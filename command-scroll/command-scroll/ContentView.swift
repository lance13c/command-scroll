import AppKit
import SwiftUI

struct ContentView: View {
  @EnvironmentObject private var scrollManager: CommandScrollManager

  // MARK: - Body
  var body: some View {
    VStack(spacing: 16) {
      headerRow()
      statusRow()

      if !scrollManager.inputMonitoringGranted {
        permissionWarning()
      }

      HStack(alignment: .top, spacing: 16) {
        instructionsView()
        VStack(spacing: 12) {
          activationToggle()
          activityInfoView()
        }
      }

      scrollSettingsView()
      Spacer()
      footerButtons()
    }
    .padding()
    .frame(width: 500, height: 400)  // Wider but shorter window
  }

  // MARK: - UI Components
  private func headerRow() -> some View {
    HStack {
      Image(systemName: "command.circle")
        .resizable()
        .aspectRatio(contentMode: .fit)
        .frame(width: 40, height: 40)
        .foregroundColor(.blue)

      Text("Command Scroll")
        .font(.title2)
        .fontWeight(.bold)

      Spacer()
    }
  }

  private func statusRow() -> some View {
    HStack {
      Circle()
        .fill(scrollManager.commandKeyDown ? Color.green : Color.blue)
        .frame(width: 10, height: 10)

      Text(scrollManager.commandKeyDown ? "Command key pressed" : "Ready")
        .font(.subheadline)

      Spacer()
    }
  }

  private func permissionWarning() -> some View {
    HStack(alignment: .top) {
      VStack(alignment: .leading, spacing: 6) {
        Text("Input Monitoring permission not granted.")
          .foregroundColor(.red)
          .font(.caption)

        Button("Open Input Monitoring Settings") {
          openInputMonitoringSettings()
        }
        .font(.caption)
      }
      Spacer()
    }
    .padding(.horizontal)
  }

  private func openInputMonitoringSettings() {
    let prefUrl = URL(
      string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ListenEvent")
    if let url = prefUrl {
      NSWorkspace.shared.open(url)
    }
  }

  private func instructionsView() -> some View {
    VStack(alignment: .leading, spacing: 8) {
      Text("Instructions:")
        .font(.headline)

      VStack(alignment: .leading, spacing: 4) {
        Text("• Hold the Command (⌘) key")
        Text("• Move your trackpad to scroll the active window")
        Text("• Release Command key to stop scrolling")
      }
      .font(.caption)
    }
    .padding(10)
    .frame(maxWidth: .infinity, alignment: .leading)
    .background(Color.gray.opacity(0.1))
    .cornerRadius(8)
  }

  private func activationToggle() -> some View {
    Toggle("Enable Command Scrolling", isOn: $scrollManager.isActive)
      .onChange(of: scrollManager.isActive) { oldValue, newValue in
        AppDelegate.shared?.updateMenuItemState()
      }
  }

  private func scrollSettingsView() -> some View {
    GroupBox(label: Text("Scroll Settings").font(.headline)) {
      VStack(spacing: 12) {
        sensitivitySlider()
        momentumStrengthSlider()
        decelerationRateSlider()
      }
      .padding(.vertical, 5)
    }
  }

  private func sensitivitySlider() -> some View {
    VStack(alignment: .leading) {
      Text("Scroll Sensitivity: \(String(format: "%.1f", scrollManager.scrollMultiplier))")
        .font(.caption)

      HStack {
        Text("Low")
          .font(.caption2)

        Slider(value: $scrollManager.scrollMultiplier, in: 0.5...5.0, step: 0.5)

        Text("High")
          .font(.caption2)
      }
    }
  }

  private func momentumStrengthSlider() -> some View {
    VStack(alignment: .leading) {
      Text("Momentum Strength: \(String(format: "%.2f", scrollManager.velocityMultiplier))")
        .font(.caption)

      HStack {
        Text("Low")
          .font(.caption2)

        Slider(value: $scrollManager.velocityMultiplier, in: 0.3...1.5, step: 0.05)

        Text("High")
          .font(.caption2)
      }
    }
  }

  private func decelerationRateSlider() -> some View {
    VStack(alignment: .leading) {
      HStack {
        Text("Deceleration Rate: \(String(format: "%.2f", scrollManager.decelerationRate))")
          .font(.caption)

        Text("Higher values make momentum last longer")
          .font(.caption2)
          .foregroundColor(.secondary)
          .padding(.leading, 4)
      }

      HStack {
        Text("Fast")
          .font(.caption2)

        Slider(value: $scrollManager.decelerationRate, in: 0.9...0.99, step: 0.01)

        Text("Slow")
          .font(.caption2)
      }
    }
  }

  private func activityInfoView() -> some View {
    Text("Last movement: \(timeAgoString(from: scrollManager.lastMouseMovement))")
      .font(.caption)
      .foregroundColor(.secondary)
  }

  private func footerButtons() -> some View {
    HStack {
      Button("Hide Window") {
        if let window = NSApp.windows.first {
          window.orderOut(nil)
        }
      }

      Spacer()

      Button("Quit") {
        NSApplication.shared.terminate(nil)
      }
      .keyboardShortcut("q", modifiers: .command)
    }
    .padding(.horizontal, 4)
  }

  // MARK: - Helper Methods
  private func timeAgoString(from date: Date) -> String {
    let seconds = Date().timeIntervalSince(date)

    if seconds < 60 {
      return "just now"
    } else if seconds < 3600 {
      let minutes = Int(seconds / 60)
      return "\(minutes) minute\(minutes == 1 ? "" : "s") ago"
    } else {
      let hours = Int(seconds / 3600)
      return "\(hours) hour\(hours == 1 ? "" : "s") ago"
    }
  }
}

#if DEBUG
  // Preview provider for SwiftUI Canvas
  struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
      ContentView()
        .environmentObject(CommandScrollManager())
    }
  }
#endif
