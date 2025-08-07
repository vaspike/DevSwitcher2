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
    static let languageSectionTitle = "language_section_title".localized
    static let languageSelectionLabel = "language_selection_label".localized
    static let languageRestartNote = "language_restart_note".localized
    static let languageRestartNowButton = "language_restart_now_button".localized
    
    // MARK: - General Settings
    static let generalSettingsSectionTitle = "general_settings_section_title".localized
    static let launchAtStartup = "launch_at_startup".localized
    static let launchAtStartupDescription = "launch_at_startup_description".localized
    
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
    
    // MARK: - Restart Required
    static let restartRequiredTitle = "restart_required_title".localized
    static let restartRequiredMessage = "restart_required_message".localized
    static let restartNow = "restart_now".localized
    static let restartLater = "restart_later".localized
    
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
    static let preferencesSubtitle = "preferences_subtitle".localized
    static let generalSettingsTabTitle = "general_settings_tab_title".localized
    static let advancedSettingsTabTitle = "advanced_settings_tab_title".localized
    static let aboutTabTitle = "about_tab_title".localized
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
    static let modifierKeyLabel = "modifier_key_label".localized
    static let triggerKeyLabel = "trigger_key_label".localized
    static func currentHotkeyDisplay(_ modifier: String, _ trigger: String) -> String {
        return "current_hotkey_display".localized(with: modifier, trigger)
    }
    
    // MARK: - CT2 Settings
    static let ct2AppSwitcher = "ct2_app_switcher".localized
    static let enableCT2 = "enable_ct2".localized
    static let currentCT2Hotkey = "current_ct2_hotkey".localized
    static let ct2FunctionDisabled = "ct2_function_disabled".localized
    static let ct2DisabledMessage = "ct2_disabled_message".localized
    
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
    
    // MARK: - Separator Placeholders for Different Strategies
    static let separatorPlaceholderFirstLastPart = "separator_placeholder_first_last_part".localized
    static let separatorPlaceholderBeforeFirst = "separator_placeholder_before_first".localized
    static let separatorPlaceholderAfterLast = "separator_placeholder_after_last".localized
    
    // MARK: - Separator Help Text for Different Strategies
    static let separatorHelpFirstPart = "separator_help_first_part".localized
    static let separatorHelpLastPart = "separator_help_last_part".localized
    static let separatorHelpBeforeFirst = "separator_help_before_first".localized
    static let separatorHelpAfterLast = "separator_help_after_last".localized
    
    // MARK: - Preview Functionality
    static let preview = "preview".localized
    static let previewWindowTitles = "preview_window_titles".localized
    static let selectWindowTitle = "select_window_title".localized
    static let appNotRunning = "app_not_running".localized
    static let extractionResult = "extraction_result".localized
    static let copyTitle = "copy_title".localized
    static let selectedTitle = "selected_title".localized
    static let currentStrategy = "current_strategy".localized
    static let currentSeparator = "current_separator".localized
    static let loading = "loading".localized
    
    // MARK: - App Selection UI
    static let selectFromInstalledApps = "select_from_installed_apps".localized
    static let selectApplicationPlaceholder = "select_application_placeholder".localized
    static let searchApplications = "search_applications".localized
    static let noApplicationsFound = "no_applications_found".localized
    static let noSearchResults = "no_search_results".localized
    static let moreThan50Results = "more_than_50_results".localized
    static let loadingAppsHint = "loading_apps_hint".localized
    
    // MARK: - Add App Config Dialog Section Titles
    static let appSelectionSection = "app_selection_section".localized
    static let basicInfoSection = "basic_info_section".localized
    static let extractionStrategySection = "extraction_strategy_section".localized
    static let previewResultsSection = "preview_results_section".localized
    
    // MARK: - Configuration Export/Import
    static let exportConfig = "export_config".localized
    static let importConfig = "import_config".localized
    static let exportConfiguration = "export_configuration".localized
    static let importConfiguration = "import_configuration".localized
    static let chooseExportLocation = "choose_export_location".localized
    static let chooseImportFile = "choose_import_file".localized
    static let fileName = "file_name".localized
    static let exportSuccess = "export_success".localized
    static let exportFailed = "export_failed".localized
    static let importSuccess = "import_success".localized
    static let importFailed = "import_failed".localized
    static let importNoData = "import_no_data".localized
    static let importPartialSuccess = "import_partial_success".localized
    static let exportEncodingError = "export_encoding_error".localized
    static let importDecodingError = "import_decoding_error".localized
    static let fileReadError = "file_read_error".localized
    static let invalidFileFormat = "invalid_file_format".localized
    static let operationCancelled = "operation_cancelled".localized
    static let importNoDataMessage = "import_no_data_message".localized
    
    // 带参数的消息
    static func exportSuccessMessage(_ fileName: String) -> String {
        return "export_success_message".localized(with: fileName)
    }
    
    static func importSuccessMessage(_ newConfigs: Int, _ updatedConfigs: Int) -> String {
        return "import_success_message".localized(with: newConfigs, updatedConfigs)
    }
    
    static func importPartialSuccessMessage(_ totalImported: Int) -> String {
        return "import_partial_success_message".localized(with: totalImported)
    }
    
    // MARK: - Additional UI Labels
    static func separatorLabel(_ separator: String) -> String {
        return "separator_label".localized(with: separator)
    }
    static let defaultStrategyApply = "default_strategy_apply".localized
    static let appConfigImport = "app_config_import".localized
    static let appConfigExport = "app_config_export".localized
    static let appConfigAdd = "app_config_add".localized
    static let noAppConfigsMessage = "no_app_configs_message".localized
    static let windowTitleSectionTitle = "window_title_section_title".localized
    static let defaultStrategyDescription = "default_strategy_description".localized
    static let appConfigsDescription = "app_configs_description".localized
    static let extractionStrategyLabel = "extraction_strategy_label".localized
    static let customSeparatorLabel = "custom_separator_label".localized
    static let separatorExample = "separator_example".localized
    static let deleteConfigTooltip = "delete_config_tooltip".localized
    static let ds2HotkeySectionTitle = "ds2_hotkey_section_title".localized
    static let ds2HotkeyDescription = "ds2_hotkey_description".localized
    static let ct2HotkeySectionTitle = "ct2_hotkey_section_title".localized
    static let ct2EnableToggle = "ct2_enable_toggle".localized
    static let ct2HotkeyDescription = "ct2_hotkey_description".localized
    static let hotkeyApply = "hotkey_apply".localized
    static let hotkeyReset = "hotkey_reset".localized
    
    // MARK: - Switcher Display Settings
    static let switcherDisplaySectionTitle = "switcher_display_section_title".localized
    static let showNumberKeysLabel = "show_number_keys_label".localized
    static let showNumberKeysDescription = "show_number_keys_description".localized
    
    // MARK: - Switcher Behavior Settings
    static let switcherBehaviorSectionTitle = "switcher_behavior_section_title".localized
    static let followActiveWindowLabel = "follow_active_window_label".localized
    static let followActiveWindowDescription = "follow_active_window_description".localized
    
    // MARK: - Switcher Position Settings
    static let switcherVerticalPositionLabel = "switcher_vertical_position_label".localized
    static let switcherVerticalPositionDescription = "switcher_vertical_position_description".localized
    static let resetToGoldenRatio = "reset_to_golden_ratio".localized
    
    // MARK: - Switcher Header Style Settings
    static let switcherHeaderStyleLabel = "switcher_header_style_label".localized
    static let switcherHeaderStyleDescription = "switcher_header_style_description".localized
    static let headerStyleDefault = "header_style_default".localized
    static let headerStyleSimplified = "header_style_simplified".localized
    
    // MARK: - Switcher Layout Style Settings
    static let switcherLayoutStyleLabel = "switcher_layout_style_label".localized
    static let switcherLayoutStyleDescription = "switcher_layout_style_description".localized
    static let layoutStyleList = "layout_style_list".localized
    static let layoutStyleCircular = "layout_style_circular".localized
    
    // MARK: - Circular Layout Size Settings
    static let circularLayoutSizeLabel = "circular_layout_size_label".localized
    static let circularLayoutSizeDescription = "circular_layout_size_description".localized
    
    // MARK: - Circular Layout Outer Ring Transparency Settings
    static let circularLayoutOuterRingTransparencyLabel = "circular_layout_outer_ring_transparency_label".localized
    static let circularLayoutOuterRingTransparencyDescription = "circular_layout_outer_ring_transparency_description".localized
    static let circularLayoutOuterRingTransparencyStrongBlur = "circular_layout_outer_ring_transparency_strong_blur".localized
    static let circularLayoutOuterRingTransparencyOpaque = "circular_layout_outer_ring_transparency_opaque".localized
    
    // MARK: - About Page
    static let aboutApp = "about_app".localized
    static let version = "version".localized
    static let appDescription = "app_description".localized
    static let mainFeatures = "main_features".localized
    static let feature1 = "feature_1".localized
    static let feature2 = "feature_2".localized
    static let feature3 = "feature_3".localized
    static let feature4 = "feature_4".localized
    static let feature5 = "feature_5".localized
    static let feature6 = "feature_6".localized
    static let developmentInfo = "development_info".localized
    static let author = "author".localized
    static let gitHub = "github".localized
    static let openGitHub = "open_github".localized
    static let website = "website".localized
    static let openWebsite = "open_website".localized
    static let buyMeCoffee = "buy_me_coffee".localized
    static let supportDevelopment = "support_development".localized
    static let coffeeDescription = "coffee_description".localized
    static let copyright = "copyright".localized
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let languageChanged = Notification.Name("languageChanged")
} 