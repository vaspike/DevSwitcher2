//
//  WindowManager.swift
//  DevSwitcher2
//
//  Created by river on 2025-07-26.
//

import Foundation
import AppKit
import CoreGraphics
import SwiftUI
import ApplicationServices

struct WindowInfo {
    let windowID: CGWindowID
    let title: String
    let projectName: String
    let appName: String
    let processID: pid_t
    let axWindowIndex: Int  // AX window index
}

class WindowManager: ObservableObject {
    @Published var windows: [WindowInfo] = []
    @Published var isShowingSwitcher = false
    @Published var currentWindowIndex = 0
    
    // CT2 related properties
    @Published var apps: [AppInfo] = []
    @Published var isShowingAppSwitcher = false
    @Published var currentAppIndex = 0
    
    private var switcherWindow: NSWindow?
    private var eventMonitor: Any?
    private var globalEventMonitor: Any?
    
    // Current view type tracking
    private var currentViewType: SwitcherType = .ds2
    
    // Event handling state management
    private var isProcessingKeyEvent = false
    private var lastModifierEventTime = Date()
    
    // Modifier key watchdog mechanism
    private var modifierKeyWatchdog: Timer?
    private let watchdogInterval: TimeInterval = 0.016 // 16ms ≈ 60Hz
    private var watchdogCallCount = 0
    private var watchdogPhase = 0
    private var lastSwitchTime = Date()
    
    // AX element cache item structure
    private struct AXCacheItem {
        let element: AXUIElement
        let processID: pid_t
        var lastAccessTime: Date
        
        init(element: AXUIElement, processID: pid_t) {
            self.element = element
            self.processID = processID
            self.lastAccessTime = Date()
        }
        
        mutating func updateAccessTime() {
            self.lastAccessTime = Date()
        }
    }
    
    // Improved AX element cache with more metadata
    private var axElementCache: [CGWindowID: AXCacheItem] = [:]
    private let maxAXCacheSize = 100  // Maximum cache of 100 AX elements
    private let axCacheCleanupThreshold = 120  // Start cleanup when reaching 120
    
    // Weak reference to HotkeyManager to avoid circular reference
    weak var hotkeyManager: HotkeyManager?
    
    // Settings manager
    private let settingsManager = SettingsManager.shared
    
    init() {
        setupSwitcherWindow()
    }
    
    deinit {
        // Ensure event listeners are cleaned up
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let globalMonitor = globalEventMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        
        // Clean up watchdog timer
        stopModifierKeyWatchdog()
        
        // Clean up AX cache
        Logger.log("🗑️ WindowManager cleanup, releasing \(axElementCache.count) AX elements")
        axElementCache.removeAll()
    }
    
    // MARK: - AX Cache Management Methods
    
    // Smart AX cache cleanup
    private func cleanupAXCache() {
        guard axElementCache.count >= axCacheCleanupThreshold else { return }
        
        Logger.log("🧹 Starting AX cache LRU cleanup, current size: \(axElementCache.count)")
        
        // Get set of currently running application process IDs
        let runningProcesses = Set(NSWorkspace.shared.runningApplications.map { $0.processIdentifier })
        
        // First remove cache items for terminated processes
        var itemsToRemove: [CGWindowID] = []
        for (windowID, cacheItem) in axElementCache {
            if !runningProcesses.contains(cacheItem.processID) {
                itemsToRemove.append(windowID)
            }
        }
        
        for windowID in itemsToRemove {
            axElementCache.removeValue(forKey: windowID)
        }
        
        let afterProcessCleanup = axElementCache.count
        Logger.log("🗑️ Removing AX elements for terminated processes: \(itemsToRemove.count) items")
        
        // If still over limit, perform LRU cleanup
        if axElementCache.count > maxAXCacheSize {
            let sortedEntries = axElementCache.sorted { $0.value.lastAccessTime < $1.value.lastAccessTime }
            let itemsToKeep = Array(sortedEntries.suffix(maxAXCacheSize))
            var newCache: [CGWindowID: AXCacheItem] = [:]
            for (key, value) in itemsToKeep {
                newCache[key] = value
            }
            
            let lruRemovedCount = axElementCache.count - newCache.count
            axElementCache = newCache
            
            Logger.log("🧹 LRU cleanup completed, removed \(lruRemovedCount) AX elements, current size: \(axElementCache.count)")
        }
    }
    
    // Get or cache AX element
    private func getCachedAXElement(windowID: CGWindowID, processID: pid_t, windowIndex: Int) -> AXUIElement? {
        // Check if exists in cache and update access time
        if var cachedItem = axElementCache[windowID] {
            cachedItem.updateAccessTime()
            axElementCache[windowID] = cachedItem
            return cachedItem.element
        }
        
        // Not in cache, get new AX element
        let (_, axElement) = getAXWindowInfo(windowID: windowID, processID: processID, windowIndex: windowIndex)
        
        if let element = axElement {
            // Check if cleanup is needed before adding to cache
            cleanupAXCache()
            
            // Add to cache
            axElementCache[windowID] = AXCacheItem(element: element, processID: processID)
            Logger.log("📦 Caching AX element: WindowID \(windowID), current cache size: \(axElementCache.count)")
        }
        
        return axElement
    }
    
    // MARK: - Memory Optimized View Creation Methods
    
    // Create DS2 view
    private func createDS2HostingView() -> NSHostingView<DS2SwitcherView> {
        Logger.log("🆕 Creating DS2 HostingView")
        let contentView = DS2SwitcherView(windowManager: self)
        return NSHostingView(rootView: contentView)
    }
    
    // Create CT2 view
    private func createCT2HostingView() -> NSHostingView<CT2SwitcherView> {
        Logger.log("🆕 Creating CT2 HostingView")
        let contentView = CT2SwitcherView(windowManager: self)
        return NSHostingView(rootView: contentView)
    }
    
    private func setupSwitcherWindow() {
        let contentRect = NSRect(x: 0, y: 0, width: 600, height: 400)
        switcherWindow = NSWindow(
            contentRect: contentRect,
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        
        switcherWindow?.isReleasedWhenClosed = false
        switcherWindow?.level = .floating
        switcherWindow?.backgroundColor = NSColor.clear
        switcherWindow?.hasShadow = true
        switcherWindow?.isOpaque = false
        
        // Initial content view will be set on first display
        switcherWindow?.contentView = NSView() // Temporary empty view
        
        // Center display
        switcherWindow?.center()
    }
    
    func showWindowSwitcher() {
        guard !isShowingSwitcher else { return }
        
        // 1. 清除旧缓存，确保一个干净的开始
        AppIconCache.shared.clearCache()
        
        // 2. 获取当前应用的窗口 (这会开始填充缓存)
        getCurrentAppWindows()
        
        if windows.isEmpty {
            Logger.log(LocalizedStrings.noWindowsFound)
            return
        }
        
        isShowingSwitcher = true
        // 默认选中第二个窗口（跳过当前窗口）
        currentWindowIndex = windows.count > 1 ? 1 : 0
        
        // 暂时禁用全局热键，避免冲突
        hotkeyManager?.temporarilyDisableHotkey()
        
        // 确保切换器窗口内容为DS2视图
        currentViewType = .ds2
        switcherWindow?.contentView = createDS2HostingView()
        
        // 显示切换器窗口
        switcherWindow?.makeKeyAndOrderFront(nil)
        NSApp.activateCompat()
        
        // 3. 延迟打印日志，以获取渲染后的真实缓存大小
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self, self.isShowingSwitcher else { return }
            let cacheInfo = AppIconCache.shared.getCacheInfo()
            let formattedSize = ByteCountFormatter.string(fromByteCount: Int64(cacheInfo.dataSize), countStyle: .memory)
            Logger.log("📊 DS2 icon cache status (after rendering): \(cacheInfo.count) / \(cacheInfo.maxSize), total size: \(formattedSize)")
        }
        
        // 使用统一的事件处理机制
        setupUnifiedEventHandling()
        
        // 启动修饰键看门狗机制（DS2）
        startModifierKeyWatchdog(for: .ds2)
    }
    
    func hideSwitcher() {
        // 保持向后兼容，内部调用异步版本
        hideSwitcherAsync()
    }
    
    // MARK: - CT2 Functionality: App Switcher Display and Hide
    func showAppSwitcher() {
        guard !isShowingAppSwitcher else { return }
        
        // 1. 清除旧缓存，确保一个干净的开始
        AppIconCache.shared.clearCache()
        
        // 2. 获取所有应用的窗口信息 (这会开始填充缓存)
        getAllAppsWithWindows()
        
        if apps.isEmpty {
            Logger.log("No applications with windows found")
            return
        }
        
        isShowingAppSwitcher = true
        // 默认选中第二个应用（跳过当前应用）
        currentAppIndex = apps.count > 1 ? 1 : 0
        
        // 暂时禁用全局热键，避免冲突
        hotkeyManager?.temporarilyDisableHotkey()
        
        // 更新切换器窗口内容为CT2视图
        currentViewType = .ct2
        switcherWindow?.contentView = createCT2HostingView()
        
        // 显示切换器窗口
        switcherWindow?.makeKeyAndOrderFront(nil)
        NSApp.activateCompat()
        
        // 3. 延迟打印日志，以获取渲染后的真实缓存大小
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self, self.isShowingAppSwitcher else { return }
            let cacheInfo = AppIconCache.shared.getCacheInfo()
            let formattedSize = ByteCountFormatter.string(fromByteCount: Int64(cacheInfo.dataSize), countStyle: .memory)
            Logger.log("📊 CT2 icon cache status (after rendering): \(cacheInfo.count) / \(cacheInfo.maxSize), total size: \(formattedSize)")
        }
        
        // 使用统一的事件处理机制
        setupUnifiedEventHandling()
        
        // 启动修饰键看门狗机制（CT2）
        startModifierKeyWatchdog(for: .ct2)
    }
    
    func hideAppSwitcher() {
        // 保持向后兼容，内部调用异步版本
        hideAppSwitcherAsync()
    }
    
    // 旧的事件处理方法已被统一的事件处理机制替代
    
    // 旧的CT2事件处理方法已被统一的事件处理机制替代
    
    func moveToNextWindow() {
        guard !windows.isEmpty else { return }
        let oldIndex = currentWindowIndex
        currentWindowIndex = (currentWindowIndex + 1) % windows.count
        Logger.log("🔄 moveToNextWindow: \(oldIndex) -> \(currentWindowIndex) (total: \(windows.count))")
    }
    
    func moveToPreviousWindow() {
        guard !windows.isEmpty else { return }
        currentWindowIndex = currentWindowIndex > 0 ? currentWindowIndex - 1 : windows.count - 1
    }
    
    func selectWindow(at index: Int) {
        guard index < windows.count else { return }
        currentWindowIndex = index
        hideSwitcher()
    }
    
    // MARK: - CT2 Functionality: App Switching Related Methods
    func moveToNextApp() {
        guard !apps.isEmpty else { return }
        let oldIndex = currentAppIndex
        currentAppIndex = (currentAppIndex + 1) % apps.count
        Logger.log("🔄 moveToNextApp: \(oldIndex) -> \(currentAppIndex) (total: \(apps.count))")
    }
    
    func moveToPreviousApp() {
        guard !apps.isEmpty else { return }
        currentAppIndex = currentAppIndex > 0 ? currentAppIndex - 1 : apps.count - 1
    }
    
    func selectApp(at index: Int) {
        guard index < apps.count else { return }
        currentAppIndex = index
        hideAppSwitcher()
    }
    
    // MARK: - EventTap Support Methods
    func selectNextApp() {
        moveToNextApp()
    }
    
    func selectPreviousApp() {
        moveToPreviousApp()
    }
    
    func activateSelectedApp() {
        hideAppSwitcher()
    }
    
    private func getCurrentAppWindows() {
        windows.removeAll()
        // 不再全量清空AX缓存，让智能清理机制处理
        
        // 打印所有运行的应用
        Logger.log("\n=== Debug Information Start ===")
        let allApps = NSWorkspace.shared.runningApplications
        // Logger.log("All running applications:")
        // for app in allApps {
        //     let isActive = app.isActive ? " [ACTIVE]" : ""
        //     let bundleId = app.bundleIdentifier ?? "Unknown"
        //     Logger.log("  - \(app.localizedName ?? "Unknown") (PID: \(app.processIdentifier), Bundle: \(bundleId))\(isActive)")
        // }
        
        // 获取前台应用（排除自己）
        let frontmostApp = allApps.first { app in
            app.isActive && app.bundleIdentifier != Bundle.main.bundleIdentifier
        }
        
        // 获取所有窗口（统一获取，避免重复调用）
        let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
        
        // 如果无法获取前台应用，则使用最前面窗口对应的应用
        let targetApp: NSRunningApplication
        if let frontApp = frontmostApp {
            targetApp = frontApp
            Logger.log("✅ Using frontmost application as target app")
        } else {
            Logger.log("⚠️ Cannot get frontmost application, trying to use application of the frontmost window")
            
            // 找到第一个有效的可见窗口的应用（排除自己）
            // windowList已经按z-order排序（最前面的窗口在前）
            var topWindowApp: NSRunningApplication?
            for windowInfo in windowList {
                guard let processID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                      let isOnScreen = windowInfo[kCGWindowIsOnscreen as String] as? Bool,
                      let layer = windowInfo[kCGWindowLayer as String] as? Int else { continue }
                
                // 过滤条件：在屏幕上、层级为0（正常窗口）、不是自己的进程
                if isOnScreen && layer == 0 {
                    if let app = allApps.first(where: { $0.processIdentifier == processID }),
                       app.bundleIdentifier != Bundle.main.bundleIdentifier {
                        topWindowApp = app
                        Logger.log("🔍 Found application of frontmost window: \(app.localizedName ?? "Unknown") (PID: \(processID))")
                        break
                    }
                }
            }
            
            guard let foundApp = topWindowApp else {
                Logger.log("❌ Cannot get any valid target application")
                return
            }
            
            targetApp = foundApp
        }
        
        Logger.log("\n🎯 Target application: \(targetApp.localizedName ?? "Unknown") (PID: \(targetApp.processIdentifier))")
        Logger.log("   Bundle ID: \(targetApp.bundleIdentifier ?? "Unknown")")
        Logger.log("\n📋 System found \(windowList.count) windows in total")
        
        // // 打印所有窗口信息
        // Logger.log("\n🔍 All window details:")
        // for (index, windowInfo) in windowList.enumerated() {
        //     let processID = windowInfo[kCGWindowOwnerPID as String] as? pid_t ?? -1
        //     let windowTitle = windowInfo[kCGWindowName as String] as? String ?? ""
        //     let layer = windowInfo[kCGWindowLayer as String] as? Int ?? -1
        //     let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID ?? 0
        //     let bounds = windowInfo[kCGWindowBounds as String] as? [String: Any]
        //     let width = (bounds?["Width"] as? NSNumber)?.intValue ?? 0
        //     let height = (bounds?["Height"] as? NSNumber)?.intValue ?? 0
        //     let ownerName = windowInfo[kCGWindowOwnerName as String] as? String ?? "Unknown"
        //     let isOnScreen = windowInfo[kCGWindowIsOnscreen as String] as? Bool ?? false
            
        //     let isTarget = processID == targetApp.processIdentifier ? " ⭐ [TARGET]" : ""
            
        //     Logger.log("  [\(index)] PID:\(processID) | Layer:\(layer) | Size:\(width)x\(height) | OnScreen:\(isOnScreen)")
        //     Logger.log("       Owner: \(ownerName)")
        //     Logger.log("       Title: '\(windowTitle)'\(isTarget)")
        //     Logger.log("       ID: \(windowID)")
        //     Logger.log("")
        // }
        
                 // 筛选目标应用的窗口
         var candidateWindows: [[String: Any]] = []
         var validWindows: [[String: Any]] = []
         var windowCounter = 1
         var validWindowIndex = 0  // 跟踪有效窗口的索引
        
        for windowInfo in windowList {
            guard let processID = windowInfo[kCGWindowOwnerPID as String] as? pid_t else { continue }
            
            if processID == targetApp.processIdentifier {
                candidateWindows.append(windowInfo)
                
                let windowTitle = windowInfo[kCGWindowName as String] as? String ?? ""
                let layer = windowInfo[kCGWindowLayer as String] as? Int ?? -1
                let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID ?? 0
                let isOnScreen = windowInfo[kCGWindowIsOnscreen as String] as? Bool ?? false
                
                Logger.log("🔎 Checking target application window:")
                Logger.log("   Title: '\(windowTitle)'")
                Logger.log("   Layer: \(layer)")
                Logger.log("   ID: \(windowID)")
                Logger.log("   OnScreen: \(isOnScreen)")
                
                                 // 检查过滤条件 - 允许空标题
                 let hasValidID = windowInfo[kCGWindowNumber as String] is CGWindowID
                 let hasValidLayer = layer >= 0
                 let bounds = windowInfo[kCGWindowBounds as String] as? [String: Any]
                 let width = (bounds?["Width"] as? NSNumber)?.intValue ?? 0
                 let height = (bounds?["Height"] as? NSNumber)?.intValue ?? 0
                 let hasReasonableSize = width > 100 && height > 100 // 过滤掉太小的窗口
                 
                 Logger.log("   Filter check: ID=\(hasValidID), Layer=\(hasValidLayer), Size=\(width)x\(height), ReasonableSize=\(hasReasonableSize)")
                 
                 if hasValidID && hasValidLayer && hasReasonableSize {
                    validWindows.append(windowInfo)
                    
                                         // 通过AX API获取窗口标题和AX元素
                     let (axTitle, _) = getAXWindowInfo(windowID: windowID, processID: processID, windowIndex: validWindowIndex)
                     
                     let displayTitle: String
                     let projectName: String
                     
                     if !axTitle.isEmpty {
                         displayTitle = axTitle
                         projectName = settingsManager.extractProjectName(
                             from: axTitle, 
                             bundleId: targetApp.bundleIdentifier ?? "", 
                             appName: targetApp.localizedName ?? ""
                         )
                     } else if !windowTitle.isEmpty {
                         displayTitle = windowTitle
                         projectName = settingsManager.extractProjectName(
                             from: windowTitle, 
                             bundleId: targetApp.bundleIdentifier ?? "", 
                             appName: targetApp.localizedName ?? ""
                         )
                     } else {
                         displayTitle = "\(targetApp.localizedName ?? "应用") 窗口 \(windowCounter)"
                         projectName = displayTitle
                         windowCounter += 1
                     }
                     
                     // AX元素会在getCachedAXElement中自动缓存
                    
                    let window = WindowInfo(
                        windowID: windowID,
                        title: displayTitle,
                        projectName: projectName,
                        appName: targetApp.localizedName ?? "",
                        processID: processID,
                        axWindowIndex: validWindowIndex
                    )
                    
                    windows.append(window)
                    Logger.log("   ✅ Window added: '\(projectName)'")
                    
                    validWindowIndex += 1  // 增加有效窗口索引
                } else {
                    Logger.log("   ❌ Window filtered out")
                }
                Logger.log("")
            }
        }
        
                 Logger.log("📊 Statistics result:")
         Logger.log("   Target application candidate windows: \(candidateWindows.count)")
         Logger.log("   Valid windows: \(validWindows.count)")
         Logger.log("   Final added windows: \(windows.count)")
         Logger.log("=== Debug Information End ===\n")
     }
     
     // MARK: - CT2 Functionality: Get Window Info for All Apps
     private func getAllAppsWithWindows() {
         apps.removeAll()
         // 不再全量清空AX缓存，让智能清理机制处理
         
         Logger.log("\n=== CT2 Debug Information Start ===")
         
         // 获取所有运行的应用
         let allApps = NSWorkspace.shared.runningApplications
         Logger.log("Total running applications: \(allApps.count)")
         
         // 获取所有窗口，按照前后顺序排列（最前面的窗口排在前面）
         // 这个顺序就是Command+Tab的真实顺序
         let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
         Logger.log("System found \(windowList.count) windows in total")
         
         // 按应用组织窗口
         var appWindows: [pid_t: [WindowInfo]] = [:]
         var appInfoMap: [pid_t: (bundleId: String, appName: String)] = [:]
         var appFirstWindowOrder: [pid_t: Int] = [:] // 记录每个应用的第一个窗口在列表中的位置
         
         // 首先建立processID到应用信息的映射
         for app in allApps {
             // 跳过没有用户界面的应用和当前应用
             guard app.activationPolicy == .regular,
                   app.bundleIdentifier != Bundle.main.bundleIdentifier else {
                 continue
             }
             
             appInfoMap[app.processIdentifier] = (
                 bundleId: app.bundleIdentifier ?? "unknown",
                 appName: app.localizedName ?? "Unknown App"
             )
         }
         
         Logger.log("Valid application count: \(appInfoMap.count)")
         
         // 处理所有窗口，按应用分组，同时记录应用首次出现的顺序
         var windowCounter = 1
         for (windowIndex, windowInfo) in windowList.enumerated() {
             guard let processID = windowInfo[kCGWindowOwnerPID as String] as? pid_t,
                   let appInfo = appInfoMap[processID] else {
                 continue
             }
             
             let windowTitle = windowInfo[kCGWindowName as String] as? String ?? ""
             let layer = windowInfo[kCGWindowLayer as String] as? Int ?? -1
             let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID ?? 0
             let isOnScreen = windowInfo[kCGWindowIsOnscreen as String] as? Bool ?? false
             
             // 检查过滤条件
             let hasValidID = windowInfo[kCGWindowNumber as String] is CGWindowID
             let hasValidLayer = layer >= 0
             let bounds = windowInfo[kCGWindowBounds as String] as? [String: Any]
             let width = (bounds?["Width"] as? NSNumber)?.intValue ?? 0
             let height = (bounds?["Height"] as? NSNumber)?.intValue ?? 0
             let hasReasonableSize = width > 100 && height > 100
             
             if hasValidID && hasValidLayer && hasReasonableSize && isOnScreen {
                 // 记录该应用第一个窗口在列表中的位置（用于排序）
                 if appFirstWindowOrder[processID] == nil {
                     appFirstWindowOrder[processID] = windowIndex
                 }
                 
                 // 获取当前应用的窗口数量，用于确定AX窗口索引
                 let currentAppWindowCount = appWindows[processID]?.count ?? 0
                 
                 // 通过AX API获取窗口标题
                 let (axTitle, _) = getAXWindowInfo(windowID: windowID, processID: processID, windowIndex: currentAppWindowCount)
                 
                 let displayTitle: String
                 let projectName: String
                 
                 if !axTitle.isEmpty {
                     displayTitle = axTitle
                     projectName = settingsManager.extractProjectName(
                         from: axTitle,
                         bundleId: appInfo.bundleId,
                         appName: appInfo.appName
                     )
                 } else if !windowTitle.isEmpty {
                     displayTitle = windowTitle
                     projectName = settingsManager.extractProjectName(
                         from: windowTitle,
                         bundleId: appInfo.bundleId,
                         appName: appInfo.appName
                     )
                 } else {
                     displayTitle = "\(appInfo.appName) 窗口 \(windowCounter)"
                     projectName = displayTitle
                     windowCounter += 1
                 }
                 
                 // AX元素会在getCachedAXElement中自动缓存
                 
                 let window = WindowInfo(
                     windowID: windowID,
                     title: displayTitle,
                     projectName: projectName,
                     appName: appInfo.appName,
                     processID: processID,
                     axWindowIndex: currentAppWindowCount
                 )
                 
                 // 添加到该应用的窗口列表
                 if appWindows[processID] == nil {
                     appWindows[processID] = []
                 }
                 appWindows[processID]?.append(window)
             }
         }
         
         // 创建AppInfo对象，同时收集应用激活状态信息
         for (processID, windows) in appWindows {
             guard let appInfo = appInfoMap[processID], !windows.isEmpty else {
                 continue
             }
             
             // 查找对应的NSRunningApplication以获取激活状态
             let runningApp = allApps.first { $0.processIdentifier == processID }
             let isActive = runningApp?.isActive ?? false
             
             let app = AppInfo(
                 bundleId: appInfo.bundleId,
                 processID: processID,
                 appName: appInfo.appName,
                 windows: windows,
                 isActive: isActive,
                 lastUsedTime: nil  // macOS不直接提供最近使用时间，我们用激活状态来排序
             )
             
             apps.append(app)
         }
         
         // 按照窗口在CGWindowListCopyWindowInfo中的出现顺序排序
         // 这样可以真正模拟Command+Tab的行为
         apps.sort { app1, app2 in
             let order1 = appFirstWindowOrder[app1.processID] ?? Int.max
             let order2 = appFirstWindowOrder[app2.processID] ?? Int.max
             
             // 窗口出现越早的应用排在前面
             if order1 != order2 {
                 return order1 < order2
             }
             
             // 如果顺序相同（理论上不应该发生），按应用名称排序
             return app1.appName.localizedCaseInsensitiveCompare(app2.appName) == .orderedAscending
         }
         
         Logger.log("📊 CT2 Statistics result:")
         Logger.log("   Valid application count: \(apps.count)")
         for (index, app) in apps.enumerated() {
             let activeStatus = app.isActive ? " [ACTIVE]" : ""
             Logger.log("   \(index + 1). \(app.appName): \(app.windowCount) windows\(activeStatus)")
         }
         Logger.log("=== CT2 Debug Information End ===\n")
     }
     
     // 通过 AX API 获取特定窗口ID对应的标题和AXUIElement
     private func getAXWindowInfo(windowID: CGWindowID, processID: pid_t, windowIndex: Int) -> (title: String, axElement: AXUIElement?) {
         let app = AXUIElementCreateApplication(processID)
         
         var windowsRef: CFTypeRef?
         guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef) == .success,
               let axWindows = windowsRef as? [AXUIElement] else {
             Logger.log("   ❌ Cannot get AX window list")
             return ("", nil)
         }
         
         Logger.log("   🔍 Total AX windows: \(axWindows.count), target index: \(windowIndex)")
         
         // 直接通过索引获取对应的AX窗口
         guard windowIndex < axWindows.count else {
             Logger.log("   ❌ Window index \(windowIndex) out of range (total: \(axWindows.count))")
             return ("", nil)
         }
         
         let axWindow = axWindows[windowIndex]
         
         // 获取窗口标题
         var titleRef: CFTypeRef?
         if AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleRef) == .success,
            let title = titleRef as? String {
             Logger.log("   ✅ Window ID \(windowID) matched successfully through index[\(windowIndex)], title: '\(title)'")
             return (title, axWindow)
         } else {
             Logger.log("   ⚠️ Window ID \(windowID) matched successfully through index[\(windowIndex)], but no title")
             return ("", axWindow)
         }
     }
    
    
    private func activateWindow(_ window: WindowInfo) {
        Logger.log("\n🎯 Attempting to activate window ID: \(window.windowID), title: '\(window.title)'")
        
        // 优先使用AX增强方法
        if activateWindowWithAXEnhanced(window) {
            Logger.log("   ✅ AX enhanced activation successful")
            return
        }
        
        Logger.log("   ⚠️ AX enhanced method failed, trying fallback solution")
        
        // 降级方案1: 传统AX方法（保持向后兼容）
        let windowBounds = getWindowBounds(windowID: window.windowID)
        
        // 首先尝试从缓存中获取AXUIElement
        if let cachedElement = getCachedAXElement(windowID: window.windowID, processID: window.processID, windowIndex: window.axWindowIndex) {
            Logger.log("   ✅ Got AX element (cached or new)")
            
            // 执行多显示器焦点转移和窗口激活
            if activateWindowWithFocusTransfer(axElement: cachedElement, windowBounds: windowBounds, window: window) {
                Logger.log("   ✅ Window activation successful")
                return
            } else {
                Logger.log("   ⚠️ AX element activation failed")
            }
        }
        
        Logger.log("   ❌ Cannot get AX element for window ID \(window.windowID)")
        
        // 降级方案：尝试使用Core Graphics API
        Logger.log("   🔄 Trying final fallback solution")
        fallbackActivateWindowWithFocusTransfer(window.windowID, processID: window.processID, windowBounds: windowBounds)
    }
    
    // MARK: - AX Enhanced Multi-Display Focus Transfer Support
    
    // 显示器信息结构
    struct DisplayInfo {
        let screen: NSScreen
        let windowRect: CGRect
        let displayID: CGDirectDisplayID
    }
    
    // AX增强的窗口激活方法（主入口）
    private func activateWindowWithAXEnhanced(_ window: WindowInfo) -> Bool {
        guard let axElement = getCachedAXElement(windowID: window.windowID, processID: window.processID, windowIndex: window.axWindowIndex) else {
            Logger.log("   ❌ AX enhanced activation failed: cannot get AX element")
            return false
        }
        
        Logger.log("   🔄 Using AX enhanced method to activate window")
        
        // 获取窗口显示器信息
        guard let displayInfo = getWindowDisplayInfo(axElement: axElement) else {
            Logger.log("   ❌ AX enhanced activation failed: cannot get display information")
            return false
        }
        
        // 检查是否需要跨显示器激活
        let currentScreen = getCurrentFocusedScreen()
        let needsCrossDisplayActivation = (displayInfo.screen != currentScreen)
        
        Logger.log("   📍 Window position: \(displayInfo.windowRect)")
        Logger.log("   🖥️ Target display: \(displayInfo.screen.localizedName)")
        Logger.log("   🔄 Cross-display activation needed: \(needsCrossDisplayActivation)")
        
        if needsCrossDisplayActivation {
            return performCrossDisplayAXActivation(axElement: axElement, displayInfo: displayInfo, window: window)
        } else {
            return performSameDisplayAXActivation(axElement: axElement, window: window)
        }
    }
    
    // 获取窗口的显示器信息
    private func getWindowDisplayInfo(axElement: AXUIElement) -> DisplayInfo? {
        // 获取窗口位置
        var positionRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axElement, kAXPositionAttribute as CFString, &positionRef) == .success,
              let positionValue = positionRef else {
            Logger.log("   ⚠️ Cannot get window position")
            return nil
        }
        
        // 获取窗口大小
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axElement, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let sizeValue = sizeRef else {
            Logger.log("   ⚠️ Cannot get window size")
            return nil
        }
        
        // 转换为CGPoint和CGSize
        var point = CGPoint.zero
        var cgSize = CGSize.zero
        
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &point) == true,
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &cgSize) == true else {
            Logger.log("   ⚠️ AX value conversion failed")
            return nil
        }
        
        // 计算窗口矩形
        let windowRect = CGRect(origin: point, size: cgSize)
        
        // 找到包含此窗口的显示器
        guard let targetScreen = findScreenContaining(rect: windowRect) else {
            Logger.log("   ⚠️ Cannot find display containing window")
            return nil
        }
        
        // 获取显示器ID
        let displayID = getDisplayID(for: targetScreen)
        
        return DisplayInfo(screen: targetScreen, windowRect: windowRect, displayID: displayID)
    }
    
    // 找到包含指定矩形的显示器
    private func findScreenContaining(rect: CGRect) -> NSScreen? {
        let windowCenter = CGPoint(x: rect.midX, y: rect.midY)
        
        // 在所有显示器中查找
        for screen in NSScreen.screens {
            if screen.frame.contains(windowCenter) {
                return screen
            }
        }
        
        // 如果没有找到，返回主显示器
        return NSScreen.main
    }
    
    // 获取显示器的CGDirectDisplayID
    private func getDisplayID(for screen: NSScreen) -> CGDirectDisplayID {
        guard let screenNumber = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else {
            return CGMainDisplayID()
        }
        return CGDirectDisplayID(screenNumber.uint32Value)
    }
    
    // 获取当前焦点所在的显示器
    private func getCurrentFocusedScreen() -> NSScreen? {
        // 方法1: 通过鼠标位置确定
        let mouseLocation = NSEvent.mouseLocation
        for screen in NSScreen.screens {
            if screen.frame.contains(mouseLocation) {
                return screen
            }
        }
        
        // 方法2: 返回主显示器作为默认
        return NSScreen.main
    }
    
    // 跨显示器激活窗口（AX增强方法）
    private func performCrossDisplayAXActivation(axElement: AXUIElement, displayInfo: DisplayInfo, window: WindowInfo) -> Bool {
        Logger.log("   🚀 Executing cross-display AX activation")
        
        // 步骤1: 智能焦点转移到目标显示器
        if !transferFocusToDisplay(displayInfo: displayInfo) {
            Logger.log("   ⚠️ Focus transfer failed, but continuing to try activation")
        }
        
        // 步骤2: 激活应用进程
        guard let app = NSRunningApplication(processIdentifier: window.processID) else {
            Logger.log("   ❌ Cannot get application process")
            return false
        }
        
        let appActivated = app.activate()
        Logger.log("   🎯 Application activation result: \(appActivated ? "successful" : "failed")")
        
        // 步骤3: 使用AX API提升窗口
        let raiseResult = AXUIElementPerformAction(axElement, kAXRaiseAction as CFString)
        Logger.log("   ⬆️ AX window raise result: \(raiseResult == .success ? "successful" : "failed")")
        
        // 步骤4: 设置窗口为焦点窗口
        AXUIElementSetAttributeValue(axElement, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(axElement, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        
        // 步骤5: 验证激活结果
        let success = verifyWindowActivation(axElement: axElement, displayInfo: displayInfo)
        Logger.log("   ✅ Cross-display activation \(success ? "successful" : "failed")")
        
        return success
    }
    
    // 同显示器激活窗口（AX增强方法）
    private func performSameDisplayAXActivation(axElement: AXUIElement, window: WindowInfo) -> Bool {
        Logger.log("   🎯 Executing same-display AX activation")
        
        // 步骤1: 激活应用进程
        guard let app = NSRunningApplication(processIdentifier: window.processID) else {
            Logger.log("   ❌ Cannot get application process")
            return false
        }
        
        let appActivated = app.activate()
        Logger.log("   🎯 Application activation result: \(appActivated ? "successful" : "failed")")
        
        // 步骤2: 使用AX API提升窗口
        let raiseResult = AXUIElementPerformAction(axElement, kAXRaiseAction as CFString)
        Logger.log("   ⬆️ AX window raise result: \(raiseResult == .success ? "successful" : "failed")")
        
        // 步骤3: 设置窗口为焦点窗口
        AXUIElementSetAttributeValue(axElement, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(axElement, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        
        return raiseResult == .success
    }
    
    // 智能焦点转移到目标显示器
    private func transferFocusToDisplay(displayInfo: DisplayInfo) -> Bool {
        Logger.log("   🔄 Transferring focus to display: \(displayInfo.screen.localizedName)")
        
        // 方法1: 精确鼠标定位
        let targetPoint = CGPoint(
            x: displayInfo.windowRect.midX,
            y: displayInfo.windowRect.midY
        )
        
        // 创建鼠标移动事件
        guard let moveEvent = CGEvent(
            mouseEventSource: nil,
            mouseType: .mouseMoved,
            mouseCursorPosition: targetPoint,
            mouseButton: .left
        ) else {
            Logger.log("   ❌ Cannot create mouse movement event")
            return false
        }
        
        // 发送事件
        moveEvent.post(tap: .cghidEventTap)
        
        // 短暂延迟确保焦点转移完成
        usleep(30000) // 30ms
        
        Logger.log("   🖱️ Mouse moved to target window position: (\(targetPoint.x), \(targetPoint.y))")
        return true
    }
    
    // 验证窗口激活结果
    private func verifyWindowActivation(axElement: AXUIElement, displayInfo: DisplayInfo) -> Bool {
        // 验证1: 检查窗口是否为主窗口
        var isMainRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(axElement, kAXMainAttribute as CFString, &isMainRef) == .success,
           let isMain = isMainRef as? Bool, isMain {
            Logger.log("   ✅ Window has become main window")
            return true
        }
        
        // 验证2: 检查窗口是否有焦点
        var isFocusedRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(axElement, kAXFocusedAttribute as CFString, &isFocusedRef) == .success,
           let isFocused = isFocusedRef as? Bool, isFocused {
            Logger.log("   ✅ Window has gained focus")
            return true
        }
        
        Logger.log("   ⚠️ Window activation verification failed, but may still be successful")
        return false
    }
    
    // 获取窗口边界信息
    private func getWindowBounds(windowID: CGWindowID) -> CGRect? {
        let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, windowID) as? [[String: Any]] ?? []
        
        for windowInfo in windowList {
            if let id = windowInfo[kCGWindowNumber as String] as? CGWindowID, id == windowID {
                if let bounds = windowInfo[kCGWindowBounds as String] as? [String: Any],
                   let x = bounds["X"] as? NSNumber,
                   let y = bounds["Y"] as? NSNumber,
                   let width = bounds["Width"] as? NSNumber,
                   let height = bounds["Height"] as? NSNumber {
                    return CGRect(x: x.doubleValue, y: y.doubleValue, width: width.doubleValue, height: height.doubleValue)
                }
            }
        }
        
        return nil
    }
    
    // 支持多显示器焦点转移的窗口激活方法
    private func activateWindowWithFocusTransfer(axElement: AXUIElement, windowBounds: CGRect?, window: WindowInfo) -> Bool {
        // 首先将鼠标移动到目标窗口所在的显示器（如果需要）
        if let bounds = windowBounds {
            moveCursorToWindowDisplay(windowBounds: bounds)
        }
        
        // 延迟一小段时间确保鼠标移动完成
        usleep(50000) // 50ms
        
        // 激活窗口
        let raiseResult = AXUIElementPerformAction(axElement, kAXRaiseAction as CFString)
        Logger.log("   AXRaiseAction result: \(raiseResult == .success ? "successful" : "failed")")
        
        // 将应用置于前台
        if let app = NSRunningApplication(processIdentifier: window.processID) {
            let activateResult = app.activate()
            Logger.log("   Application activation result: \(activateResult ? "successful" : "failed")")
        }
        
        // 确保窗口获得焦点（通过AX API）
        if raiseResult == .success {
            // 尝试设置窗口为主窗口
            AXUIElementSetAttributeValue(axElement, kAXMainAttribute as CFString, kCFBooleanTrue)
            
            // 尝试设置窗口为焦点窗口
            AXUIElementSetAttributeValue(axElement, kAXFocusedAttribute as CFString, kCFBooleanTrue)
            
            return true
        }
        
        return false
    }
    
    // 将鼠标光标移动到指定窗口所在的显示器
    private func moveCursorToWindowDisplay(windowBounds: CGRect) {
        let currentCursorLocation = NSEvent.mouseLocation
        let windowCenter = CGPoint(x: windowBounds.midX, y: windowBounds.midY)
        
        // 转换坐标系（NSEvent使用左下角原点，CGWindow使用左上角原点）
        let screens = NSScreen.screens
        var totalHeight: CGFloat = 0
        for screen in screens {
            totalHeight = max(totalHeight, screen.frame.maxY)
        }
        let flippedWindowCenter = CGPoint(x: windowCenter.x, y: totalHeight - windowCenter.y)
        
        // 检查鼠标是否已经在目标显示器上
        var targetScreen: NSScreen?
        for screen in screens {
            if screen.frame.contains(flippedWindowCenter) {
                targetScreen = screen
                break
            }
        }
        
        // 检查当前鼠标是否在同一个显示器上
        var currentScreen: NSScreen?
        for screen in screens {
            if screen.frame.contains(currentCursorLocation) {
                currentScreen = screen
                break
            }
        }
        
        // 如果鼠标不在目标显示器上，移动到目标窗口的中心
        if let target = targetScreen, target != currentScreen {
            Logger.log("   🖱️ Moving mouse from display \(currentScreen?.localizedName ?? "unknown") to \(target.localizedName)")
            
            // 使用Core Graphics移动鼠标
            let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: windowCenter, mouseButton: .left)
            moveEvent?.post(tap: .cghidEventTap)
            
            Logger.log("   🖱️ Mouse moved to window center: (\(windowCenter.x), \(windowCenter.y))")
        } else {
            Logger.log("   🖱️ Mouse is already on target display, no need to move")
        }
    }
    
    // 降级方案：使用Core Graphics API激活窗口（支持多显示器焦点转移）
    private func fallbackActivateWindowWithFocusTransfer(_ windowID: CGWindowID, processID: pid_t, windowBounds: CGRect?) {
        // 首先将鼠标移动到目标窗口所在的显示器（如果需要）
        if let bounds = windowBounds {
            moveCursorToWindowDisplay(windowBounds: bounds)
        }
        
        // 延迟一小段时间确保鼠标移动完成
        usleep(50000) // 50ms
        
        // 将应用置于前台
        if let app = NSRunningApplication(processIdentifier: processID) {
            let activateResult = app.activate()
            Logger.log("   Fallback solution - Application activation result: \(activateResult ? "successful" : "failed")")
        }
        
        // 注意：Core Graphics没有直接激活特定窗口的API
        // 这里只能激活应用，让它自己决定显示哪个窗口
        Logger.log("   ⚠️ Using fallback solution, can only activate application, cannot precisely control window")
        Logger.log("   🖱️ Mouse moved to target window's display to improve focus transfer")
    }
    
    // 降级方案：使用Core Graphics API激活窗口（保持向后兼容）
    private func fallbackActivateWindow(_ windowID: CGWindowID, processID: pid_t) {
        // 将应用置于前台
        if let app = NSRunningApplication(processIdentifier: processID) {
            let activateResult = app.activate()
            Logger.log("   Fallback solution - Application activation result: \(activateResult ? "successful" : "failed")")
        }
        
        // 注意：Core Graphics没有直接激活特定窗口的API
        // 这里只能激活应用，让它自己决定显示哪个窗口
        Logger.log("   ⚠️ Using fallback solution, can only activate application, cannot precisely control window")
    }
    
    // MARK: - Enhanced Event Handling Mechanism (Solution 3)
    
    /// 设置统一的事件处理机制，减少事件冲突
    private func setupUnifiedEventHandling() {
        // 清理现有监听器
        cleanupEventMonitors()
        
        // 设置本地事件监听器 - 处理所有类型的事件
        eventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.keyDown, .keyUp, .flagsChanged]
        ) { [weak self] event in
            return self?.handleUnifiedKeyEvent(event, isGlobal: false)
        }
        
        // 设置全局事件监听器 - 主要用于监听修饰键变化
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.flagsChanged, .keyDown, .keyUp]
        ) { [weak self] event in
            self?.handleUnifiedKeyEvent(event, isGlobal: true)
        }
        
        Logger.log("🔧 Unified event handling mechanism has been set up")
    }
    
    /// 统一的事件处理入口，减少竞态条件
    private func handleUnifiedKeyEvent(_ event: NSEvent, isGlobal: Bool) -> NSEvent? {
        // 防止重复处理同一事件
        guard !isProcessingKeyEvent else {
            return isGlobal ? nil : event
        }
        
        isProcessingKeyEvent = true
        defer { isProcessingKeyEvent = false }
        
        let eventSource = isGlobal ? "全局" : "本地"
        
        // 根据当前切换器类型分发事件
        if isShowingSwitcher {
            return handleDS2UnifiedEvent(event, source: eventSource)
        } else if isShowingAppSwitcher {
            return handleCT2UnifiedEvent(event, source: eventSource)
        }
        
        return isGlobal ? nil : event
    }
    
    /// DS2切换器的统一事件处理
    private func handleDS2UnifiedEvent(_ event: NSEvent, source: String) -> NSEvent? {
        let settings = settingsManager.settings
        
        switch event.type {
        case .keyUp:
            // ESC键关闭切换器
            if event.keyCode == 53 { // ESC key
                Logger.log("🔴 [\(source)] ESC key detected, closing DS2 switcher")
                hideSwitcherAsync()
                return nil
            }
            
        case .keyDown:
            // 处理触发键
            if event.keyCode == UInt16(settings.triggerKey.keyCode) {
                if event.modifierFlags.contains(settings.modifierKey.eventModifier) {
                    let isShiftPressed = event.modifierFlags.contains(.shift)
                    
                    if isShiftPressed {
                        Logger.log("🟢 [\(source)] DS2 reverse switch: \(currentWindowIndex) -> ", terminator: "")
                        moveToPreviousWindow()
                        Logger.log("\(currentWindowIndex)")
                    } else {
                        Logger.log("🟢 [\(source)] DS2 forward switch: \(currentWindowIndex) -> ", terminator: "")
                        moveToNextWindow()
                        Logger.log("\(currentWindowIndex)")
                    }
                    return nil // 阻止事件传递
                }
            }
            
        case .flagsChanged:
            // 检测修饰键松开 - 添加防抖处理
            let now = Date()
            let timeSinceLastModifier = now.timeIntervalSince(lastModifierEventTime)
            
            // 防抖：如果距离上次修饰键事件时间太短，忽略
            if timeSinceLastModifier < 0.05 { // 50ms防抖
                return source == "全局" ? nil : event
            }
            
            lastModifierEventTime = now
            
            if !event.modifierFlags.contains(settings.modifierKey.eventModifier) {
                Logger.log("🔴 [\(source)] \(settings.modifierKey.displayName) key release detected, closing DS2 switcher")
                hideSwitcherAsync()
                return nil
            }
            
        default:
            break
        }
        
        return source == "全局" ? nil : event
    }
    
    /// CT2切换器的统一事件处理
    private func handleCT2UnifiedEvent(_ event: NSEvent, source: String) -> NSEvent? {
        let settings = settingsManager.settings
        
        switch event.type {
        case .keyUp:
            // ESC键关闭切换器
            if event.keyCode == 53 { // ESC key
                Logger.log("🔴 [\(source)] ESC key detected, closing CT2 switcher")
                hideAppSwitcherAsync()
                return nil
            }
            
        case .keyDown:
            // 处理触发键
            if event.keyCode == UInt16(settings.ct2TriggerKey.keyCode) {
                if event.modifierFlags.contains(settings.ct2ModifierKey.eventModifier) {
                    let isShiftPressed = event.modifierFlags.contains(.shift)
                    
                    if isShiftPressed {
                        Logger.log("🟢 [\(source)] CT2 reverse switch: \(currentAppIndex) -> ", terminator: "")
                        moveToPreviousApp()
                        print("\(currentAppIndex)")
                    } else {
                        Logger.log("🟢 [\(source)] CT2 forward switch: \(currentAppIndex) -> ", terminator: "")
                        moveToNextApp()
                        print("\(currentAppIndex)")
                    }
                    return nil // 阻止事件传递
                }
            }
            
        case .flagsChanged:
            // 检测修饰键松开 - 添加防抖处理
            let now = Date()
            let timeSinceLastModifier = now.timeIntervalSince(lastModifierEventTime)
            
            // 防抖：如果距离上次修饰键事件时间太短，忽略
            if timeSinceLastModifier < 0.05 { // 50ms防抖
                return source == "全局" ? nil : event
            }
            
            lastModifierEventTime = now
            
            if !event.modifierFlags.contains(settings.ct2ModifierKey.eventModifier) {
                Logger.log("🔴 [\(source)] \(settings.ct2ModifierKey.displayName) key release detected, closing CT2 switcher")
                hideAppSwitcherAsync()
                return nil
            }
            
        default:
            break
        }
        
        return source == "全局" ? nil : event
    }
    
    /// 清理事件监听器的统一方法
    private func cleanupEventMonitors() {
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if let globalMonitor = globalEventMonitor {
            NSEvent.removeMonitor(globalMonitor)
            globalEventMonitor = nil
        }
    }
    
    // MARK: - Async Window Activation Optimization (Solution 2)
    
    /// 异步版本的DS2切换器隐藏方法，提供更流畅的体验
    private func hideSwitcherAsync() {
        guard isShowingSwitcher else { return }
        
        Logger.log("🚀 Async DS2 switcher hiding started")
        
        // 立即隐藏UI，给用户即时反馈
        isShowingSwitcher = false
        switcherWindow?.orderOut(nil)
        
        // 关键: 销毁视图以释放内存
        switcherWindow?.contentView = NSView()
        
        // 停止修饰键看门狗
        stopModifierKeyWatchdog()
        
        // 立即清理事件监听器
        cleanupEventMonitors()
        
        // 立即重新启用全局热键
        hotkeyManager?.reEnableHotkey()
        
        // 清除应用图标缓存（在后台线程执行）
        DispatchQueue.global(qos: .utility).async {
            AppIconCache.shared.clearCache()
        }
        
        // 异步激活窗口，避免阻塞UI
        if currentWindowIndex < windows.count {
            let targetWindow = windows[currentWindowIndex]
            Logger.log("🎯 Preparing async window activation: \(targetWindow.title)")
            
            // 使用用户初始优先级确保响应性
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.activateWindowAsync(targetWindow)
            }
        }
        
        Logger.log("🚀 DS2 switcher UI hidden, window activation in progress asynchronously")
    }
    
    /// 异步版本的CT2切换器隐藏方法，提供更流畅的体验
    private func hideAppSwitcherAsync() {
        guard isShowingAppSwitcher else { return }
        
        Logger.log("🚀 Async CT2 switcher hiding started")
        
        // 立即隐藏UI，给用户即时反馈
        isShowingAppSwitcher = false
        switcherWindow?.orderOut(nil)
        
        // 关键: 销毁视图以释放内存
        switcherWindow?.contentView = NSView()
        
        // 停止修饰键看门狗
        stopModifierKeyWatchdog()
        
        // 立即清理事件监听器
        cleanupEventMonitors()
        
        // 立即重新启用全局热键
        hotkeyManager?.reEnableHotkey()
        
        // 重置CT2切换器状态同步
        hotkeyManager?.resetCT2SwitcherState()
        
        // 清除应用图标缓存（在后台线程执行）
        DispatchQueue.global(qos: .utility).async {
            AppIconCache.shared.clearCache()
        }
        
        // 异步激活应用，避免阻塞UI
        if currentAppIndex < apps.count, let firstWindow = apps[currentAppIndex].firstWindow {
            Logger.log("🎯 Preparing async application activation: \(apps[currentAppIndex].appName)")
            
            // 使用用户初始优先级确保响应性
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.activateWindowAsync(firstWindow)
            }
        }
        
        Logger.log("🚀 CT2 switcher UI hidden, application activation in progress asynchronously")
    }
    
    /// 异步窗口激活方法，优化性能和流畅度
    private func activateWindowAsync(_ window: WindowInfo) {
        Logger.log("🚀 Async window activation started: \(window.title)")
        
        // 首先尝试快速激活应用
        guard let app = NSRunningApplication(processIdentifier: window.processID) else {
            Logger.log("❌ Cannot find application corresponding to process ID \(window.processID)")
            return
        }
        
        // 在主线程激活应用（系统要求）
        DispatchQueue.main.async {
            let activated = app.activate()
            Logger.log("   📱 Application activation result: \(activated ? "successful" : "failed")")
        }
        
        // 短暂延迟后激活具体窗口
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.activateSpecificWindowFast(window)
        }
    }
    
    /// 快速窗口激活方法，简化复杂的多显示器处理
    private func activateSpecificWindowFast(_ window: WindowInfo) {
        Logger.log("⚡ Fast activation of specific window: \(window.title)")
        
        // 尝试从缓存获取AX元素
        if let axElement = getCachedAXElement(
            windowID: window.windowID,
            processID: window.processID, 
            windowIndex: window.axWindowIndex
        ) {
            // 使用AX API激活窗口
            let raiseResult = AXUIElementPerformAction(axElement, kAXRaiseAction as CFString)
            Logger.log("   ⚡ AX activation result: \(raiseResult == .success ? "successful" : "failed")")
            
            if raiseResult == .success {
                // 尝试设置为主窗口和焦点窗口
                AXUIElementSetAttributeValue(axElement, kAXMainAttribute as CFString, kCFBooleanTrue)
                AXUIElementSetAttributeValue(axElement, kAXFocusedAttribute as CFString, kCFBooleanTrue)
                Logger.log("   ✅ Window activation completed")
                return
            }
        }
        
        // 如果AX方法失败，使用降级方案
        Logger.log("   ⚠️ AX method failed, using fallback solution")
        fallbackActivateAsync(window)
    }
    
    /// 异步降级激活方案
    private func fallbackActivateAsync(_ window: WindowInfo) {
        // 简化的降级方案，只激活应用
        if let app = NSRunningApplication(processIdentifier: window.processID) {
            app.activate()
            Logger.log("   📱 Fallback solution: application activated")
        }
        
        // 可选：尝试通过窗口ID进行基本操作（如果需要）
        // 这里可以添加其他轻量级的窗口操作
    }
    
    // MARK: - Modifier Key Watchdog Mechanism
    
    /// 启动修饰键看门狗，提供双重保险机制
    /// - Parameter switcherType: 切换器类型（DS2或CT2）
    private func startModifierKeyWatchdog(for switcherType: SwitcherType) {
        // 先停止任何现有的看门狗
        stopModifierKeyWatchdog()
        
        // 重置看门狗状态
        watchdogCallCount = 0
        watchdogPhase = 0
        lastSwitchTime = Date()
        
        // 检查是否需要启用看门狗（在快速切换场景下更有价值）
        let timeSinceLastSwitch = Date().timeIntervalSince(lastSwitchTime)
        let shouldUseWatchdog = timeSinceLastSwitch < 2.0 // 2秒内的操作启用看门狗
        
        if !shouldUseWatchdog {
            Logger.log("🐕 Watchdog: not a fast switching scenario, skipping startup")
            return
        }
        
        Logger.log("🐕 Starting modifier key watchdog, type: \(switcherType == .ds2 ? "DS2" : "CT2"), interval: \(Int(watchdogInterval * 1000))ms")
        
        modifierKeyWatchdog = Timer.scheduledTimer(withTimeInterval: watchdogInterval, repeats: true) { [weak self] _ in
            self?.checkModifierKeyState(for: switcherType)
        }
    }
    
    /// 停止修饰键看门狗
    private func stopModifierKeyWatchdog() {
        guard let watchdog = modifierKeyWatchdog else { return }
        
        Logger.log("🐕 Stopping modifier key watchdog, runtime: \(String(format: "%.1f", Double(watchdogCallCount) * watchdogInterval))s, detection count: \(watchdogCallCount)")
        
        watchdog.invalidate()
        modifierKeyWatchdog = nil
        watchdogCallCount = 0
        watchdogPhase = 0
    }
    
    /// 检测修饰键状态的核心方法
    /// - Parameter switcherType: 切换器类型
    private func checkModifierKeyState(for switcherType: SwitcherType) {
        watchdogCallCount += 1
        watchdogPhase += 1
        
        // 性能保护：超时自动停止（16秒或1000次检测）
        if watchdogCallCount > 1000 {
            Logger.log("🐕⚠️ Watchdog timeout auto-stop (1000 detections)")
            stopModifierKeyWatchdog()
            return
        }
        
        // 获取当前修饰键状态
        let currentModifiers = NSEvent.modifierFlags
        let settings = settingsManager.settings
        
        let requiredModifier: NSEvent.ModifierFlags
        let modifierName: String
        let isActive: Bool
        
        // 根据切换器类型检查对应的修饰键
        switch switcherType {
        case .ds2:
            requiredModifier = settings.modifierKey.eventModifier
            modifierName = settings.modifierKey.displayName
            isActive = isShowingSwitcher
        case .ct2:
            requiredModifier = settings.ct2ModifierKey.eventModifier
            modifierName = settings.ct2ModifierKey.displayName
            isActive = isShowingAppSwitcher
        }
        
        // 如果切换器已经不活跃，停止看门狗
        if !isActive {
            Logger.log("🐕 Watchdog detected switcher closed, auto-stopping")
            stopModifierKeyWatchdog()
            return
        }
        
        // 检查修饰键是否仍在按下状态
        if !currentModifiers.contains(requiredModifier) {
            Logger.log("🐕🚨 [Watchdog Detection] \(modifierName) key released, immediately closing \(switcherType == .ds2 ? "DS2" : "CT2") switcher")
            stopModifierKeyWatchdog()
            
            // 在主线程执行关闭操作
            DispatchQueue.main.async { [weak self] in
                switch switcherType {
                case .ds2:
                    self?.hideSwitcherAsync()
                case .ct2:
                    self?.hideAppSwitcherAsync()
                }
            }
            return
        }
        
        // 可选：动态调整检测频率（前10次检测使用高频率）
        if watchdogPhase == 10 {
            Logger.log("🐕 Watchdog entering low frequency mode")
            stopModifierKeyWatchdog()
            
            // 重新启动低频看门狗
            modifierKeyWatchdog = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { [weak self] _ in
                self?.checkModifierKeyState(for: switcherType)
            }
        }
        
        // 每100次检测输出一次状态（约1.6秒）
        if watchdogCallCount % 100 == 0 {
            Logger.log("🐕 Watchdog running normally, detected \(watchdogCallCount) times, \(modifierName) key status: pressed")
        }
    }
} 
