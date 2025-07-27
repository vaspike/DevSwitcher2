//
//  CompatibilityExtensions.swift
//  DevSwitcher2
//
//  Created for macOS version compatibility
//

import Foundation
import AppKit

// MARK: - NSApplication Compatibility Extension
extension NSApplication {
    /// 兼容性activate方法，支持macOS 12.0+
    func activateCompat() {
        if #available(macOS 14.0, *) {
            self.activate()
        } else {
            self.activate(ignoringOtherApps: true)
        }
    }
}

// MARK: - macOS Version Utilities
struct MacOSVersion {
    static let current = ProcessInfo.processInfo.operatingSystemVersion
    
    static var isMontereyOrLater: Bool {
        return current.majorVersion >= 12
    }
    
    static var isVenturaOrLater: Bool {
        return current.majorVersion >= 13
    }
    
    static var isSonomaOrLater: Bool {
        return current.majorVersion >= 14
    }
    
    static var displayString: String {
        return "\(current.majorVersion).\(current.minorVersion).\(current.patchVersion)"
    }
} 