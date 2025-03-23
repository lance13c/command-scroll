import AppKit
import Combine
import SwiftUI

@main
struct CommandScrollApp: App {
  // Use @State instead of @StateObject for app struct
  // The actual StateObject will be created in a proper view
  private var scrollManager = CommandScrollManager()
  @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

  init() {
    // Create a local reference to the scroll manager to avoid capturing self
    let scrollManagerRef = scrollManager

    // Use the local reference instead of accessing self.scrollManager
    DispatchQueue.main.async {
      (NSApplication.shared.delegate as? AppDelegate)?.scrollManager = scrollManagerRef
    }
  }

  var body: some Scene {
    WindowGroup {
      // Wrap the ContentView in RootView to properly manage StateObject
      RootView(scrollManager: scrollManager)
        .onAppear {
          // Initialize scroll functionality when app appears
          scrollManager.setupMonitors()
        }
    }
    .windowStyle(.hiddenTitleBar)
    // Remove the commands modifier to prevent duplicate menu items
  }
}

// Add this wrapper view to properly handle the StateObject
struct RootView: View {
  // Initialize the StateObject here in a proper view
  @StateObject private var scrollManagerState: CommandScrollManager

  init(scrollManager: CommandScrollManager) {
    // Use the _scrollManagerState to initialize without triggering the warning
    _scrollManagerState = StateObject(wrappedValue: scrollManager)
  }

  var body: some View {
    ContentView()
      .environmentObject(scrollManagerState)
  }
}
