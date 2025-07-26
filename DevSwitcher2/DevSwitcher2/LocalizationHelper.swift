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
    // 窗口切换器界面
    static let windowSwitcherTitle = "window_switcher_title".localized
    static let hotkeyHint = "hotkey_hint".localized
    static let cancelHint = "cancel_hint".localized
    static let selectHint = "select_hint".localized
    
    // 状态栏
    static let statusItemTooltip = "status_item_tooltip".localized
    
    // 权限提示
    static let accessibilityPermissionRequired = "accessibility_permission_required".localized
    static let openSystemPreferences = "open_system_preferences".localized
    
    // 错误信息
    static let noWindowsFound = "no_windows_found".localized
    static let hotkeyRegistrationFailed = "hotkey_registration_failed".localized
    static let hotkeyRegistrationSuccess = "hotkey_registration_success".localized
} 