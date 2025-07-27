//
//  SettingsManager.swift
//  DevSwitcher2
//
//  Created by river on 2025-07-26.
//

import Foundation
import AppKit
import Carbon

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
    case customSeparator = "customSeparator" // Custom separator
    
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
        case .customSeparator:
            return LocalizedStrings.strategyCustomSeparator
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
    
    static let `default` = AppSettings(
        modifierKey: .command,
        triggerKey: .grave,
        appTitleConfigs: [
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
            )
        ],
        defaultTitleStrategy: .beforeFirstSeparator,
        defaultCustomSeparator: " - ",
        // CT2 default settings
        ct2Enabled: true,
        ct2ModifierKey: .command,
        ct2TriggerKey: .tab
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
    
    // MARK: - App Title Configuration
    func getAppTitleConfig(for bundleId: String) -> AppTitleConfig? {
        return settings.appTitleConfigs[bundleId]
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
        if let config = getAppTitleConfig(for: bundleId) {
            return extractProjectName(from: title, using: config.strategy, customSeparator: config.customSeparator)
        }
        
        // Use default strategy
        return extractProjectName(from: title, using: settings.defaultTitleStrategy, customSeparator: settings.defaultCustomSeparator)
    }
    
    private func extractProjectName(from title: String, using strategy: TitleExtractionStrategy, customSeparator: String?) -> String {
        guard !title.isEmpty else { return title }
        
        switch strategy {
        case .firstPart:
            return extractFirstPart(from: title)
            
        case .lastPart:
            return extractLastPart(from: title)
            
        case .beforeFirstSeparator:
            return extractBeforeFirstSeparator(from: title)
            
        case .afterLastSeparator:
            return extractAfterLastSeparator(from: title)
            
        case .fullTitle:
            return title
            
        case .customSeparator:
            guard let separator = customSeparator else { return title }
            return extractUsingCustomSeparator(from: title, separator: separator)
        }
    }
    
    private func extractFirstPart(from title: String) -> String {
        let commonSeparators = [" - ", " — ", " | ", " / ", " \\ "]
        
        for separator in commonSeparators {
            if let range = title.range(of: separator) {
                return String(title[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
        }
        
        return title
    }
    
    private func extractLastPart(from title: String) -> String {
        let commonSeparators = [" - ", " — ", " | ", " / ", " \\ "]
        
        for separator in commonSeparators {
            if let range = title.range(of: separator, options: .backwards) {
                return String(title[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        }
        
        return title
    }
    
    private func extractBeforeFirstSeparator(from title: String) -> String {
        let commonSeparators = [" — ", " - ", " | ", " / ", " \\ "]
        
        for separator in commonSeparators {
            if let range = title.range(of: separator) {
                return String(title[..<range.lowerBound]).trimmingCharacters(in: .whitespaces)
            }
        }
        
        return title
    }
    
    private func extractAfterLastSeparator(from title: String) -> String {
        let commonSeparators = [" — ", " - ", " | ", " / ", " \\ "]
        
        for separator in commonSeparators {
            if let range = title.range(of: separator, options: .backwards) {
                return String(title[range.upperBound...]).trimmingCharacters(in: .whitespaces)
            }
        }
        
        return title
    }
    
    private func extractUsingCustomSeparator(from title: String, separator: String) -> String {
        if let range = title.range(of: separator, options: .backwards) {
            return String(title[range.upperBound...]).trimmingCharacters(in: .whitespaces)
        }
        
        return title
    }
}