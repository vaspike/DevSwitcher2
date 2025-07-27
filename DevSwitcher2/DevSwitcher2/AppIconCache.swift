//
//  AppIconCache.swift
//  DevSwitcher2
//
//  Created by river on 2025-07-27.
//

import Foundation
import AppKit

// MARK: - 缓存项数据结构
private struct CacheItem {
    let icon: NSImage
    var lastAccessTime: Date
    
    init(icon: NSImage) {
        self.icon = icon
        self.lastAccessTime = Date()
    }
    
    mutating func updateAccessTime() {
        self.lastAccessTime = Date()
    }
}

// MARK: - 应用图标缓存管理器
class AppIconCache: ObservableObject {
    static let shared = AppIconCache()
    
    // 缓存配置
    private let maxCacheSize = 50  // 最多缓存50个图标
    private let cacheCleanupThreshold = 60  // 当达到60个图标时开始清理
    
    // 使用CacheItem来跟踪访问时间，实现LRU
    private var iconCache: [pid_t: CacheItem] = [:]
    private let cacheQueue = DispatchQueue(label: "com.devswitcher2.iconcache", qos: .utility)
    private var cleanupTimer: Timer? // 管理清理定时器
    
    private init() {
        setupApplicationTerminationMonitoring()
        setupMemoryWarningMonitoring()
    }
    
    deinit {
        // 清理定时器
        cleanupTimer?.invalidate()
        cleanupTimer = nil
        
        // 移除通知观察者
        NotificationCenter.default.removeObserver(self)
        
        print("🗑️ AppIconCache已清理，释放了 \(iconCache.count) 个图标和相关资源")
    }
    
    // MARK: - 公共接口
    func getIcon(for processID: pid_t) -> NSImage? {
        return cacheQueue.sync {
            // 如果缓存中有，更新访问时间并返回
            if var cachedItem = iconCache[processID] {
                cachedItem.updateAccessTime()
                iconCache[processID] = cachedItem
                return cachedItem.icon
            }
            
            // 验证进程仍然存在
            guard let app = NSRunningApplication(processIdentifier: processID),
                  let icon = app.icon else {
                return nil
            }
            
            // 添加到缓存前检查大小
            checkAndCleanupCache()
            
            // 缓存新图标
            iconCache[processID] = CacheItem(icon: icon)
            print("📦 缓存应用图标: \(app.localizedName ?? "Unknown") (PID: \(processID)), 当前缓存大小: \(iconCache.count)")
            
            return icon
        }
    }
    
    func clearCache() {
        cacheQueue.sync {
            let oldCount = iconCache.count
            iconCache.removeAll()
            print("🗑️ 应用图标缓存已清除，释放了 \(oldCount) 个图标")
        }
    }
    
    func getCacheInfo() -> (count: Int, maxSize: Int) {
        return cacheQueue.sync {
            return (count: iconCache.count, maxSize: maxCacheSize)
        }
    }
    
    // MARK: - 私有方法
    
    // 检查缓存大小并在必要时清理
    private func checkAndCleanupCache() {
        guard iconCache.count >= cacheCleanupThreshold else { return }
        
        print("🧹 开始LRU缓存清理，当前大小: \(iconCache.count)")
        
        // 按最后访问时间排序，最久未访问的在前
        let sortedEntries = iconCache.sorted { $0.value.lastAccessTime < $1.value.lastAccessTime }
        
        // 保留最近访问的maxCacheSize个项目
        let itemsToKeep = Array(sortedEntries.suffix(maxCacheSize))
        var newCache: [pid_t: CacheItem] = [:]
        for (key, value) in itemsToKeep {
            newCache[key] = value
        }
        
        let removedCount = iconCache.count - newCache.count
        iconCache = newCache
        
        print("🧹 LRU清理完成，移除 \(removedCount) 个图标，当前大小: \(iconCache.count)")
    }
    
    // 清理已终止进程的图标
    private func cleanupTerminatedProcesses() {
        cacheQueue.async {
            let runningProcesses = Set(NSWorkspace.shared.runningApplications.map { $0.processIdentifier })
            let cachedProcesses = Set(self.iconCache.keys)
            let terminatedProcesses = cachedProcesses.subtracting(runningProcesses)
            
            for pid in terminatedProcesses {
                self.iconCache.removeValue(forKey: pid)
            }
            
            if !terminatedProcesses.isEmpty {
                print("🗑️ 清理已终止进程图标: \(terminatedProcesses.count) 个，当前缓存大小: \(self.iconCache.count)")
            }
        }
    }
    
    // MARK: - 系统监听设置
    
    private func setupApplicationTerminationMonitoring() {
        // 监听应用终止通知
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidTerminate(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
        
        // 定期清理已终止进程的缓存（每30秒）
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.cleanupTerminatedProcesses()
        }
    }
    
    private func setupMemoryWarningMonitoring() {
        // 监听内存压力警告（使用系统通知）
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: NSApplication.didBecomeActiveNotification, // 作为替代，也可以定期清理
            object: nil
        )
    }
    
    @objc private func applicationDidTerminate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        cacheQueue.async {
            if self.iconCache.removeValue(forKey: app.processIdentifier) != nil {
                print("🗑️ 移除已终止应用图标: \(app.localizedName ?? "Unknown") (PID: \(app.processIdentifier))")
            }
        }
    }
    
    @objc private func handleMemoryWarning() {
        print("⚠️ 收到内存警告，清理图标缓存")
        cacheQueue.async {
            // 在内存警告时，清理一半的缓存
            let targetSize = max(self.maxCacheSize / 2, 10)
            let sortedEntries = self.iconCache.sorted { $0.value.lastAccessTime < $1.value.lastAccessTime }
            let itemsToKeep = Array(sortedEntries.suffix(targetSize))
            
            let oldCount = self.iconCache.count
            var newCache: [pid_t: CacheItem] = [:]
            for (key, value) in itemsToKeep {
                newCache[key] = value
            }
            self.iconCache = newCache
            
            print("⚠️ 内存警告清理完成，从 \(oldCount) 减少到 \(self.iconCache.count) 个图标")
        }
    }
}