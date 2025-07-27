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
    let axWindowIndex: Int  // AX窗口的索引
}

class WindowManager: ObservableObject {
    @Published var windows: [WindowInfo] = []
    @Published var isShowingSwitcher = false
    @Published var currentWindowIndex = 0
    
    // CT2相关属性
    @Published var apps: [AppInfo] = []
    @Published var isShowingAppSwitcher = false
    @Published var currentAppIndex = 0
    
    private var switcherWindow: NSWindow?
    private var eventMonitor: Any?
    private var globalEventMonitor: Any?
    
    // 当前视图类型跟踪
    private var currentViewType: SwitcherType = .ds2
    
    // 事件处理状态管理
    private var isProcessingKeyEvent = false
    private var lastModifierEventTime = Date()
    
    // 修饰键看门狗机制
    private var modifierKeyWatchdog: Timer?
    private let watchdogInterval: TimeInterval = 0.016 // 16ms ≈ 60Hz
    private var watchdogCallCount = 0
    private var watchdogPhase = 0
    private var lastSwitchTime = Date()
    
    // AX元素缓存项结构
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
    
    // 改进的AX元素缓存，包含更多元数据
    private var axElementCache: [CGWindowID: AXCacheItem] = [:]
    private let maxAXCacheSize = 100  // 最大缓存100个AX元素
    private let axCacheCleanupThreshold = 120  // 达到120个时开始清理
    
    // HotkeyManager的弱引用，避免循环引用
    weak var hotkeyManager: HotkeyManager?
    
    // 设置管理器
    private let settingsManager = SettingsManager.shared
    
    init() {
        setupSwitcherWindow()
    }
    
    deinit {
        // 确保事件监听器被清理
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
        }
        if let globalMonitor = globalEventMonitor {
            NSEvent.removeMonitor(globalMonitor)
        }
        
        // 清理看门狗定时器
        stopModifierKeyWatchdog()
        
        // 清理AX缓存
        print("🗑️ WindowManager清理，释放 \(axElementCache.count) 个AX元素")
        axElementCache.removeAll()
    }
    
    // MARK: - AX缓存管理方法
    
    // 智能清理AX缓存
    private func cleanupAXCache() {
        guard axElementCache.count >= axCacheCleanupThreshold else { return }
        
        print("🧹 开始AX缓存LRU清理，当前大小: \(axElementCache.count)")
        
        // 获取当前运行的应用进程ID集合
        let runningProcesses = Set(NSWorkspace.shared.runningApplications.map { $0.processIdentifier })
        
        // 首先移除已终止进程的缓存项
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
        print("🗑️ 移除已终止进程的AX元素: \(itemsToRemove.count) 个")
        
        // 如果还是超过限制，执行LRU清理
        if axElementCache.count > maxAXCacheSize {
            let sortedEntries = axElementCache.sorted { $0.value.lastAccessTime < $1.value.lastAccessTime }
            let itemsToKeep = Array(sortedEntries.suffix(maxAXCacheSize))
            var newCache: [CGWindowID: AXCacheItem] = [:]
            for (key, value) in itemsToKeep {
                newCache[key] = value
            }
            
            let lruRemovedCount = axElementCache.count - newCache.count
            axElementCache = newCache
            
            print("🧹 LRU清理完成，移除 \(lruRemovedCount) 个AX元素，当前大小: \(axElementCache.count)")
        }
    }
    
    // 获取或缓存AX元素
    private func getCachedAXElement(windowID: CGWindowID, processID: pid_t, windowIndex: Int) -> AXUIElement? {
        // 检查缓存中是否存在并更新访问时间
        if var cachedItem = axElementCache[windowID] {
            cachedItem.updateAccessTime()
            axElementCache[windowID] = cachedItem
            return cachedItem.element
        }
        
        // 缓存中没有，获取新的AX元素
        let (_, axElement) = getAXWindowInfo(windowID: windowID, processID: processID, windowIndex: windowIndex)
        
        if let element = axElement {
            // 在添加到缓存前检查是否需要清理
            cleanupAXCache()
            
            // 添加到缓存
            axElementCache[windowID] = AXCacheItem(element: element, processID: processID)
            print("📦 缓存AX元素: WindowID \(windowID), 当前缓存大小: \(axElementCache.count)")
        }
        
        return axElement
    }
    
    // MARK: - 内存优化的视图创建方法
    
    // 创建DS2视图
    private func createDS2HostingView() -> NSHostingView<DS2SwitcherView> {
        print("🆕 创建DS2 HostingView")
        let contentView = DS2SwitcherView(windowManager: self)
        return NSHostingView(rootView: contentView)
    }
    
    // 创建CT2视图
    private func createCT2HostingView() -> NSHostingView<CT2SwitcherView> {
        print("🆕 创建CT2 HostingView")
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
        
        // 初始内容视图将在首次显示时设置
        switcherWindow?.contentView = NSView() // 临时空视图
        
        // 居中显示
        switcherWindow?.center()
    }
    
    func showWindowSwitcher() {
        guard !isShowingSwitcher else { return }
        
        // 1. 清除旧缓存，确保一个干净的开始
        AppIconCache.shared.clearCache()
        
        // 2. 获取当前应用的窗口 (这会开始填充缓存)
        getCurrentAppWindows()
        
        if windows.isEmpty {
            print(LocalizedStrings.noWindowsFound)
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
        NSApp.activate()
        
        // 3. 延迟打印日志，以获取渲染后的真实缓存大小
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self, self.isShowingSwitcher else { return }
            let cacheInfo = AppIconCache.shared.getCacheInfo()
            let formattedSize = ByteCountFormatter.string(fromByteCount: Int64(cacheInfo.dataSize), countStyle: .memory)
            print("📊 DS2 图标缓存状态 (渲染后): \(cacheInfo.count) / \(cacheInfo.maxSize), 总大小: \(formattedSize)")
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
    
    // MARK: - CT2功能：应用切换器显示和隐藏
    func showAppSwitcher() {
        guard !isShowingAppSwitcher else { return }
        
        // 1. 清除旧缓存，确保一个干净的开始
        AppIconCache.shared.clearCache()
        
        // 2. 获取所有应用的窗口信息 (这会开始填充缓存)
        getAllAppsWithWindows()
        
        if apps.isEmpty {
            print("没有找到有窗口的应用")
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
        NSApp.activate()
        
        // 3. 延迟打印日志，以获取渲染后的真实缓存大小
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self, self.isShowingAppSwitcher else { return }
            let cacheInfo = AppIconCache.shared.getCacheInfo()
            let formattedSize = ByteCountFormatter.string(fromByteCount: Int64(cacheInfo.dataSize), countStyle: .memory)
            print("📊 CT2 图标缓存状态 (渲染后): \(cacheInfo.count) / \(cacheInfo.maxSize), 总大小: \(formattedSize)")
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
        print("🔄 moveToNextWindow: \(oldIndex) -> \(currentWindowIndex) (总数: \(windows.count))")
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
    
    // MARK: - CT2功能：应用切换相关方法
    func moveToNextApp() {
        guard !apps.isEmpty else { return }
        let oldIndex = currentAppIndex
        currentAppIndex = (currentAppIndex + 1) % apps.count
        print("🔄 moveToNextApp: \(oldIndex) -> \(currentAppIndex) (总数: \(apps.count))")
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
    
    // MARK: - EventTap支持方法
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
        print("\n=== 调试信息开始 ===")
        let allApps = NSWorkspace.shared.runningApplications
        // print("所有运行的应用:")
        // for app in allApps {
        //     let isActive = app.isActive ? " [ACTIVE]" : ""
        //     let bundleId = app.bundleIdentifier ?? "Unknown"
        //     print("  - \(app.localizedName ?? "Unknown") (PID: \(app.processIdentifier), Bundle: \(bundleId))\(isActive)")
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
            print("✅ 使用前台应用作为目标应用")
        } else {
            print("⚠️ 无法获取前台应用，尝试使用最前面的窗口对应的应用")
            
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
                        print("🔍 找到最前面窗口的应用: \(app.localizedName ?? "Unknown") (PID: \(processID))")
                        break
                    }
                }
            }
            
            guard let foundApp = topWindowApp else {
                print("❌ 无法获取任何有效的目标应用")
                return
            }
            
            targetApp = foundApp
        }
        
        print("\n🎯 目标应用: \(targetApp.localizedName ?? "Unknown") (PID: \(targetApp.processIdentifier))")
        print("   Bundle ID: \(targetApp.bundleIdentifier ?? "Unknown")")
        print("\n📋 系统总共找到 \(windowList.count) 个窗口")
        
        // // 打印所有窗口信息
        // print("\n🔍 所有窗口详情:")
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
            
        //     print("  [\(index)] PID:\(processID) | Layer:\(layer) | Size:\(width)x\(height) | OnScreen:\(isOnScreen)")
        //     print("       Owner: \(ownerName)")
        //     print("       Title: '\(windowTitle)'\(isTarget)")
        //     print("       ID: \(windowID)")
        //     print("")
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
                
                print("🔎 检查目标应用窗口:")
                print("   标题: '\(windowTitle)'")
                print("   Layer: \(layer)")
                print("   ID: \(windowID)")
                print("   OnScreen: \(isOnScreen)")
                
                                 // 检查过滤条件 - 允许空标题
                 let hasValidID = windowInfo[kCGWindowNumber as String] is CGWindowID
                 let hasValidLayer = layer >= 0
                 let bounds = windowInfo[kCGWindowBounds as String] as? [String: Any]
                 let width = (bounds?["Width"] as? NSNumber)?.intValue ?? 0
                 let height = (bounds?["Height"] as? NSNumber)?.intValue ?? 0
                 let hasReasonableSize = width > 100 && height > 100 // 过滤掉太小的窗口
                 
                 print("   过滤检查: ID=\(hasValidID), Layer=\(hasValidLayer), Size=\(width)x\(height), ReasonableSize=\(hasReasonableSize)")
                 
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
                    print("   ✅ 窗口已添加: '\(projectName)'")
                    
                    validWindowIndex += 1  // 增加有效窗口索引
                } else {
                    print("   ❌ 窗口被过滤")
                }
                print("")
            }
        }
        
                 print("📊 统计结果:")
         print("   目标应用候选窗口: \(candidateWindows.count)")
         print("   有效窗口: \(validWindows.count)")
         print("   最终添加窗口: \(windows.count)")
         print("=== 调试信息结束 ===\n")
     }
     
     // MARK: - CT2功能：获取所有应用的窗口信息
     private func getAllAppsWithWindows() {
         apps.removeAll()
         // 不再全量清空AX缓存，让智能清理机制处理
         
         print("\n=== CT2调试信息开始 ===")
         
         // 获取所有运行的应用
         let allApps = NSWorkspace.shared.runningApplications
         print("所有运行的应用总数: \(allApps.count)")
         
         // 获取所有窗口，按照前后顺序排列（最前面的窗口排在前面）
         // 这个顺序就是Command+Tab的真实顺序
         let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
         print("系统总共找到 \(windowList.count) 个窗口")
         
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
         
         print("有效应用数量: \(appInfoMap.count)")
         
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
         
         print("📊 CT2统计结果:")
         print("   有效应用数量: \(apps.count)")
         for (index, app) in apps.enumerated() {
             let activeStatus = app.isActive ? " [ACTIVE]" : ""
             print("   \(index + 1). \(app.appName): \(app.windowCount) 个窗口\(activeStatus)")
         }
         print("=== CT2调试信息结束 ===\n")
     }
     
     // 通过 AX API 获取特定窗口ID对应的标题和AXUIElement
     private func getAXWindowInfo(windowID: CGWindowID, processID: pid_t, windowIndex: Int) -> (title: String, axElement: AXUIElement?) {
         let app = AXUIElementCreateApplication(processID)
         
         var windowsRef: CFTypeRef?
         guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef) == .success,
               let axWindows = windowsRef as? [AXUIElement] else {
             print("   ❌ 无法获取AX窗口列表")
             return ("", nil)
         }
         
         print("   🔍 AX窗口总数: \(axWindows.count), 目标索引: \(windowIndex)")
         
         // 直接通过索引获取对应的AX窗口
         guard windowIndex < axWindows.count else {
             print("   ❌ 窗口索引 \(windowIndex) 超出范围 (总数: \(axWindows.count))")
             return ("", nil)
         }
         
         let axWindow = axWindows[windowIndex]
         
         // 获取窗口标题
         var titleRef: CFTypeRef?
         if AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleRef) == .success,
            let title = titleRef as? String {
             print("   ✅ 窗口ID \(windowID) 通过索引[\(windowIndex)]匹配成功，标题: '\(title)'")
             return (title, axWindow)
         } else {
             print("   ⚠️ 窗口ID \(windowID) 通过索引[\(windowIndex)]匹配成功，但无标题")
             return ("", axWindow)
         }
     }
    
    
    private func activateWindow(_ window: WindowInfo) {
        print("\n🎯 尝试激活窗口ID: \(window.windowID), 标题: '\(window.title)'")
        
        // 优先使用AX增强方法
        if activateWindowWithAXEnhanced(window) {
            print("   ✅ AX增强方法激活成功")
            return
        }
        
        print("   ⚠️ AX增强方法失败，尝试降级方案")
        
        // 降级方案1: 传统AX方法（保持向后兼容）
        let windowBounds = getWindowBounds(windowID: window.windowID)
        
        // 首先尝试从缓存中获取AXUIElement
        if let cachedElement = getCachedAXElement(windowID: window.windowID, processID: window.processID, windowIndex: window.axWindowIndex) {
            print("   ✅ 获取到AX元素（缓存或新建）")
            
            // 执行多显示器焦点转移和窗口激活
            if activateWindowWithFocusTransfer(axElement: cachedElement, windowBounds: windowBounds, window: window) {
                print("   ✅ 窗口激活成功")
                return
            } else {
                print("   ⚠️ AX元素激活失败")
            }
        }
        
        print("   ❌ 无法获取窗口ID \(window.windowID) 的AX元素")
        
        // 降级方案：尝试使用Core Graphics API
        print("   🔄 尝试最终降级方案")
        fallbackActivateWindowWithFocusTransfer(window.windowID, processID: window.processID, windowBounds: windowBounds)
    }
    
    // MARK: - AX增强的多显示器焦点转移支持
    
    // 显示器信息结构
    struct DisplayInfo {
        let screen: NSScreen
        let windowRect: CGRect
        let displayID: CGDirectDisplayID
    }
    
    // AX增强的窗口激活方法（主入口）
    private func activateWindowWithAXEnhanced(_ window: WindowInfo) -> Bool {
        guard let axElement = getCachedAXElement(windowID: window.windowID, processID: window.processID, windowIndex: window.axWindowIndex) else {
            print("   ❌ AX增强激活失败：无法获取AX元素")
            return false
        }
        
        print("   🔄 使用AX增强方法激活窗口")
        
        // 获取窗口显示器信息
        guard let displayInfo = getWindowDisplayInfo(axElement: axElement) else {
            print("   ❌ AX增强激活失败：无法获取显示器信息")
            return false
        }
        
        // 检查是否需要跨显示器激活
        let currentScreen = getCurrentFocusedScreen()
        let needsCrossDisplayActivation = (displayInfo.screen != currentScreen)
        
        print("   📍 窗口位置: \(displayInfo.windowRect)")
        print("   🖥️ 目标显示器: \(displayInfo.screen.localizedName)")
        print("   🔄 需要跨显示器激活: \(needsCrossDisplayActivation)")
        
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
            print("   ⚠️ 无法获取窗口位置")
            return nil
        }
        
        // 获取窗口大小
        var sizeRef: CFTypeRef?
        guard AXUIElementCopyAttributeValue(axElement, kAXSizeAttribute as CFString, &sizeRef) == .success,
              let sizeValue = sizeRef else {
            print("   ⚠️ 无法获取窗口大小")
            return nil
        }
        
        // 转换为CGPoint和CGSize
        var point = CGPoint.zero
        var cgSize = CGSize.zero
        
        guard AXValueGetValue(positionValue as! AXValue, .cgPoint, &point) == true,
              AXValueGetValue(sizeValue as! AXValue, .cgSize, &cgSize) == true else {
            print("   ⚠️ AX值转换失败")
            return nil
        }
        
        // 计算窗口矩形
        let windowRect = CGRect(origin: point, size: cgSize)
        
        // 找到包含此窗口的显示器
        guard let targetScreen = findScreenContaining(rect: windowRect) else {
            print("   ⚠️ 无法找到包含窗口的显示器")
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
        print("   🚀 执行跨显示器AX激活")
        
        // 步骤1: 智能焦点转移到目标显示器
        if !transferFocusToDisplay(displayInfo: displayInfo) {
            print("   ⚠️ 焦点转移失败，但继续尝试激活")
        }
        
        // 步骤2: 激活应用进程
        guard let app = NSRunningApplication(processIdentifier: window.processID) else {
            print("   ❌ 无法获取应用进程")
            return false
        }
        
        let appActivated = app.activate()
        print("   🎯 应用激活结果: \(appActivated ? "成功" : "失败")")
        
        // 步骤3: 使用AX API提升窗口
        let raiseResult = AXUIElementPerformAction(axElement, kAXRaiseAction as CFString)
        print("   ⬆️ AX窗口提升结果: \(raiseResult == .success ? "成功" : "失败")")
        
        // 步骤4: 设置窗口为焦点窗口
        AXUIElementSetAttributeValue(axElement, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(axElement, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        
        // 步骤5: 验证激活结果
        let success = verifyWindowActivation(axElement: axElement, displayInfo: displayInfo)
        print("   ✅ 跨显示器激活\(success ? "成功" : "失败")")
        
        return success
    }
    
    // 同显示器激活窗口（AX增强方法）
    private func performSameDisplayAXActivation(axElement: AXUIElement, window: WindowInfo) -> Bool {
        print("   🎯 执行同显示器AX激活")
        
        // 步骤1: 激活应用进程
        guard let app = NSRunningApplication(processIdentifier: window.processID) else {
            print("   ❌ 无法获取应用进程")
            return false
        }
        
        let appActivated = app.activate()
        print("   🎯 应用激活结果: \(appActivated ? "成功" : "失败")")
        
        // 步骤2: 使用AX API提升窗口
        let raiseResult = AXUIElementPerformAction(axElement, kAXRaiseAction as CFString)
        print("   ⬆️ AX窗口提升结果: \(raiseResult == .success ? "成功" : "失败")")
        
        // 步骤3: 设置窗口为焦点窗口
        AXUIElementSetAttributeValue(axElement, kAXMainAttribute as CFString, kCFBooleanTrue)
        AXUIElementSetAttributeValue(axElement, kAXFocusedAttribute as CFString, kCFBooleanTrue)
        
        return raiseResult == .success
    }
    
    // 智能焦点转移到目标显示器
    private func transferFocusToDisplay(displayInfo: DisplayInfo) -> Bool {
        print("   🔄 转移焦点到显示器: \(displayInfo.screen.localizedName)")
        
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
            print("   ❌ 无法创建鼠标移动事件")
            return false
        }
        
        // 发送事件
        moveEvent.post(tap: .cghidEventTap)
        
        // 短暂延迟确保焦点转移完成
        usleep(30000) // 30ms
        
        print("   🖱️ 鼠标已移动到目标窗口位置: (\(targetPoint.x), \(targetPoint.y))")
        return true
    }
    
    // 验证窗口激活结果
    private func verifyWindowActivation(axElement: AXUIElement, displayInfo: DisplayInfo) -> Bool {
        // 验证1: 检查窗口是否为主窗口
        var isMainRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(axElement, kAXMainAttribute as CFString, &isMainRef) == .success,
           let isMain = isMainRef as? Bool, isMain {
            print("   ✅ 窗口已成为主窗口")
            return true
        }
        
        // 验证2: 检查窗口是否有焦点
        var isFocusedRef: CFTypeRef?
        if AXUIElementCopyAttributeValue(axElement, kAXFocusedAttribute as CFString, &isFocusedRef) == .success,
           let isFocused = isFocusedRef as? Bool, isFocused {
            print("   ✅ 窗口已获得焦点")
            return true
        }
        
        print("   ⚠️ 窗口激活验证未通过，但可能仍然成功")
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
        print("   AXRaiseAction 结果: \(raiseResult == .success ? "成功" : "失败")")
        
        // 将应用置于前台
        if let app = NSRunningApplication(processIdentifier: window.processID) {
            let activateResult = app.activate()
            print("   应用激活结果: \(activateResult ? "成功" : "失败")")
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
            print("   🖱️ 将鼠标从显示器 \(currentScreen?.localizedName ?? "未知") 移动到 \(target.localizedName)")
            
            // 使用Core Graphics移动鼠标
            let moveEvent = CGEvent(mouseEventSource: nil, mouseType: .mouseMoved, mouseCursorPosition: windowCenter, mouseButton: .left)
            moveEvent?.post(tap: .cghidEventTap)
            
            print("   🖱️ 鼠标已移动到窗口中心: (\(windowCenter.x), \(windowCenter.y))")
        } else {
            print("   🖱️ 鼠标已在目标显示器上，无需移动")
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
            print("   降级方案 - 应用激活结果: \(activateResult ? "成功" : "失败")")
        }
        
        // 注意：Core Graphics没有直接激活特定窗口的API
        // 这里只能激活应用，让它自己决定显示哪个窗口
        print("   ⚠️ 使用降级方案，只能激活应用，无法精确控制窗口")
        print("   🖱️ 已将鼠标移动到目标窗口所在显示器以改善焦点转移")
    }
    
    // 降级方案：使用Core Graphics API激活窗口（保持向后兼容）
    private func fallbackActivateWindow(_ windowID: CGWindowID, processID: pid_t) {
        // 将应用置于前台
        if let app = NSRunningApplication(processIdentifier: processID) {
            let activateResult = app.activate()
            print("   降级方案 - 应用激活结果: \(activateResult ? "成功" : "失败")")
        }
        
        // 注意：Core Graphics没有直接激活特定窗口的API
        // 这里只能激活应用，让它自己决定显示哪个窗口
        print("   ⚠️ 使用降级方案，只能激活应用，无法精确控制窗口")
    }
    
    // MARK: - 增强事件处理机制 (方案3)
    
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
        
        print("🔧 统一事件处理机制已设置")
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
                print("🔴 [\(source)] 检测到ESC键，关闭DS2切换器")
                hideSwitcherAsync()
                return nil
            }
            
        case .keyDown:
            // 处理触发键
            if event.keyCode == UInt16(settings.triggerKey.keyCode) {
                if event.modifierFlags.contains(settings.modifierKey.eventModifier) {
                    let isShiftPressed = event.modifierFlags.contains(.shift)
                    
                    if isShiftPressed {
                        print("🟢 [\(source)] DS2反向切换: \(currentWindowIndex) -> ", terminator: "")
                        moveToPreviousWindow()
                        print("\(currentWindowIndex)")
                    } else {
                        print("🟢 [\(source)] DS2正向切换: \(currentWindowIndex) -> ", terminator: "")
                        moveToNextWindow()
                        print("\(currentWindowIndex)")
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
                print("🔴 [\(source)] 检测到\(settings.modifierKey.displayName)键松开，关闭DS2切换器")
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
                print("🔴 [\(source)] 检测到ESC键，关闭CT2切换器")
                hideAppSwitcherAsync()
                return nil
            }
            
        case .keyDown:
            // 处理触发键
            if event.keyCode == UInt16(settings.ct2TriggerKey.keyCode) {
                if event.modifierFlags.contains(settings.ct2ModifierKey.eventModifier) {
                    let isShiftPressed = event.modifierFlags.contains(.shift)
                    
                    if isShiftPressed {
                        print("🟢 [\(source)] CT2反向切换: \(currentAppIndex) -> ", terminator: "")
                        moveToPreviousApp()
                        print("\(currentAppIndex)")
                    } else {
                        print("🟢 [\(source)] CT2正向切换: \(currentAppIndex) -> ", terminator: "")
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
                print("🔴 [\(source)] 检测到\(settings.ct2ModifierKey.displayName)键松开，关闭CT2切换器")
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
    
    // MARK: - 异步窗口激活优化 (方案2)
    
    /// 异步版本的DS2切换器隐藏方法，提供更流畅的体验
    private func hideSwitcherAsync() {
        guard isShowingSwitcher else { return }
        
        print("🚀 异步隐藏DS2切换器开始")
        
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
            print("🎯 准备异步激活窗口: \(targetWindow.title)")
            
            // 使用用户初始优先级确保响应性
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.activateWindowAsync(targetWindow)
            }
        }
        
        print("🚀 DS2切换器UI已隐藏，窗口激活异步进行中")
    }
    
    /// 异步版本的CT2切换器隐藏方法，提供更流畅的体验
    private func hideAppSwitcherAsync() {
        guard isShowingAppSwitcher else { return }
        
        print("🚀 异步隐藏CT2切换器开始")
        
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
            print("🎯 准备异步激活应用: \(apps[currentAppIndex].appName)")
            
            // 使用用户初始优先级确保响应性
            DispatchQueue.global(qos: .userInitiated).async { [weak self] in
                self?.activateWindowAsync(firstWindow)
            }
        }
        
        print("🚀 CT2切换器UI已隐藏，应用激活异步进行中")
    }
    
    /// 异步窗口激活方法，优化性能和流畅度
    private func activateWindowAsync(_ window: WindowInfo) {
        print("🚀 异步激活窗口开始: \(window.title)")
        
        // 首先尝试快速激活应用
        guard let app = NSRunningApplication(processIdentifier: window.processID) else {
            print("❌ 无法找到进程ID \(window.processID) 对应的应用")
            return
        }
        
        // 在主线程激活应用（系统要求）
        DispatchQueue.main.async {
            let activated = app.activate()
            print("   📱 应用激活结果: \(activated ? "成功" : "失败")")
        }
        
        // 短暂延迟后激活具体窗口
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            self?.activateSpecificWindowFast(window)
        }
    }
    
    /// 快速窗口激活方法，简化复杂的多显示器处理
    private func activateSpecificWindowFast(_ window: WindowInfo) {
        print("⚡ 快速激活具体窗口: \(window.title)")
        
        // 尝试从缓存获取AX元素
        if let axElement = getCachedAXElement(
            windowID: window.windowID,
            processID: window.processID, 
            windowIndex: window.axWindowIndex
        ) {
            // 使用AX API激活窗口
            let raiseResult = AXUIElementPerformAction(axElement, kAXRaiseAction as CFString)
            print("   ⚡ AX激活结果: \(raiseResult == .success ? "成功" : "失败")")
            
            if raiseResult == .success {
                // 尝试设置为主窗口和焦点窗口
                AXUIElementSetAttributeValue(axElement, kAXMainAttribute as CFString, kCFBooleanTrue)
                AXUIElementSetAttributeValue(axElement, kAXFocusedAttribute as CFString, kCFBooleanTrue)
                print("   ✅ 窗口激活完成")
                return
            }
        }
        
        // 如果AX方法失败，使用降级方案
        print("   ⚠️ AX方法失败，使用降级方案")
        fallbackActivateAsync(window)
    }
    
    /// 异步降级激活方案
    private func fallbackActivateAsync(_ window: WindowInfo) {
        // 简化的降级方案，只激活应用
        if let app = NSRunningApplication(processIdentifier: window.processID) {
            app.activate()
            print("   📱 降级方案：应用已激活")
        }
        
        // 可选：尝试通过窗口ID进行基本操作（如果需要）
        // 这里可以添加其他轻量级的窗口操作
    }
    
    // MARK: - 修饰键看门狗机制
    
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
            print("🐕 看门狗：非快速切换场景，跳过启动")
            return
        }
        
        print("🐕 启动修饰键看门狗，类型: \(switcherType == .ds2 ? "DS2" : "CT2"), 间隔: \(Int(watchdogInterval * 1000))ms")
        
        modifierKeyWatchdog = Timer.scheduledTimer(withTimeInterval: watchdogInterval, repeats: true) { [weak self] _ in
            self?.checkModifierKeyState(for: switcherType)
        }
    }
    
    /// 停止修饰键看门狗
    private func stopModifierKeyWatchdog() {
        guard let watchdog = modifierKeyWatchdog else { return }
        
        print("🐕 停止修饰键看门狗，运行时间: \(String(format: "%.1f", Double(watchdogCallCount) * watchdogInterval))s，检测次数: \(watchdogCallCount)")
        
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
            print("🐕⚠️ 看门狗超时自动停止（1000次检测）")
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
            print("🐕 看门狗检测到切换器已关闭，自动停止")
            stopModifierKeyWatchdog()
            return
        }
        
        // 检查修饰键是否仍在按下状态
        if !currentModifiers.contains(requiredModifier) {
            print("🐕🚨 [看门狗检测] \(modifierName)键已松开，立即关闭\(switcherType == .ds2 ? "DS2" : "CT2")切换器")
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
            print("🐕 看门狗进入低频模式")
            stopModifierKeyWatchdog()
            
            // 重新启动低频看门狗
            modifierKeyWatchdog = Timer.scheduledTimer(withTimeInterval: 0.033, repeats: true) { [weak self] _ in
                self?.checkModifierKeyState(for: switcherType)
            }
        }
        
        // 每100次检测输出一次状态（约1.6秒）
        if watchdogCallCount % 100 == 0 {
            print("🐕 看门狗运行正常，已检测\(watchdogCallCount)次，\(modifierName)键状态: 按下中")
        }
    }
} 
