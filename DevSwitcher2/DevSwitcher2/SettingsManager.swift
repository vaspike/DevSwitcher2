//
//  SettingsManager.swift
//  DevSwitcher2
//
//  Created by river on 2025-07-26.
//

import Foundation
import AppKit
import Carbon
import ServiceManagement

// MARK: - Modifier Key Enum
enum ModifierKey: String, CaseIterable, Codable {
    case command = "command"
    case option = "option"
    case control = "control"
    case function = "function"
    
    var displayName: String {
        switch self {
        case .command:
            return LocalizedStrings.modifierCommand
        case .option:
            return LocalizedStrings.modifierOption
        case .control:
            return LocalizedStrings.modifierControl
        case .function:
            return LocalizedStrings.modifierFunction
        }
    }
    
    var carbonModifier: UInt32 {
        switch self {
        case .command:
            return UInt32(cmdKey)
        case .option:
            return UInt32(optionKey)
        case .control:
            return UInt32(controlKey)
        case .function:
            return UInt32(kEventKeyModifierFnMask)
        }
    }
    
    var cgEventFlags: CGEventFlags {
        switch self {
        case .command:
            return .maskCommand
        case .option:
            return .maskAlternate
        case .control:
            return .maskControl
        case .function:
            return .maskSecondaryFn
        }
    }
    
    var eventModifier: NSEvent.ModifierFlags {
        switch self {
        case .command:
            return .command
        case .option:
            return .option
        case .control:
            return .control
        case .function:
            return .function
        }
    }
}

// MARK: - Trigger Key Enum
enum TriggerKey: String, CaseIterable, Codable {
    case grave = "`"           // ` key
    case tab = "Tab"          // Tab key
    case space = "Space"      // Space key
    case semicolon = ";"      // ; key
    case quote = "'"          // ' key
    case comma = ","          // , key
    case period = "."         // . key
    case slash = "/"          // / key
    case backslash = "\\"     // \ key
    case leftBracket = "["    // [ key
    case rightBracket = "]"   // ] key
    
    var displayName: String {
        switch self {
        case .grave:
            return LocalizedStrings.triggerGrave
        case .tab:
            return LocalizedStrings.triggerTab
        case .space:
            return LocalizedStrings.triggerSpace
        case .semicolon:
            return LocalizedStrings.triggerSemicolon
        case .quote:
            return LocalizedStrings.triggerQuote
        case .comma:
            return LocalizedStrings.triggerComma
        case .period:
            return LocalizedStrings.triggerPeriod
        case .slash:
            return LocalizedStrings.triggerSlash
        case .backslash:
            return LocalizedStrings.triggerBackslash
        case .leftBracket:
            return LocalizedStrings.triggerLeftBracket
        case .rightBracket:
            return LocalizedStrings.triggerRightBracket
        }
    }
    
    var keyCode: UInt32 {
        switch self {
        case .grave:
            return UInt32(kVK_ANSI_Grave)      // 50
        case .tab:
            return UInt32(kVK_Tab)             // 48
        case .space:
            return UInt32(kVK_Space)           // 49
        case .semicolon:
            return UInt32(kVK_ANSI_Semicolon)  // 41
        case .quote:
            return UInt32(kVK_ANSI_Quote)      // 39
        case .comma:
            return UInt32(kVK_ANSI_Comma)      // 43
        case .period:
            return UInt32(kVK_ANSI_Period)     // 47
        case .slash:
            return UInt32(kVK_ANSI_Slash)      // 44
        case .backslash:
            return UInt32(kVK_ANSI_Backslash)  // 42
        case .leftBracket:
            return UInt32(kVK_ANSI_LeftBracket) // 33
        case .rightBracket:
            return UInt32(kVK_ANSI_RightBracket) // 30
        }
    }
}

// MARK: - Window Title Extraction Strategy
enum TitleExtractionStrategy: String, CaseIterable, Codable {
    case firstPart = "firstPart"           // Take first part (default)
    case lastPart = "lastPart"             // Take last part
    case beforeFirstSeparator = "beforeFirstSeparator"  // Before first separator
    case afterLastSeparator = "afterLastSeparator"      // After last separator
    case fullTitle = "fullTitle"           // Full title
    
    var displayName: String {
        switch self {
        case .firstPart:
            return LocalizedStrings.strategyFirstPart
        case .lastPart:
            return LocalizedStrings.strategyLastPart
        case .beforeFirstSeparator:
            return LocalizedStrings.strategyBeforeFirstSeparator
        case .afterLastSeparator:
            return LocalizedStrings.strategyAfterLastSeparator
        case .fullTitle:
            return LocalizedStrings.strategyFullTitle
        }
    }
}

// MARK: - App Title Configuration
struct AppTitleConfig: Codable {
    let bundleId: String
    let appName: String
    let strategy: TitleExtractionStrategy
    let customSeparator: String?
    
    init(bundleId: String, appName: String, strategy: TitleExtractionStrategy, customSeparator: String? = nil) {
        self.bundleId = bundleId
        self.appName = appName
        self.strategy = strategy
        self.customSeparator = customSeparator
    }
}

// MARK: - App Settings Data Structure
struct AppSettings: Codable {
    var modifierKey: ModifierKey
    var triggerKey: TriggerKey
    var appTitleConfigs: [String: AppTitleConfig] // bundleId -> config
    var defaultTitleStrategy: TitleExtractionStrategy
    var defaultCustomSeparator: String
    
    // CT2 settings
    var ct2Enabled: Bool
    var ct2ModifierKey: ModifierKey
    var ct2TriggerKey: TriggerKey
    
    // General settings
    var launchAtStartup: Bool
    
    static let `default` = AppSettings(
        modifierKey: .command,
        triggerKey: .grave,
        appTitleConfigs: [
            "com.jetbrains.intellij": AppTitleConfig(
                bundleId: "com.jetbrains.intellij",
                appName: "IntelliJ IDEA",
                strategy: .beforeFirstSeparator,
                customSeparator: " – "
            ),
            "com.apple.dt.Xcode": AppTitleConfig(
                bundleId: "com.apple.dt.Xcode",
                appName: "Xcode",
                strategy: .beforeFirstSeparator,
                customSeparator: " — "
            ),
            "com.microsoft.VSCode": AppTitleConfig(
                bundleId: "com.microsoft.VSCode",
                appName: "VS Code",
                strategy: .afterLastSeparator,
                customSeparator: " - "
            ),
            "com.todesktop.230313mzl4w4u92": AppTitleConfig(
                bundleId: "com.todesktop.230313mzl4w4u92",
                appName: "Cursor",
                strategy: .afterLastSeparator,
                customSeparator: " - "
            ),
            "com.apple.Safari": AppTitleConfig(
                bundleId: "com.apple.Safari",
                appName: "Safari",
                strategy: .beforeFirstSeparator,
                customSeparator: " — "
            )
        ],
        defaultTitleStrategy: .beforeFirstSeparator,
        defaultCustomSeparator: " - ",
        // CT2 default settings
        ct2Enabled: true,
        ct2ModifierKey: .command,
        ct2TriggerKey: .tab,
        // General default settings
        launchAtStartup: false
    )
}

// MARK: - Settings Manager
class SettingsManager: ObservableObject {
    @Published var settings: AppSettings
    
    private let userDefaults = UserDefaults.standard
    private let settingsKey = "DevSwitcher2Settings"
    
    static let shared = SettingsManager()
    
    private init() {
        if let data = userDefaults.data(forKey: settingsKey) {
            do {
                self.settings = try JSONDecoder().decode(AppSettings.self, from: data)
            } catch {
                Logger.log("Settings decoding failed, possibly due to version incompatibility: \(error)")
                // Try to migrate old version settings
                self.settings = Self.migrateOldSettings() ?? AppSettings.default
                saveSettings()
            }
        } else {
            self.settings = AppSettings.default
            saveSettings()
        }
    }
    
    // Method to migrate old version settings
    private static func migrateOldSettings() -> AppSettings? {
        // If unable to decode new version settings, try reading known old settings from UserDefaults
        // More migration logic can be added here as needed
        
        // Create default settings and maintain existing basic configuration
        let migratedSettings = AppSettings.default
        
        // Logic to read specific values from old version settings can be added here
        // For example: if let oldModifier = UserDefaults.standard.string(forKey: "oldModifierKey") { ... }
        
        Logger.log("Using default settings with CT2 functionality enabled")
        return migratedSettings
    }
    
    func saveSettings() {
        if let data = try? JSONEncoder().encode(settings) {
            userDefaults.set(data, forKey: settingsKey)
            Logger.log("Settings saved")
        } else {
            Logger.log("Failed to save settings")
        }
    }
    
    func resetToDefault() {
        settings = AppSettings.default
        saveSettings()
    }
    
    // MARK: - Hotkey Settings
    func updateHotkey(modifier: ModifierKey, trigger: TriggerKey) {
        settings.modifierKey = modifier
        settings.triggerKey = trigger
        saveSettings()
    }
    
    // MARK: - CT2 Settings
    func updateCT2Enabled(_ enabled: Bool) {
        settings.ct2Enabled = enabled
        saveSettings()
    }
    
    func updateCT2Hotkey(modifier: ModifierKey, trigger: TriggerKey) {
        settings.ct2ModifierKey = modifier
        settings.ct2TriggerKey = trigger
        saveSettings()
    }
    
    // MARK: - General Settings
    func updateLaunchAtStartup(_ enabled: Bool) {
        settings.launchAtStartup = enabled
        saveSettings()
        
        // Apply launch at startup setting
        setLaunchAtStartup(enabled)
    }
    
    private func setLaunchAtStartup(_ enabled: Bool) {
        let bundleIdentifier = Bundle.main.bundleIdentifier ?? "com.unknown.DevSwitcher2"
        
        if enabled {
            // Add to login items
            let appURL = Bundle.main.bundleURL
            if #available(macOS 13.0, *) {
                // Use modern API for macOS 13+
                try? SMAppService.mainApp.register()
            } else {
                // Use legacy API for older macOS versions
                addToLoginItemsLegacy(appURL: appURL)
            }
        } else {
            // Remove from login items
            if #available(macOS 13.0, *) {
                // Use modern API for macOS 13+
                try? SMAppService.mainApp.unregister()
            } else {
                // Use legacy API for older macOS versions
                removeFromLoginItemsLegacy(bundleIdentifier: bundleIdentifier)
            }
        }
    }
    
    // Legacy method for macOS 12 and earlier
    private func addToLoginItemsLegacy(appURL: URL) {
        // Use AppleScript as a more reliable method for legacy support
        let script = """
        tell application "System Events"
            if not (exists login item "\(appURL.lastPathComponent)") then
                make login item at end with properties {name:"\(appURL.lastPathComponent)", path:"\(appURL.path)", hidden:false}
            end if
        end tell
        """
        
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let error = error {
                Logger.log("❌ Failed to add login item via AppleScript: \(error)")
            } else {
                Logger.log("✅ Successfully added login item via AppleScript")
            }
        }
    }
    
    private func removeFromLoginItemsLegacy(bundleIdentifier: String) {
        let appURL = Bundle.main.bundleURL
        
        let script = """
        tell application "System Events"
            if (exists login item "\(appURL.lastPathComponent)") then
                delete login item "\(appURL.lastPathComponent)"
            end if
        end tell
        """
        
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
            if let error = error {
                Logger.log("❌ Failed to remove login item via AppleScript: \(error)")
            } else {
                Logger.log("✅ Successfully removed login item via AppleScript")
            }
        }
    }
    
    // MARK: - App Title Configuration
    func getAppTitleConfig(for bundleId: String) -> AppTitleConfig? {
        Logger.log("获取自定义config: \(bundleId)")
        let config = settings.appTitleConfigs[bundleId]
        Logger.log("获取自定义config: \(String(describing: config))")
        return config
    }
    
    func setAppTitleConfig(_ config: AppTitleConfig) {
        settings.appTitleConfigs[config.bundleId] = config
        saveSettings()
    }
    
    func removeAppTitleConfig(for bundleId: String) {
        settings.appTitleConfigs.removeValue(forKey: bundleId)
        saveSettings()
    }
    
    func updateDefaultTitleStrategy(_ strategy: TitleExtractionStrategy, customSeparator: String = " - ") {
        settings.defaultTitleStrategy = strategy
        settings.defaultCustomSeparator = customSeparator
        saveSettings()
    }
    
    // MARK: - Generic Title Extraction Algorithm
    func extractProjectName(from title: String, bundleId: String, appName: String) -> String {
        // First check if there are app-specific configurations
        Logger.log("准备截断标题: \(bundleId)")
        if let config = getAppTitleConfig(for: bundleId) {
            Logger.log("使用自定义config: \(config)")
            return extractProjectNamePrivate(from: title, using: config.strategy, customSeparator: config.customSeparator)
        }
        
        // Use default strategy
        return extractProjectNamePrivate(from: title, using: settings.defaultTitleStrategy, customSeparator: settings.defaultCustomSeparator)
    }
    
    // Public method for preview functionality
    func extractProjectName(from title: String, using strategy: TitleExtractionStrategy, customSeparator: String?) -> String {
        return extractProjectNamePrivate(from: title, using: strategy, customSeparator: customSeparator)
    }
    
    private func extractProjectNamePrivate(from title: String, using strategy: TitleExtractionStrategy, customSeparator: String?) -> String {
        guard !title.isEmpty else { return title }
        
        switch strategy {
        case .firstPart:
            return extractFirstPart(from: title, customSeparator: customSeparator)
            
        case .lastPart:
            return extractLastPart(from: title, customSeparator: customSeparator)
            
        case .beforeFirstSeparator:
            return extractBeforeFirstSeparator(from: title, customSeparator: customSeparator)
            
        case .afterLastSeparator:
            return extractAfterLastSeparator(from: title, customSeparator: customSeparator)
            
        case .fullTitle:
            return title
        }
    }
    
    private func extractFirstPart(from title: String, customSeparator: String?) -> String {
        // 如果指定了自定义分隔符，优先使用
        if let customSeparator = customSeparator, !customSeparator.isEmpty {
            if let range = title.range(of: customSeparator) {
                return String(title[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
        }
        
        // 否则使用默认分隔符列表
        let commonSeparators = [" - ", " — ", " | ", " / ", " \\ "]
        
        for separator in commonSeparators {
            if let range = title.range(of: separator) {
                return String(title[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
        }
        
        return title
    }
    
    private func extractLastPart(from title: String, customSeparator: String?) -> String {
        // 如果指定了自定义分隔符，优先使用
        if let customSeparator = customSeparator, !customSeparator.isEmpty {
            if let range = title.range(of: customSeparator, options: .backwards) {
                return String(title[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        }
        
        // 否则使用默认分隔符列表
        let commonSeparators = [" - ", " — ", " | ", " / ", " \\ "]
        
        for separator in commonSeparators {
            if let range = title.range(of: separator, options: .backwards) {
                return String(title[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        }
        
        return title
    }
    
    private func extractBeforeFirstSeparator(from title: String, customSeparator: String?) -> String {
        // 如果指定了自定义分隔符，优先使用
        if let customSeparator = customSeparator, !customSeparator.isEmpty {
            if let range = title.range(of: customSeparator) {
                return String(title[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
        }
        
        // 否则使用默认分隔符列表
        let commonSeparators = [" — ", " - ", " | ", " / ", " \\ "]
        
        for separator in commonSeparators {
            if let range = title.range(of: separator) {
                return String(title[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
        }
        
        return title
    }
    
    private func extractAfterLastSeparator(from title: String, customSeparator: String?) -> String {
        // 如果指定了自定义分隔符，优先使用
        if let customSeparator = customSeparator, !customSeparator.isEmpty {
            if let range = title.range(of: customSeparator, options: .backwards) {
                return String(title[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        }
        
        // 否则使用默认分隔符列表
        let commonSeparators = [" — ", " - ", " | ", " / ", " \\ "]
        
        for separator in commonSeparators {
            if let range = title.range(of: separator, options: .backwards) {
                return String(title[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        }
        
        return title
    }
}
