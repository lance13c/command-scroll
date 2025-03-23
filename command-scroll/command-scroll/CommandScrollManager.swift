import AppKit
import Combine
import SwiftUI

public class CommandScrollManager: ObservableObject {
  // MARK: - Configuration Properties
  @Published public var scrollMultiplier: CGFloat = 2.5
  @Published public var velocityMultiplier: CGFloat = 0.60
  @Published public var decelerationRate: CGFloat = 0.95

  // MARK: - Public State Properties
  @Published public var isActive = true
  @Published public var commandKeyDown = false
  @Published public var lastMouseMovement = Date()
  @Published public var inputMonitoringGranted: Bool = false

  // MARK: - Private Properties
  private var lastMouseLocation: CGPoint?
  private var velocityX: CGFloat = 0
  private var velocityY: CGFloat = 0
  private var lastMoveTime: Date = Date()
  private var isDragging: Bool = false
  private var lastMouseDeltas: [(dx: CGFloat, dy: CGFloat, timestamp: Date)] = []
  private let velocityHistoryCount = 5

  // Momentum scrolling state
  private var momentumActive: Bool = false
  private var lastSignificantMoveTime: Date = Date()

  // CGEventTap tracking
  private var flagsChangedEventTap: CFMachPort?
  private var mouseMovedEventTap: CFMachPort?
  private var runLoopSource1: CFRunLoopSource?
  private var runLoopSource2: CFRunLoopSource?
  private var inertiaTimer: Timer?
  private var mousePauseDetectionTimer: Timer?

  #if DEBUG
    private let loggingEnabled = true
  #else
    private let loggingEnabled = false
  #endif

  // MARK: - Initialization & Setup
  public init() {
    logDebug("CommandScrollManager initialized")
  }

  public func setupMonitors() {
    removeMonitors()

    // Request accessibility permissions with prompt if needed
    let options: NSDictionary = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
    let accessibilityEnabled = AXIsProcessTrustedWithOptions(options)
    logDebug("Accessibility permissions granted: \(accessibilityEnabled)")

    setupGlobalKeyMonitor()
    setupGlobalMouseMonitor()

    // Check if both event taps were created successfully
    if (flagsChangedEventTap != nil && mouseMovedEventTap != nil) || loggingEnabled {
      inputMonitoringGranted = true
      logDebug("Input Monitoring permissions granted")
    } else {
      inputMonitoringGranted = false
      logDebug("Input Monitoring permissions NOT granted")
    }

    setupMousePauseDetectionTimer()
  }

  public func removeMonitors() {
    if let eventTap = flagsChangedEventTap {
      CGEvent.tapEnable(tap: eventTap, enable: false)
      flagsChangedEventTap = nil
    }
    if let runLoopSource = runLoopSource1 {
      CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
      runLoopSource1 = nil
    }
    if let eventTap = mouseMovedEventTap {
      CGEvent.tapEnable(tap: eventTap, enable: false)
      mouseMovedEventTap = nil
    }
    if let runLoopSource = runLoopSource2 {
      CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
      runLoopSource2 = nil
    }

    mousePauseDetectionTimer?.invalidate()
    mousePauseDetectionTimer = nil
    stopMomentumScrolling()
    logDebug("Monitors removed")
  }

  // MARK: - Mouse Pause Detection
  private func setupMousePauseDetectionTimer() {
    mousePauseDetectionTimer?.invalidate()
    mousePauseDetectionTimer = Timer.scheduledTimer(withTimeInterval: 0.016, repeats: true) {
      [weak self] _ in
      guard let self = self, self.isActive, self.commandKeyDown, self.isDragging,
        !self.momentumActive
      else { return }
      let now = Date()
      let timeSinceLastMove = now.timeIntervalSince(self.lastSignificantMoveTime)
      let hasSignificantVelocity = abs(self.velocityX) > 5.0 || abs(self.velocityY) > 5.0
      if timeSinceLastMove > 0.03 && timeSinceLastMove < 0.2 && hasSignificantVelocity {
        self.logDebug("Mouse pause detected with velocity: (\(self.velocityX), \(self.velocityY))")
        self.startMomentumScrolling()
      }
    }
    if let timer = mousePauseDetectionTimer {
      RunLoop.current.add(timer, forMode: .common)
    }
  }

  // MARK: - Event Monitors Setup
  private func setupGlobalKeyMonitor() {
    let eventMask = CGEventMask(1 << CGEventType.flagsChanged.rawValue)
    let callback: CGEventTapCallBack = { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
      if let refcon = refcon {
        let manager = Unmanaged<CommandScrollManager>.fromOpaque(refcon).takeUnretainedValue()
        manager.handleKeyEvent(event)
      }
      return Unmanaged.passUnretained(event)
    }
    let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    flagsChangedEventTap = CGEvent.tapCreate(
      tap: .cgSessionEventTap,
      place: .headInsertEventTap,
      options: .defaultTap,
      eventsOfInterest: eventMask,
      callback: callback,
      userInfo: selfPtr
    )
    if let eventTap = flagsChangedEventTap {
      runLoopSource1 = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
      if let runLoopSource = runLoopSource1 {
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        logDebug("Global key event monitor set up successfully")
      } else {
        logDebug("Failed to create run loop source for key events")
      }
    } else {
      logDebug("Failed to create event tap for key events - check accessibility permissions")
    }
  }

  private func setupGlobalMouseMonitor() {
    let eventMask = CGEventMask(1 << CGEventType.mouseMoved.rawValue)
    let callback: CGEventTapCallBack = { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
      if let refcon = refcon {
        let manager = Unmanaged<CommandScrollManager>.fromOpaque(refcon).takeUnretainedValue()
        manager.handleMouseEvent(event)
      }
      return Unmanaged.passUnretained(event)
    }
    let selfPtr = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
    mouseMovedEventTap = CGEvent.tapCreate(
      tap: .cgSessionEventTap,
      place: .headInsertEventTap,
      options: .defaultTap,
      eventsOfInterest: eventMask,
      callback: callback,
      userInfo: selfPtr
    )
    if let eventTap = mouseMovedEventTap {
      runLoopSource2 = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
      if let runLoopSource = runLoopSource2 {
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        logDebug("Global mouse event monitor set up successfully")
      } else {
        logDebug("Failed to create run loop source for mouse events")
      }
    } else {
      logDebug("Failed to create event tap for mouse events - check accessibility permissions")
    }
  }

  // MARK: - Event Handling
  private func handleMouseEvent(_ event: CGEvent) {
    guard isActive && commandKeyDown else {
      if isDragging && !commandKeyDown {
        startMomentumScrolling()
        isDragging = false
      }
      return
    }
    let currentLocation = CGPoint(x: event.location.x, y: event.location.y)
    let currentTime = Date()
    if lastMouseLocation == nil {
      lastMouseLocation = currentLocation
      lastMoveTime = currentTime
      lastSignificantMoveTime = currentTime
      isDragging = true
      momentumActive = false
      velocityX = 0
      velocityY = 0
      lastMouseDeltas.removeAll()
      return
    }
    let deltaX = currentLocation.x - lastMouseLocation!.x
    let deltaY = currentLocation.y - lastMouseLocation!.y
    let movementMagnitude = sqrt(deltaX * deltaX + deltaY * deltaY)
    if momentumActive && movementMagnitude > 1.0 {
      logDebug("Exiting momentum mode due to new mouse movement")
      stopMomentumScrolling()
      lastMouseDeltas.removeAll()
      lastSignificantMoveTime = currentTime
    }
    if lastMouseDeltas.count >= velocityHistoryCount {
      lastMouseDeltas.removeFirst()
    }
    lastMouseDeltas.append((dx: deltaX, dy: deltaY, timestamp: currentTime))
    calculateVelocity()
    if !momentumActive {
      let minMovementThreshold: CGFloat = 0.3
      if movementMagnitude > minMovementThreshold {
        lastSignificantMoveTime = currentTime
        isDragging = true
        performScroll(deltaX: deltaX, deltaY: deltaY)
      }
    }
    lastMouseLocation = currentLocation
    lastMoveTime = currentTime
  }

  private func handleKeyEvent(_ event: CGEvent) {
    if event.type == .flagsChanged {
      if let nsEvent = NSEvent(cgEvent: event) {
        let isCommandDown = nsEvent.modifierFlags.contains(.command)
        if isCommandDown != commandKeyDown {
          if commandKeyDown && !isCommandDown, !momentumActive, isDragging {
            startMomentumScrolling()
          }
          commandKeyDown = isCommandDown
          logDebug("Command key \(isCommandDown ? "pressed" : "released") (global)")
          if isCommandDown {
            lastMouseLocation = nil
            stopMomentumScrolling()
            isDragging = false
            momentumActive = false
            lastMouseDeltas.removeAll()
          }
        }
      }
    }
  }

  // MARK: - Momentum & Velocity Management
  private func calculateVelocity() {
    guard !lastMouseDeltas.isEmpty else {
      velocityX *= decelerationRate
      velocityY *= decelerationRate
      return
    }
    var totalWeight: CGFloat = 0
    var weightedSumX: CGFloat = 0
    var weightedSumY: CGFloat = 0
    let now = Date()
    let timeWindow: TimeInterval = 0.08
    for delta in lastMouseDeltas {
      let age = now.timeIntervalSince(delta.timestamp)
      let weight: CGFloat = age < 0.02 ? 1.5 : max(0, 1.0 - (age / timeWindow))
      weightedSumX += delta.dx * weight
      weightedSumY += delta.dy * weight
      totalWeight += weight
    }
    if totalWeight > 0 {
      let newVelocityX = weightedSumX / totalWeight
      let newVelocityY = weightedSumY / totalWeight
      let isDirectionChangeX = (velocityX * newVelocityX < 0)
      let isDirectionChangeY = (velocityY * newVelocityY < 0)
      velocityX =
        isDirectionChangeX
        ? (newVelocityX * 0.95 + velocityX * 0.05) : (newVelocityX * 0.8 + velocityX * 0.2)
      velocityY =
        isDirectionChangeY
        ? (newVelocityY * 0.95 + velocityY * 0.05) : (newVelocityY * 0.8 + velocityY * 0.2)
      velocityX *= velocityMultiplier
      velocityY *= velocityMultiplier
    }
  }

  private func startMomentumScrolling() {
    if abs(velocityX) > 1.0 || abs(velocityY) > 1.0 {
      logDebug("Starting momentum scrolling with velocity: (\(velocityX), \(velocityY))")
      inertiaTimer?.invalidate()
      let velocityMagnitude = sqrt(velocityX * velocityX + velocityY * velocityY)
      let boostFactor = min(1.15, max(1.02, 1.2 - (velocityMagnitude * 0.01)))
      velocityX *= boostFactor
      velocityY *= boostFactor
      momentumActive = true
      inertiaTimer = Timer.scheduledTimer(withTimeInterval: 1 / 120, repeats: true) {
        [weak self] _ in
        self?.updateMomentumScrolling()
      }
      if let timer = inertiaTimer {
        RunLoop.current.add(timer, forMode: .common)
      }
    } else {
      logDebug("No significant velocity for momentum scrolling")
    }
  }

  private func stopMomentumScrolling() {
    inertiaTimer?.invalidate()
    inertiaTimer = nil
    velocityX = 0
    velocityY = 0
    momentumActive = false
  }

  private func updateMomentumScrolling() {
    velocityX *= decelerationRate
    velocityY *= decelerationRate
    if abs(velocityX) > 0.1 || abs(velocityY) > 0.1 {
      performScroll(deltaX: velocityX, deltaY: velocityY)
    } else {
      stopMomentumScrolling()
    }
  }

  private func performScroll(deltaX: CGFloat, deltaY: CGFloat) {
    let scaledDeltaX = deltaX * scrollMultiplier
    let scaledDeltaY = deltaY * scrollMultiplier
    if let scrollEvent = CGEvent(
      scrollWheelEvent2Source: nil,
      units: .pixel,
      wheelCount: 2,
      wheel1: Int32(scaledDeltaY),
      wheel2: Int32(scaledDeltaX),
      wheel3: 0)
    {
      scrollEvent.post(tap: .cghidEventTap)
    }
  }

  // MARK: - Public Controls
  public func toggleActive() {
    isActive.toggle()
    logDebug("Scrolling \(isActive ? "enabled" : "disabled")")
  }

  private func logDebug(_ message: String) {
    #if DEBUG
      if loggingEnabled {
        print(message)
      }
    #endif
  }

  deinit {
    removeMonitors()
    logDebug("CommandScrollManager deallocated")
  }
}
