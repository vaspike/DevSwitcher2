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
    
    private var switcherWindow: NSWindow?
    private var eventMonitor: Any?
    private var globalEventMonitor: Any?
    
    // 缓存窗口ID到AXUIElement的映射
    private var axElementCache: [CGWindowID: AXUIElement] = [:]
    
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
        
        // 设置 SwiftUI 内容视图
        let contentView = WindowSwitcherView(windowManager: self)
        switcherWindow?.contentView = NSHostingView(rootView: contentView)
        
        // 居中显示
        switcherWindow?.center()
    }
    
    func showWindowSwitcher() {
        guard !isShowingSwitcher else { return }
        
        // 清除应用图标缓存，确保图标信息最新
        AppIconCache.shared.clearCache()
        
        // 获取当前应用的窗口
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
        
        // 显示切换器窗口
        switcherWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate()
        
        // 监听键盘事件（包括修饰键变化）
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp, .flagsChanged]) { [weak self] event in
            return self?.handleKeyEvent(event)
        }
        
        // 添加全局事件监听器以监听修饰键变化（检测Command键释放）
        globalEventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.flagsChanged]) { [weak self] event in
            self?.handleGlobalKeyEvent(event)
        }
    }
    
    func hideSwitcher() {
        guard isShowingSwitcher else { return }
        
        isShowingSwitcher = false
        switcherWindow?.orderOut(nil)
        
        // 正确移除事件监听器
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
        if let globalMonitor = globalEventMonitor {
            NSEvent.removeMonitor(globalMonitor)
            globalEventMonitor = nil
        }
        
        // 重新启用全局热键
        hotkeyManager?.reEnableHotkey()
        
        // 清除应用图标缓存
        AppIconCache.shared.clearCache()
        
        // 激活选中的窗口
        if currentWindowIndex < windows.count {
            activateWindow(windows[currentWindowIndex])
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        guard isShowingSwitcher else { return event }
        
        // ESC键关闭切换器
        if event.type == .keyUp && event.keyCode == 53 { // ESC key
            hideSwitcher()
            return nil
        }
        
        // 处理触发键
        let settings = settingsManager.settings
        if event.keyCode == UInt16(settings.triggerKey.keyCode) {
            if event.type == .keyDown {
                // 触发键按下：检查修饰键是否还在按下状态
                if event.modifierFlags.contains(settings.modifierKey.eventModifier) {
                    // 检查是否同时按下shift键
                    let isShiftPressed = event.modifierFlags.contains(.shift)
                    
                    if isShiftPressed {
                        print("🟢 DS2已显示，检测到\(settings.triggerKey.displayName)键且\(settings.modifierKey.displayName)+Shift键按下，当前索引: \(currentWindowIndex), 窗口总数: \(windows.count)")
                        moveToPreviousWindow()
                        print("🟢 反向切换后索引: \(currentWindowIndex)")
                    } else {
                        print("🟢 DS2已显示，检测到\(settings.triggerKey.displayName)键且\(settings.modifierKey.displayName)键按下，当前索引: \(currentWindowIndex), 窗口总数: \(windows.count)")
                        moveToNextWindow()
                        print("🟢 切换后索引: \(currentWindowIndex)")
                    }
                    return nil // 阻止事件传递，避免触发全局热键
                }
            }
            return event
        }
        
        // 检测修饰键松开
        if event.type == .flagsChanged {
            let settings = settingsManager.settings
            // 修饰键被松开（modifierFlags不再包含对应修饰键）
            if !event.modifierFlags.contains(settings.modifierKey.eventModifier) {
                print("🔴 检测到\(settings.modifierKey.displayName)键松开，隐藏切换器")
                hideSwitcher()
                return nil
            }
        }
        
        return event
    }
    
    private func handleGlobalKeyEvent(_ event: NSEvent) {
        guard isShowingSwitcher else { return }
        
        // 只处理修饰键变化，检测修饰键松开
        if event.type == .flagsChanged {
            let settings = settingsManager.settings
            if !event.modifierFlags.contains(settings.modifierKey.eventModifier) {
                print("🌍 全局事件: 检测到\(settings.modifierKey.displayName)键松开，隐藏切换器")
                DispatchQueue.main.async {
                    self.hideSwitcher()
                }
            }
        }
    }
    
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
    
    private func getCurrentAppWindows() {
        windows.removeAll()
        axElementCache.removeAll() // 清空AX元素缓存
        
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
        
        guard let targetApp = frontmostApp else {
            print("❌ 无法获取前台应用")
            return
        }
        
        print("\n🎯 目标应用: \(targetApp.localizedName ?? "Unknown") (PID: \(targetApp.processIdentifier))")
        print("   Bundle ID: \(targetApp.bundleIdentifier ?? "Unknown")")
        
        // 获取所有窗口
        let windowList = CGWindowListCopyWindowInfo(.optionOnScreenOnly, kCGNullWindowID) as? [[String: Any]] ?? []
        print("\n📋 系统总共找到 \(windowList.count) 个窗口")
        
        // 打印所有窗口信息
        print("\n🔍 所有窗口详情:")
        for (index, windowInfo) in windowList.enumerated() {
            let processID = windowInfo[kCGWindowOwnerPID as String] as? pid_t ?? -1
            let windowTitle = windowInfo[kCGWindowName as String] as? String ?? ""
            let layer = windowInfo[kCGWindowLayer as String] as? Int ?? -1
            let windowID = windowInfo[kCGWindowNumber as String] as? CGWindowID ?? 0
            let bounds = windowInfo[kCGWindowBounds as String] as? [String: Any]
            let width = (bounds?["Width"] as? NSNumber)?.intValue ?? 0
            let height = (bounds?["Height"] as? NSNumber)?.intValue ?? 0
            let ownerName = windowInfo[kCGWindowOwnerName as String] as? String ?? "Unknown"
            let isOnScreen = windowInfo[kCGWindowIsOnscreen as String] as? Bool ?? false
            
            let isTarget = processID == targetApp.processIdentifier ? " ⭐ [TARGET]" : ""
            
            print("  [\(index)] PID:\(processID) | Layer:\(layer) | Size:\(width)x\(height) | OnScreen:\(isOnScreen)")
            print("       Owner: \(ownerName)")
            print("       Title: '\(windowTitle)'\(isTarget)")
            print("       ID: \(windowID)")
            print("")
        }
        
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
                     let (axTitle, axElement) = getAXWindowInfo(windowID: windowID, processID: processID, windowIndex: validWindowIndex)
                     
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
                     
                     // 缓存AXUIElement
                     if let element = axElement {
                         axElementCache[windowID] = element
                     }
                    
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
        if let cachedElement = axElementCache[window.windowID] {
            print("   ✅ 从缓存中找到AX元素")
            
            // 执行多显示器焦点转移和窗口激活
            if activateWindowWithFocusTransfer(axElement: cachedElement, windowBounds: windowBounds, window: window) {
                print("   ✅ 窗口激活成功（使用缓存元素）")
                return
            } else {
                print("   ⚠️ 缓存的AX元素激活失败，尝试重新获取")
                // 从缓存中移除失效的元素
                axElementCache.removeValue(forKey: window.windowID)
            }
        }
        
        // 如果缓存中没有或激活失败，重新获取AXUIElement
        print("   🔍 重新获取AX元素")
        let (_, axElement) = getAXWindowInfo(windowID: window.windowID, processID: window.processID, windowIndex: window.axWindowIndex)
        
        if let element = axElement {
            print("   ✅ 重新获取AX元素成功")
            
            // 更新缓存
            axElementCache[window.windowID] = element
            
            // 执行多显示器焦点转移和窗口激活
            if activateWindowWithFocusTransfer(axElement: element, windowBounds: windowBounds, window: window) {
                print("   ✅ 窗口激活成功（重新获取元素）")
            } else {
                print("   ❌ 窗口激活失败")
            }
        } else {
            print("   ❌ 无法获取窗口ID \(window.windowID) 的AX元素")
            
            // 降级方案2：尝试使用Core Graphics API
            print("   🔄 尝试最终降级方案")
            fallbackActivateWindowWithFocusTransfer(window.windowID, processID: window.processID, windowBounds: windowBounds)
        }
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
        guard let axElement = axElementCache[window.windowID] else {
            print("   ❌ AX增强激活失败：缓存中无AX元素")
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
} 
