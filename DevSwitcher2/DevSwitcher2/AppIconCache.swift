//
//  AppIconCache.swift
//  DevSwitcher2
//
//  Created by river on 2025-07-27.
//

import Foundation
import AppKit

// MARK: - 应用图标缓存管理器
class AppIconCache: ObservableObject {
    static let shared = AppIconCache()
    private var iconCache: [pid_t: NSImage] = [:]
    
    private init() {}
    
    func getIcon(for processID: pid_t) -> NSImage? {
        if let cachedIcon = iconCache[processID] {
            return cachedIcon
        }
        
        // 如果缓存中没有，尝试获取并缓存
        if let app = NSRunningApplication(processIdentifier: processID),
           let icon = app.icon {
            iconCache[processID] = icon
            return icon
        }
        
        return nil
    }
    
    func clearCache() {
        iconCache.removeAll()
        print("🗑️ 应用图标缓存已清除")
    }
}