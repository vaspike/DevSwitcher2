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
        
        // 处理 ` 键
        if event.keyCode == 50 { // ` key
            if event.type == .keyDown {
                // ` 键按下：检查Command键是否还在按下状态
                if event.modifierFlags.contains(.command) {
                    print("🟢 DS2已显示，检测到`键且Command键按下，当前索引: \(currentWindowIndex), 窗口总数: \(windows.count)")
                    moveToNextWindow()
                    print("🟢 切换后索引: \(currentWindowIndex)")
                    return nil // 阻止事件传递，避免触发全局热键
                }
            }
            return event
        }
        
        // 检测Command键松开
        if event.type == .flagsChanged {
            // Command键被松开（modifierFlags不再包含.command）
            if !event.modifierFlags.contains(.command) {
                print("🔴 检测到Command键松开，隐藏切换器")
                hideSwitcher()
                return nil
            }
        }
        
        return event
    }
    
    private func handleGlobalKeyEvent(_ event: NSEvent) {
        guard isShowingSwitcher else { return }
        
        // 只处理修饰键变化，检测Command键松开
        if event.type == .flagsChanged {
            if !event.modifierFlags.contains(.command) {
                print("🌍 全局事件: 检测到Command键松开，隐藏切换器")
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
                         projectName = extractProjectName(from: axTitle, appName: targetApp.localizedName ?? "")
                     } else if !windowTitle.isEmpty {
                         displayTitle = windowTitle
                         projectName = extractProjectName(from: windowTitle, appName: targetApp.localizedName ?? "")
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
    
         private func extractProjectName(from title: String, appName: String) -> String {
         // 根据不同 IDE 提取项目名的逻辑
         
         // Cursor 特殊处理
         if appName.contains("Cursor") {
             // Cursor 的标题格式可能是: "filename - folder" 或者包含路径信息
             if let range = title.range(of: " - ") {
                 let projectPart = String(title[range.upperBound...])
                 // 如果还有更多的 " - "，取最后一部分
                 if let lastRange = projectPart.range(of: " - ", options: .backwards) {
                     return String(projectPart[lastRange.upperBound...])
                 }
                 return projectPart
             }
             // 如果包含路径分隔符，取最后一个路径组件
             if title.contains("/") {
                 let components = title.components(separatedBy: "/")
                 return components.last ?? title
             }
         }
         
         // VS Code: "filename - projectname"
         if appName.contains("Code") {
             if let range = title.range(of: " - ") {
                 let projectPart = String(title[range.upperBound...])
                 // 如果还有更多的 " - "，取最后一部分
                 if let lastRange = projectPart.range(of: " - ", options: .backwards) {
                     return String(projectPart[lastRange.upperBound...])
                 }
                 return projectPart
             }
         }
        
        // Xcode: "projectname — Edited"
        if appName.contains("Xcode") {
            if let range = title.range(of: " — ") {
                return String(title[..<range.lowerBound])
            }
        }
        
        // IntelliJ IDEA: "[projectname] - filename"
        if appName.contains("IDEA") || appName.contains("IntelliJ") {
            if title.hasPrefix("[") {
                if let endBracket = title.firstIndex(of: "]") {
                    return String(title[title.index(after: title.startIndex)..<endBracket])
                }
            }
        }
        
        // 默认情况：直接返回窗口标题
        return title
    }
    
    private func activateWindow(_ window: WindowInfo) {
        print("\n🎯 尝试激活窗口ID: \(window.windowID), 标题: '\(window.title)'")
        
        // 首先尝试从缓存中获取AXUIElement
        if let cachedElement = axElementCache[window.windowID] {
            print("   ✅ 从缓存中找到AX元素")
            
            // 激活窗口
            let raiseResult = AXUIElementPerformAction(cachedElement, kAXRaiseAction as CFString)
            print("   AXRaiseAction 结果: \(raiseResult == .success ? "成功" : "失败")")
            
            // 将应用置于前台
            if let app = NSRunningApplication(processIdentifier: window.processID) {
                let activateResult = app.activate()
                print("   应用激活结果: \(activateResult ? "成功" : "失败")")
            }
            
            if raiseResult == .success {
                print("   ✅ 窗口激活成功")
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
            
            // 激活窗口
            let raiseResult = AXUIElementPerformAction(element, kAXRaiseAction as CFString)
            print("   AXRaiseAction 结果: \(raiseResult == .success ? "成功" : "失败")")
            
            // 将应用置于前台
            if let app = NSRunningApplication(processIdentifier: window.processID) {
                let activateResult = app.activate()
                print("   应用激活结果: \(activateResult ? "成功" : "失败")")
            }
            
            if raiseResult == .success {
                print("   ✅ 窗口激活成功")
            } else {
                print("   ❌ 窗口激活失败")
            }
        } else {
            print("   ❌ 无法获取窗口ID \(window.windowID) 的AX元素")
            
            // 降级方案：尝试使用Core Graphics API
            print("   🔄 尝试降级方案")
            fallbackActivateWindow(window.windowID, processID: window.processID)
        }
    }
    
    // 降级方案：使用Core Graphics API激活窗口
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
