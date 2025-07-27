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

class AppDelegate: NSObject, NSApplicationDelegate, NSWindowDelegate {
    var statusItem: NSStatusItem?
    var windowManager: WindowManager?
    var hotkeyManager: HotkeyManager?
    var preferencesWindow: NSWindow?
    var accessibilityCheckTimer: Timer? // 添加Timer引用用于管理
    
    deinit {
        // 清理Timer资源
        accessibilityCheckTimer?.invalidate()
        accessibilityCheckTimer = nil
        print("🗑️ AppDelegate已清理，Timer资源已释放")
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // 创建状态栏图标
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        
        if let button = statusItem?.button {
            button.image = NSImage(systemSymbolName: "rectangle.3.group", accessibilityDescription: LocalizedStrings.statusItemTooltip)
            button.action = #selector(statusBarButtonClicked)
            button.target = self
            button.toolTip = LocalizedStrings.statusItemTooltip
            
            // 设置右键菜单
            setupStatusBarMenu()
        }
        
        // 初始化窗口管理器和热键管理器
        windowManager = WindowManager()
        hotkeyManager = HotkeyManager(windowManager: windowManager!)
        
        // 设置双向引用
        windowManager?.hotkeyManager = hotkeyManager
        
        // 请求辅助功能权限
        requestAccessibilityPermission()
        
        // 注册热键
        hotkeyManager?.registerHotkey()
    }
    
    @objc func statusBarButtonClicked() {
        // 左键点击不再触发主逻辑，改为显示菜单
        if let menu = statusItem?.menu {
            statusItem?.popUpMenu(menu)
        }
    }
    
    private func setupStatusBarMenu() {
        let menu = NSMenu()
        
        // 偏好设置菜单项
        let preferencesItem = NSMenuItem(title: LocalizedStrings.preferences, action: #selector(showPreferences), keyEquivalent: ",")
        preferencesItem.target = self
        menu.addItem(preferencesItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // 退出应用菜单项
        let quitItem = NSMenuItem(title: LocalizedStrings.quitApp, action: #selector(quitApplication), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    @objc func showPreferences() {
        // 如果偏好设置窗口已经存在，就激活它
        if let window = preferencesWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate()
            return
        }
        
        // 创建偏好设置窗口
        let contentView = PreferencesView()
        let hostingView = NSHostingView(rootView: contentView)
        
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 500),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        
        window.title = LocalizedStrings.preferencesTitle
        window.contentView = hostingView
        window.center()
        window.setFrameAutosaveName("PreferencesWindow")
        window.isReleasedWhenClosed = false
        
        // 设置窗口关闭时的清理
        window.delegate = self
        
        preferencesWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate()
    }
    
    @objc func quitApplication() {
        NSApplication.shared.terminate(nil)
    }
    
    func requestAccessibilityPermission() {
        let accessibilityEnabled = AXIsProcessTrusted()
        
        if !accessibilityEnabled {
            print(LocalizedStrings.accessibilityPermissionRequired)
            
            // 显示权限提示对话框
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = LocalizedStrings.accessibilityPermissionTitle
                alert.informativeText = LocalizedStrings.accessibilityPermissionMessage
                alert.alertStyle = .informational
                alert.addButton(withTitle: LocalizedStrings.openSystemPreferencesButton)
                alert.addButton(withTitle: LocalizedStrings.setupLater)
                
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    // 打开系统偏好设置
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            }
            
            // 定期检查权限状态
            accessibilityCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                if AXIsProcessTrusted() {
                    print(LocalizedStrings.accessibilityPermissionGranted)
                    timer.invalidate()
                    self?.accessibilityCheckTimer = nil
                    // 权限获得后重新注册热键
                    self?.hotkeyManager?.registerHotkey()
                }
            }
        } else {
            print(LocalizedStrings.accessibilityPermissionGranted)
        }
    }
    
    // MARK: - NSWindowDelegate
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == preferencesWindow {
            preferencesWindow = nil
        }
    }
}
