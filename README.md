# Command Scroll

A macOS utility that enables scrolling by holding the Command (⌘) key and moving your mouse or trackpad.

## Features

- **Command Key Scrolling**: Hold the Command (⌘) key and move your mouse/trackpad to scroll in any application
- **Momentum Scrolling**: Natural scrolling physics with customizable momentum
- **Adjustable Settings**:
  - Scroll sensitivity
  - Momentum strength
  - Deceleration rate
- **System Integration**: Lives in your menu bar for easy access
- **Low Resource Usage**: Designed to be lightweight and unobtrusive

## Requirements

- macOS 14.6 or later
- Input Monitoring permissions (will be requested on first launch)
- Accessibility permissions (will be requested on first launch)

## Installation

1. Download the latest release from the [Releases](https://github.com/yourusername/command-scroll/releases) page
2. Move Command Scroll to your Applications folder
3. Launch the app
4. Grant the required permissions when prompted:
   - Input Monitoring (required to detect Command key and mouse movements)
   - Accessibility (required to inject scroll events)

## Usage

1. Launch Command Scroll from your Applications folder
2. The app will appear in your menu bar
3. Hold down the Command (⌘) key and move your mouse/trackpad to scroll
4. Release the Command key to stop scrolling
5. Access settings by clicking the Command Scroll icon in the menu bar

## Configuration

Access the settings window through the menu bar icon to customize:

- **Enable/Disable**: Toggle Command Scrolling functionality
- **Scroll Sensitivity**: Adjust how far the content scrolls relative to mouse movement
- **Momentum Strength**: Control how strongly momentum affects scrolling
- **Deceleration Rate**: Adjust how quickly momentum scrolling slows down

## Troubleshooting

### Permissions Issues

If Command Scroll isn't working properly:

1. Open System Preferences > Security & Privacy > Privacy
2. Check both "Input Monitoring" and "Accessibility" lists
3. Ensure Command Scroll is checked in both lists
4. Restart the application

### Other Issues

- Check that Command Scroll is running (check menu bar)
- Ensure Command Scrolling is enabled in the settings
- Restart the application if issues persist

## Building from Source

1. Clone the repository:
   ```
   git clone https://github.com/yourusername/command-scroll.git
   ```
2. Open the project in Xcode
3. Build and run the project

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

[MIT License](LICENSE)
