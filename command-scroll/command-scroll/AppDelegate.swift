import AppKit
import Combine
import SwiftUI

class AppDelegate: NSObject, NSApplicationDelegate {
  static var shared: AppDelegate? {
    return NSApplication.shared.delegate as? AppDelegate
  }

  var scrollManager: CommandScrollManager?
  var mainWindow: NSWindow?
  var statusItem: NSStatusItem?
  private var hiddenWindow: NSWindow?

  func applicationDidFinishLaunching(_ notification: Notification) {
    print("Application launching")

    // This is the key difference - use regular activation policy even with LSUIElement=true
    NSApp.setActivationPolicy(.accessory)

    // Setup application menu
    setupApplicationMenu()

    // Setup status bar item
    setupStatusItem()

    // Save reference to main window
    if let window = NSApplication.shared.windows.first {
      mainWindow = window
      window.isReleasedWhenClosed = false
      print("Main window configured")
    }

    // Create an invisible window that stays open to keep event monitoring active
    createHiddenWindow()

    // Setup notification observers for app activation/deactivation
    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationActivated),
      name: NSApplication.didBecomeActiveNotification,
      object: nil
    )

    NotificationCenter.default.addObserver(
      self,
      selector: #selector(applicationDeactivated),
      name: NSApplication.didResignActiveNotification,
      object: nil
    )
  }

  private func createHiddenWindow() {
    // Create a tiny, invisible window to keep app running properly
    let window = NSWindow(
      contentRect: NSRect(x: 0, y: 0, width: 1, height: 1),
      styleMask: [],
      backing: .buffered,
      defer: false
    )

    // Set properties to make it invisible
    window.isOpaque = false
    window.hasShadow = false
    window.backgroundColor = NSColor.clear
    window.alphaValue = 0

    // Position off-screen
    window.setFrameOrigin(NSPoint(x: -1000, y: -1000))

    // Don't show in window menu
    window.isExcludedFromWindowsMenu = true

    // Never release
    window.isReleasedWhenClosed = false

    // This is crucial - the window must be owned and retained
    hiddenWindow = window

    // Order front but don't make key (invisible but present)
    window.orderFront(nil)

    print("Hidden window created to keep app active")
  }

  private func setupApplicationMenu() {
    // Create the main menu programmatically
    let mainMenu = NSMenu()

    // Create the application menu (first menu)
    let appMenu = NSMenu()
    let appMenuItem = NSMenuItem(title: "", action: nil, keyEquivalent: "")

    // Add items to the app menu
    appMenu.addItem(
      NSMenuItem(
        title: "About Command Scroll",
        action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)), keyEquivalent: ""))
    appMenu.addItem(NSMenuItem.separator())
    appMenu.addItem(
      NSMenuItem(
        title: "Quit Command Scroll", action: #selector(NSApplication.terminate(_:)),
        keyEquivalent: "q"))

    // Set app menu
    appMenuItem.submenu = appMenu
    mainMenu.addItem(appMenuItem)

    // Replace the application's main menu
    NSApplication.shared.mainMenu = mainMenu

    print("Application menu configured")
  }

  private func setupStatusItem() {
    statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

    if let button = statusItem?.button {
      button.title = "⌘⬇️"

      // Create menu
      let menu = NSMenu()

      menu.addItem(
        NSMenuItem(
          title: "Show Command Scroll", action: #selector(showMainWindow), keyEquivalent: ""))
      menu.addItem(NSMenuItem.separator())

      let enabledItem = NSMenuItem(
        title: scrollManager?.isActive ?? true ? "Disable Scrolling" : "Enable Scrolling",
        action: #selector(toggleActive), keyEquivalent: "e")
      enabledItem.target = self
      menu.addItem(enabledItem)

      menu.addItem(NSMenuItem.separator())
      menu.addItem(
        NSMenuItem(
          title: "Restart Monitoring", action: #selector(restartMonitoring), keyEquivalent: "r"))

      menu.addItem(NSMenuItem.separator())
      menu.addItem(
        NSMenuItem(
          title: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

      statusItem?.menu = menu

      print("Status item configured")
    }
  }

  func updateMenuItemState() {
    // Update menu item text based on current isActive state
    if let menuItem = statusItem?.menu?.item(at: 2) {
      menuItem.title = (scrollManager?.isActive ?? false) ? "Disable Scrolling" : "Enable Scrolling"
    }
  }

  @objc func applicationActivated(_ notification: Notification) {
    print("App became active")
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
      self?.scrollManager?.setupMonitors()
    }
  }

  @objc func applicationDeactivated(_ notification: Notification) {
    print("App resigned active state")
  }

  @objc func showMainWindow() {
    print("Showing main window")
    NSApp.activate(ignoringOtherApps: true)

    if let window = mainWindow {
      window.makeKeyAndOrderFront(nil)
    } else if let window = NSApplication.shared.windows.first(where: { $0 != hiddenWindow }) {
      mainWindow = window
      window.makeKeyAndOrderFront(nil)
    }
  }

  @objc func toggleActive() {
    scrollManager?.toggleActive()
    updateMenuItemState()
  }

  @objc func restartMonitoring() {
    scrollManager?.setupMonitors()
  }

  func applicationWillTerminate(_ notification: Notification) {
    scrollManager?.removeMonitors()
  }

  func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
    return false
  }
}
