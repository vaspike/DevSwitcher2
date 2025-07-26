//
//  DevSwitcher2App.swift
//  DevSwitcher2
//
//  Created by river on 2025-07-26.
//

import SwiftUI
import AppKit

@main
struct DevSwitcher2App: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var windowManager: WindowManager?
    var hotkeyManager: HotkeyManager?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 创建状态栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: LocalizedStrings.statusItemTooltip)
            button.action = #selector(statusBarButtonClicked)
            button.target = self
            button.toolTip = LocalizedStrings.statusItemTooltip
        }
        
        // 初始化窗口管理器和热键管理器
        windowManager = WindowManager()
        hotkeyManager = HotkeyManager(windowManager: windowManager!)
        
        // 请求辅助功能权限
        requestAccessibilityPermission()
        
        // 注册热键
        hotkeyManager?.registerHotkey()
    }
    
    @objc func statusBarButtonClicked() {
        // 点击状态栏图标时的操作
        windowManager?.showWindowSwitcher()
    }
    
    func requestAccessibilityPermission() {
        let accessibilityEnabled = AXIsProcessTrusted()
        
        if !accessibilityEnabled {
            print(LocalizedStrings.accessibilityPermissionRequired)
            
            // 显示权限提示对话框
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "需要辅助功能权限"
                alert.informativeText = "DevSwitcher2 需要辅助功能权限来获取和切换应用窗口。请在系统偏好设置 > 安全性与隐私 > 辅助功能 中启用 DevSwitcher2。"
                alert.alertStyle = .informational
                alert.addButton(withTitle: "打开系统偏好设置")
                alert.addButton(withTitle: "稍后设置")
                
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    // 打开系统偏好设置
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            }
            
            // 定期检查权限状态
            Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { timer in
                if AXIsProcessTrusted() {
                    print("辅助功能权限已授予")
                    timer.invalidate()
                    // 权限获得后重新注册热键
                    self.hotkeyManager?.registerHotkey()
                }
            }
        } else {
            print("辅助功能权限已启用")
        }
    }
}
