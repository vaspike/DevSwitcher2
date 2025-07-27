//
//  LocalizationHelper.swift
//  DevSwitcher2
//
//  Created by river on 2025-07-26.
//

import Foundation

extension String {
    var localized: String {
        return NSLocalizedString(self, comment: "")
    }
    
    func localized(with arguments: CVarArg...) -> String {
        return String(format: NSLocalizedString(self, comment: ""), arguments: arguments)
    }
}

struct LocalizedStrings {
    // DS2窗口切换器界面
    static let windowSwitcherTitle = "window_switcher_title".localized
    static func hotkeyHintTemplate(_ modifier: String, _ trigger: String) -> String {
        return "hotkey_hint_template".localized(with: modifier, trigger)
    }
    static let cancelHint = "cancel_hint".localized
    static let selectHint = "select_hint".localized
    
    // CT2应用切换器界面
    static let appSwitcherTitle = "app_switcher_title".localized
    static func ct2HotkeyHintTemplate(_ modifier: String) -> String {
        return "ct2_hotkey_hint_template".localized(with: modifier)
    }
    static let ct2CancelHint = "ct2_cancel_hint".localized
    static let ct2SelectHint = "ct2_select_hint".localized
    
    // 应用项显示
    static let singleWindow = "single_window".localized
    static func multipleWindows(_ count: Int) -> String {
        return "multiple_windows".localized(with: count)
    }
    
    // 状态栏
    static let statusItemTooltip = "status_item_tooltip".localized
    
    // 权限提示
    static let accessibilityPermissionRequired = "accessibility_permission_required".localized
    static let openSystemPreferences = "open_system_preferences".localized
    
    // 错误信息
    static let noWindowsFound = "no_windows_found".localized
    static let hotkeyRegistrationFailed = "hotkey_registration_failed".localized
    static let hotkeyRegistrationSuccess = "hotkey_registration_success".localized
    
    // 菜单栏
    static let preferences = "preferences".localized
    static let quitApp = "quit_app".localized
    
    // 偏好设置
    static let preferencesTitle = "preferences_title".localized
    static let coreSettings = "core_settings".localized
    static let about = "about".localized
    static let hotkeySettings = "hotkey_settings".localized
    static let windowTitleConfig = "window_title_config".localized
    static let modifierKey = "modifier_key".localized
    static let triggerKey = "trigger_key".localized
    static let apply = "apply".localized
    static let reset = "reset".localized
    static let currentHotkey = "current_hotkey".localized
    
    // 窗口标题配置
    static let defaultExtractionStrategy = "default_extraction_strategy".localized
    static let appSpecificConfig = "app_specific_config".localized
    static let addApp = "add_app".localized
    static let noAppConfigs = "no_app_configs".localized
    static let strategy = "strategy".localized
    static let delete = "delete".localized
    
    // 添加应用配置对话框
    static let addAppConfig = "add_app_config".localized
    static let bundleId = "bundle_id".localized
    static let appName = "app_name".localized
    static let extractionStrategy = "extraction_strategy".localized
    static let customSeparator = "custom_separator".localized
    static let cancel = "cancel".localized
    static let save = "save".localized
    
    // 关于页面
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