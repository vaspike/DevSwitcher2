# DevSwitcher2

<div align="center">

![DevSwitcher2 Logo](https://img.shields.io/badge/DevSwitcher2-2.4-blue?style=for-the-badge)
[![macOS](https://img.shields.io/badge/macOS-12.0+-000000?style=for-the-badge&logo=apple&logoColor=white)](https://www.apple.com/macos/)
[![Swift](https://img.shields.io/badge/swift-5.9+-FA7343?style=for-the-badge&logo=swift&logoColor=white)](https://swift.org/)
[![License](https://img.shields.io/badge/license-MIT-green?style=for-the-badge)](LICENSE)

**Efficient and Elegant macOS Window Switching Tool**

A modern menu bar application that enhances window and application switching experience for smoother workflow.

[📥 Download Latest](https://github.com/vaspike/DevSwitcher2/releases) · [🐛 Report Issues](https://github.com/vaspike/DevSwitcher2/issues) · [💡 Feature Requests](https://github.com/vaspike/DevSwitcher2/discussions) · [🇨🇳 中文文档](README_CN.md)
</div>

## 📸 Preview

![1614X1064/2.png](https://tc.z.wiki/autoupload/f/bRWXqOmJV6gqytU3GpotFgC03Y8QskjEI7gIxHL71tayl5f0KlZfm6UsKj-HyTuv/20250728/szAC/1614X1064/2.png)

![1448X1002/1.png](https://tc.z.wiki/autoupload/f/bRWXqOmJV6gqytU3GpotFgC03Y8QskjEI7gIxHL71tayl5f0KlZfm6UsKj-HyTuv/20250728/2ifI/1448X1002/1.png)

![2002X1436/4.png](https://tc.z.wiki/autoupload/f/bRWXqOmJV6gqytU3GpotFgC03Y8QskjEI7gIxHL71tayl5f0KlZfm6UsKj-HyTuv/20250728/z493/2002X1436/4.png)

![3.png](https://tc.z.wiki/autoupload/f/bRWXqOmJV6gqytU3GpotFgC03Y8QskjEI7gIxHL71tayl5f0KlZfm6UsKj-HyTuv/20250728/Mamo/3574X2316/3.png/webp)

## ✨ Key Features

### 🚀 Enhanced Application Switchers
- **Intra-App Window Switcher**: Fast switching between windows within the same app (Enhanced Command + `)
- **Inter-App Switcher**: Switching between all applications (Enhanced Command + Tab)

### 🎯 Intelligent Window Recognition
- Smart title extraction with multiple strategies (first part, last part, custom separator)
- Automatic project name recognition (e.g., Xcode projects, VSCode workspaces)
- Configurable app-specific rules

### ⚡️ Ultimate Performance
- Icon caching system for smooth visual experience
- Intelligent multi-display support
- 60Hz real-time response
- Optimized memory management

### 🛠 Highly Customizable
- Fully customizable hotkey settings
- Flexible window title display strategies

### 🌐 Internationalization Support
- Complete Chinese and English localization
- Dynamic language switching
- Automatic system language detection


## 🚀 Quick Start

### System Requirements
- macOS 12.0 or later
- Accessibility permissions (guided setup on first launch)

### Installation Methods

#### Method 1: Brew install

```bash
# Install
brew tap vaspike/devswitcher2 && brew install --cask DevSwitcher2
```
```bash
# Uninstall
brew uninstall devswitcher2
```

#### Method 2: Download Release
1. Visit the [Releases page](https://github.com/vaspike/DevSwitcher2/releases)
2. Download the latest `DevSwitcher2.dmg`
3. Open the dmg file and drag the app to Applications folder
4. Launch the app and grant necessary permissions

#### Method 1: Build from Source
```bash
# Clone repository
git clone https://github.com/vaspike/DevSwitcher2.git
cd DevSwitcher2

# Open project in Xcode
open DevSwitcher2.xcodeproj

# Or build from command line
xcodebuild -project DevSwitcher2.xcodeproj -scheme DevSwitcher2 -configuration Release
```

### Initial Setup
1. **Grant Accessibility Permissions**: The app will automatically guide you through the setup
2. **Configure Hotkeys**: Default uses Command + ` (intra-app window switcher) and Command + Tab (inter-app switcher)
3. **Customize Settings**: Access preferences through the menu bar icon
4. **Note**: The `inter-app switcher` feature is disabled by default and needs to be manually enabled in preferences

## 🎮 Usage Guide

### Basic Operations
- **Window Switching**: `Command + `` (backtick) - Switch between windows of the same app
- **App Switching**: `Command + Tab` - Switch between all applications
- **Release Modifier Keys**: Complete switching and activate selected window/app
- **ESC Key**: Cancel switching and return to original state

### Advanced Tips
- **Continuous Switching**: Hold modifier keys and repeatedly press trigger key for quick browsing
- **Reverse Switching**: Add Shift key for reverse traversal
- **Mouse Selection**: Click directly to select when switcher interface is displayed
- **Custom Hotkeys**: Configure personalized hotkey combinations in preferences

### Smart Title Strategies
DevSwitcher2 provides three title extraction strategies:

1. **First Part**: Display the first half of the title (suitable for apps with filenames first)
2. **Last Part**: Display the last half of the title (suitable for windows with app names last)
3. **Custom Separator**: Smart extraction based on specified separators (like " - ", " | ", etc.)

## ⚙️ Configuration Details

### Hotkey Settings
- **Modifier Keys**: Command, Option, Control, Shift and their combinations
- **Trigger Keys**: Letters, numbers, function keys, special symbol keys
- **Conflict Detection**: Automatic detection and warning of hotkey conflicts

### App-Specific Configuration
Configure personalized title extraction rules for different apps:
- Bundle ID identification
- Custom separators
- Specific title format handling

### Language Settings
- **System Default**: Follow system language settings
- **English**: English interface
- **Chinese**: Simplified Chinese interface
- Changes take effect after restart

## 🛠 Development Guide

### Technical Architecture
- **UI Framework**: SwiftUI + AppKit hybrid development
- **Permission Management**: Accessibility API
- **Event Handling**: Carbon Event Manager
- **Icon Caching**: Custom caching system
- **Internationalization**: NSLocalizedString + dynamic language switching

### Project Structure
```
DevSwitcher2/
├── DevSwitcher2App.swift          # App entry point and AppDelegate
├── WindowManager.swift            # Core window management logic
├── HotkeyManager.swift            # Hotkey registration and handling
├── SwitcherComponents.swift       # Switcher UI components
├── PreferencesView.swift          # Preferences interface
├── SettingsManager.swift          # Settings storage and management
├── LocalizationHelper.swift       # Internationalization support
├── AppIconCache.swift             # Icon caching system
├── CompatibilityExtensions.swift  # macOS version compatibility
└── WindowSwitcherView.swift       # Window switcher view
```

### Build Requirements
- Xcode 15.0+
- Swift 5.9+
- macOS Deployment Target: 12.0

### Contributing
1. Fork this repository
2. Create a feature branch (`git checkout -b feature/AmazingFeature`)
3. Commit your changes (`git commit -m 'Add some AmazingFeature'`)
4. Push to the branch (`git push origin feature/AmazingFeature`)
5. Create a Pull Request

## 🐛 Troubleshooting

### Common Issues

**Q: App cannot switch windows?**
A: Please ensure accessibility permissions are granted: System Preferences → Security & Privacy → Privacy → Accessibility

**Q: Hotkeys not responding?**
A: Check for conflicts with other app hotkeys, you can change them in preferences

**Q: Some app window titles display incorrectly?**
A: Try configuring a custom title separator for that app in preferences

**Q: Switcher interface displays abnormally?**
A: Restart the app or reset settings to default values

### Performance Optimization
- Icon cache is automatically managed by the app
- Adjust title extraction strategies to fit your workflow
- Disable unnecessary switching modes to save resources

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

---
App for Mac
