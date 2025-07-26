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
}

class WindowManager: ObservableObject {
    @Published var windows: [WindowInfo] = []
    @Published var isShowingSwitcher = false
    @Published var currentWindowIndex = 0
    
    private var switcherWindow: NSWindow?
    private var eventMonitor: Any?
    
    init() {
        setupSwitcherWindow()
    }
    
    deinit {
        // 确保事件监听器被清理
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
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
        currentWindowIndex = 0
        
        // 显示切换器窗口
        switcherWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // 监听键盘事件
        eventMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .keyUp]) { [weak self] event in
            return self?.handleKeyEvent(event)
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
        
        // 激活选中的窗口
        if currentWindowIndex < windows.count {
            activateWindow(windows[currentWindowIndex])
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        guard isShowingSwitcher else { return event }
        
        if event.type == .keyUp && event.keyCode == 53 { // ESC key
            hideSwitcher()
            return nil
        }
        
        if event.type == .keyUp && event.keyCode == 50 { // ` key
            if event.modifierFlags.contains(.command) {
                // 继续在窗口间切换
                moveToNextWindow()
                return nil
            } else {
                // 释放 Command 键，选择当前窗口
                hideSwitcher()
                return nil
            }
        }
        
        return event
    }
    
    func moveToNextWindow() {
        guard !windows.isEmpty else { return }
        currentWindowIndex = (currentWindowIndex + 1) % windows.count
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
                    
                                         // 尝试通过AX API获取更详细的窗口信息
                     let projectName: String
                     if windowTitle.isEmpty {
                         let axTitle = getAXWindowTitle(windowID: windowID, processID: processID)
                         if !axTitle.isEmpty {
                             projectName = extractProjectName(from: axTitle, appName: targetApp.localizedName ?? "")
                         } else {
                             projectName = "\(targetApp.localizedName ?? "应用") 窗口 \(windowCounter)"
                             windowCounter += 1
                         }
                     } else {
                         projectName = extractProjectName(from: windowTitle, appName: targetApp.localizedName ?? "")
                     }
                    
                    let window = WindowInfo(
                        windowID: windowID,
                        title: windowTitle,
                        projectName: projectName,
                        appName: targetApp.localizedName ?? "",
                        processID: processID
                    )
                    
                    windows.append(window)
                    print("   ✅ 窗口已添加: '\(projectName)'")
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
     
     // 通过 AX API 获取窗口标题
     private func getAXWindowTitle(windowID: CGWindowID, processID: pid_t) -> String {
         let app = AXUIElementCreateApplication(processID)
         
         var windowsRef: CFTypeRef?
         guard AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef) == .success,
               let axWindows = windowsRef as? [AXUIElement] else {
             return ""
         }
         
         for axWindow in axWindows {
             // 直接尝试获取标题，不需要位置匹配
             var titleRef: CFTypeRef?
             if AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleRef) == .success,
                let title = titleRef as? String,
                !title.isEmpty {
                 print("   AX API 找到标题: '\(title)'")
                 return title
             }
         }
         
         return ""
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
        // 使用 AX API 激活窗口
        let app = AXUIElementCreateApplication(window.processID)
        
        var windowsRef: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(app, kAXWindowsAttribute as CFString, &windowsRef)
        
        if result == .success, let windows = windowsRef as? [AXUIElement] {
            for axWindow in windows {
                var titleRef: CFTypeRef?
                if AXUIElementCopyAttributeValue(axWindow, kAXTitleAttribute as CFString, &titleRef) == .success,
                   let title = titleRef as? String,
                   title == window.title {
                    
                    // 激活窗口
                    AXUIElementPerformAction(axWindow, kAXRaiseAction as CFString)
                    
                    // 将应用置于前台
                    if let app = NSRunningApplication(processIdentifier: window.processID) {
                        app.activate(options: .activateIgnoringOtherApps)
                    }
                    break
                }
            }
        }
    }
} 