//
//  LocalizationHelper.swift
//  DevSwitcher2
//
//  Created by river on 2025-07-26.
//

import Foundation
import SwiftUI

// MARK: - Language Manager
class LanguageManager: ObservableObject {
    @Published var currentLanguage: AppLanguage = .system
    
    static let shared = LanguageManager()
    private let userDefaults = UserDefaults.standard
    private let languageKey = "DevSwitcher2Language"
    
    private init() {
        if let languageString = userDefaults.string(forKey: languageKey),
           let language = AppLanguage(rawValue: languageString) {
            self.currentLanguage = language
        }
        applyLanguage()
    }
    
    func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
        userDefaults.set(language.rawValue, forKey: languageKey)
        applyLanguage()
        
        // Notify app to update UI
        NotificationCenter.default.post(name: .languageChanged, object: nil)
    }
    
    private func applyLanguage() {
        let languageCode = currentLanguage.languageCode
        UserDefaults.standard.set([languageCode], forKey: "AppleLanguages")
        UserDefaults.standard.synchronize()
    }
}

// MARK: - App Supported Languages
enum AppLanguage: String, CaseIterable {
    case system = "system"
    case english = "en"
    case chinese = "zh-Hans"
    
    var displayName: String {
        switch self {
        case .system:
            return "language_system".localized
        case .english:
            return "language_english".localized
        case .chinese:
            return "language_chinese".localized
        }
    }
    
    var languageCode: String {
        switch self {
        case .system:
            return Locale.preferredLanguages.first?.prefix(2).description ?? "en"
        case .english:
            return "en"
        case .chinese:
            return "zh-Hans"
        }
    }
}

extension String {
    var localized: String {
        let language = LanguageManager.shared.currentLanguage
        if language == .system {
            return NSLocalizedString(self, comment: "")
        }
        
        guard let path = Bundle.main.path(forResource: language.languageCode, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return NSLocalizedString(self, comment: "")
        }
        
        return NSLocalizedString(self, tableName: nil, bundle: bundle, comment: "")
    }
    
    func localized(with arguments: CVarArg...) -> String {
        return String(format: self.localized, arguments: arguments)
    }
}

struct LocalizedStrings {
    // MARK: - Language Settings
    static let language = "language".localized
    static let languageSystem = "language_system".localized
    static let languageEnglish = "language_english".localized
    static let languageChinese = "language_chinese".localized
    static let languageRestartHint = "language_restart_hint".localized
    
    // MARK: - DS2 Window Switcher Interface
    static let windowSwitcherTitle = "window_switcher_title".localized
    static func hotkeyHintTemplate(_ modifier: String, _ trigger: String) -> String {
        return "hotkey_hint_template".localized(with: modifier, trigger)
    }
    static let cancelHint = "cancel_hint".localized
    static let selectHint = "select_hint".localized
    
    // MARK: - CT2 App Switcher Interface
    static let appSwitcherTitle = "app_switcher_title".localized
    static func ct2HotkeyHintTemplate(_ modifier: String) -> String {
        return "ct2_hotkey_hint_template".localized(with: modifier)
    }
    static let ct2CancelHint = "ct2_cancel_hint".localized
    static let ct2SelectHint = "ct2_select_hint".localized
    
    // MARK: - App Item Display
    static let singleWindow = "single_window".localized
    static func multipleWindows(_ count: Int) -> String {
        return "multiple_windows".localized(with: count)
    }
    
    // MARK: - Status Bar
    static let statusItemTooltip = "status_item_tooltip".localized
    
    // MARK: - Permission Prompts
    static let accessibilityPermissionRequired = "accessibility_permission_required".localized
    static let openSystemPreferences = "open_system_preferences".localized
    static let accessibilityPermissionTitle = "accessibility_permission_title".localized
    static let accessibilityPermissionMessage = "accessibility_permission_message".localized
    static let openSystemPreferencesButton = "open_system_preferences_button".localized
    static let setupLater = "setup_later".localized
    static let accessibilityPermissionGranted = "accessibility_permission_granted".localized
    
    // MARK: - Error Messages
    static let noWindowsFound = "no_windows_found".localized
    static let hotkeyRegistrationFailed = "hotkey_registration_failed".localized
    static let hotkeyRegistrationSuccess = "hotkey_registration_success".localized
    static let hotkeyConflictTitle = "hotkey_conflict_title".localized
    static let hotkeyConflictMessage = "hotkey_conflict_message".localized
    static let confirm = "confirm".localized
    
    // MARK: - Menu Bar
    static let preferences = "preferences".localized
    static let quitApp = "quit_app".localized
    
    // MARK: - Preferences
    static let preferencesTitle = "preferences_title".localized
    static let coreSettings = "core_settings".localized
    static let about = "about".localized
    static let hotkeySettings = "hotkey_settings".localized
    static let windowTitleConfig = "window_title_config".localized
    static let modifierKey = "modifier_key".localized
    static let triggerKey = "trigger_key".localized
    static let apply = "apply".localized
    static let reset = "reset".localized
    static let configuration = "configuration".localized
    static let currentHotkey = "current_hotkey".localized
    
    // MARK: - DS2 Settings
    static let ds2SameAppWindowSwitching = "ds2_same_app_window_switching".localized
    static let currentDS2Hotkey = "current_ds2_hotkey".localized
    
    // MARK: - CT2 Settings
    static let ct2AppSwitcher = "ct2_app_switcher".localized
    static let enableCT2 = "enable_ct2".localized
    static let currentCT2Hotkey = "current_ct2_hotkey".localized
    static let ct2FunctionDisabled = "ct2_function_disabled".localized
    
    // MARK: - Modifier Keys
    static let modifierCommand = "modifier_command".localized
    static let modifierOption = "modifier_option".localized
    static let modifierControl = "modifier_control".localized
    static let modifierFunction = "modifier_function".localized
    
    // MARK: - Trigger Keys
    static let triggerGrave = "trigger_grave".localized
    static let triggerTab = "trigger_tab".localized
    static let triggerSpace = "trigger_space".localized
    static let triggerSemicolon = "trigger_semicolon".localized
    static let triggerQuote = "trigger_quote".localized
    static let triggerComma = "trigger_comma".localized
    static let triggerPeriod = "trigger_period".localized
    static let triggerSlash = "trigger_slash".localized
    static let triggerBackslash = "trigger_backslash".localized
    static let triggerLeftBracket = "trigger_left_bracket".localized
    static let triggerRightBracket = "trigger_right_bracket".localized
    
    // MARK: - Window Title Configuration
    static let defaultExtractionStrategy = "default_extraction_strategy".localized
    static let appSpecificConfig = "app_specific_config".localized
    static let addApp = "add_app".localized
    static let noAppConfigs = "no_app_configs".localized
    static let strategy = "strategy".localized
    static let delete = "delete".localized
    
    // MARK: - Title Extraction Strategies
    static let strategyFirstPart = "strategy_first_part".localized
    static let strategyLastPart = "strategy_last_part".localized
    static let strategyBeforeFirstSeparator = "strategy_before_first_separator".localized
    static let strategyAfterLastSeparator = "strategy_after_last_separator".localized
    static let strategyFullTitle = "strategy_full_title".localized
    static let strategyCustomSeparator = "strategy_custom_separator".localized
    
    // MARK: - Add App Configuration Dialog
    static let addAppConfig = "add_app_config".localized
    static let bundleId = "bundle_id".localized
    static let appName = "app_name".localized
    static let extractionStrategy = "extraction_strategy".localized
    static let customSeparator = "custom_separator".localized
    static let cancel = "cancel".localized
    static let save = "save".localized
    static let bundleIdPlaceholder = "bundle_id_placeholder".localized
    static let appNamePlaceholder = "app_name_placeholder".localized
    static let customSeparatorPlaceholder = "custom_separator_placeholder".localized
    
    // MARK: - About Page
    static let aboutApp = "about_app".localized
    static let version = "version".localized
    static let appDescription = "app_description".localized
    static let mainFeatures = "main_features".localized
    static let feature1 = "feature_1".localized
    static let feature2 = "feature_2".localized
    static let feature3 = "feature_3".localized
    static let feature4 = "feature_4".localized
    static let developmentInfo = "development_info".localized
    static let copyright = "copyright".localized
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let languageChanged = Notification.Name("languageChanged")
} 