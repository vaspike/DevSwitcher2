//
//  HotkeyManager.swift
//  DevSwitcher2
//
//  Created by river on 2025-07-26.
//

import Foundation
import Carbon
import AppKit

class HotkeyManager {
    private var eventHotKeyRef: EventHotKeyRef?
    private var ct2EventHotKeyRef: EventHotKeyRef?  // CT2热键引用
    private let windowManager: WindowManager
    private var eventHandler: EventHandlerRef?
    private let settingsManager = SettingsManager.shared
    
    // CGEventTap相关
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isShowingCT2Switcher = false  // 跟踪CT2切换器是否正在显示
    
    init(windowManager: WindowManager) {
        self.windowManager = windowManager
        
        // 监听快捷键设置变化
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(hotkeySettingsChanged),
            name: .hotkeySettingsChanged,
            object: nil
        )
    }
    
    deinit {
        unregisterHotkey()
        stopEventTap()
        NotificationCenter.default.removeObserver(self)
    }
    
    @objc private func hotkeySettingsChanged() {
        print("快捷键设置已更改，重新注册热键")
        unregisterHotkey()
        registerHotkey()
    }
    
    func registerHotkey() {
        let settings = settingsManager.settings
        
        // 注册DS2热键
        registerDS2Hotkey()
        
        // 注册CT2热键（如果启用）
        if settings.ct2Enabled {
            registerCT2Hotkey()
            
            // 如果CT2是Command+Tab，启动EventTap来拦截系统事件
            if needsEventTapForCT2() {
                startEventTap()
            }
        }
    }
    
    private func registerDS2Hotkey() {
        // 定义DS2热键 ID
        let hotkeyId = EventHotKeyID(signature: OSType(0x44455653), id: 1) // 'DEVS'
        
        // 从设置中获取快捷键配置
        let settings = settingsManager.settings
        let keyCode = settings.triggerKey.keyCode
        let modifiers = settings.modifierKey.carbonModifier
        
        print("注册DS2热键: \(settings.modifierKey.displayName) + \(settings.triggerKey.displayName)")
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        
        // 安装事件处理器（如果还没有安装）
        if eventHandler == nil {
            let result = InstallEventHandler(GetApplicationEventTarget(), { (handler, event, userData) -> OSStatus in
                guard let userData = userData else { return OSStatus(eventNotHandledErr) }
                let hotkeyManager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
                
                var hotKeyID = EventHotKeyID()
                let getHotKeyResult = GetEventParameter(event, OSType(kEventParamDirectObject), OSType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
                
                if getHotKeyResult == noErr {
                    hotkeyManager.handleHotkey(hotKeyID)
                }
                
                return noErr
            }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
            
            if result != noErr {
                print("Install event handler failed: \(result)")
                return
            }
        }
        
        // 注册DS2热键
        let registerResult = RegisterEventHotKey(keyCode, modifiers, hotkeyId, GetApplicationEventTarget(), 0, &eventHotKeyRef)
        
        if registerResult == noErr {
            print("DS2热键注册成功")
        } else {
            print("DS2热键注册失败: \(registerResult)")
        }
    }
    
    private func registerCT2Hotkey() {
        // 定义CT2热键 ID
        let ct2HotkeyId = EventHotKeyID(signature: OSType(0x43543253), id: 2) // 'CT2S'
        
        // 从设置中获取CT2快捷键配置
        let settings = settingsManager.settings
        let keyCode = settings.ct2TriggerKey.keyCode
        let modifiers = settings.ct2ModifierKey.carbonModifier
        
        print("注册CT2热键: \(settings.ct2ModifierKey.displayName) + \(settings.ct2TriggerKey.displayName)")
        
        // 注册CT2热键
        let registerResult = RegisterEventHotKey(keyCode, modifiers, ct2HotkeyId, GetApplicationEventTarget(), 0, &ct2EventHotKeyRef)
        
        if registerResult == noErr {
            print("CT2热键注册成功")
        } else {
            print("CT2热键注册失败: \(registerResult)")
        }
    }
    
    func unregisterHotkey() {
        // 注销DS2热键
        if let eventHotKeyRef = eventHotKeyRef {
            UnregisterEventHotKey(eventHotKeyRef)
            self.eventHotKeyRef = nil
        }
        
        // 注销CT2热键
        if let ct2EventHotKeyRef = ct2EventHotKeyRef {
            UnregisterEventHotKey(ct2EventHotKeyRef)
            self.ct2EventHotKeyRef = nil
        }
        
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        
        // 停止EventTap
        stopEventTap()
    }
    
    // 暂时禁用热键（当切换器窗口显示时）
    func temporarilyDisableHotkey() {
        // 禁用DS2热键
        if let eventHotKeyRef = eventHotKeyRef {
            UnregisterEventHotKey(eventHotKeyRef)
            self.eventHotKeyRef = nil
            print("🔴 暂时禁用DS2全局热键")
        }
        
        // 禁用CT2热键
        if let ct2EventHotKeyRef = ct2EventHotKeyRef {
            UnregisterEventHotKey(ct2EventHotKeyRef)
            self.ct2EventHotKeyRef = nil
            print("🔴 暂时禁用CT2全局热键")
        }
    }
    
    // 重新启用热键（当切换器窗口关闭时）
    func reEnableHotkey() {
        let settings = settingsManager.settings
        
        // 重新启用DS2热键
        if eventHotKeyRef == nil {
            let hotkeyId = EventHotKeyID(signature: OSType(0x44455653), id: 1) // 'DEVS'
            let keyCode = settings.triggerKey.keyCode
            let modifiers = settings.modifierKey.carbonModifier
            
            let registerResult = RegisterEventHotKey(keyCode, modifiers, hotkeyId, GetApplicationEventTarget(), 0, &eventHotKeyRef)
            
            if registerResult == noErr {
                print("🟢 重新启用DS2全局热键: \(settings.modifierKey.displayName) + \(settings.triggerKey.displayName)")
            } else {
                print("❌ 重新启用DS2全局热键失败: \(registerResult)")
            }
        }
        
        // 重新启用CT2热键（如果启用）
        if settings.ct2Enabled && ct2EventHotKeyRef == nil {
            let ct2HotkeyId = EventHotKeyID(signature: OSType(0x43543253), id: 2) // 'CT2S'
            let keyCode = settings.ct2TriggerKey.keyCode
            let modifiers = settings.ct2ModifierKey.carbonModifier
            
            let registerResult = RegisterEventHotKey(keyCode, modifiers, ct2HotkeyId, GetApplicationEventTarget(), 0, &ct2EventHotKeyRef)
            
            if registerResult == noErr {
                print("🟢 重新启用CT2全局热键: \(settings.ct2ModifierKey.displayName) + \(settings.ct2TriggerKey.displayName)")
            } else {
                print("❌ 重新启用CT2全局热键失败: \(registerResult)")
            }
            
            // 如果需要EventTap，重新启动
            if needsEventTapForCT2() {
                startEventTap()
            }
        }
    }
    
    private func handleHotkey(_ hotKeyID: EventHotKeyID) {
        DispatchQueue.main.async {
            // 根据热键ID判断是DS2还是CT2
            if hotKeyID.signature == OSType(0x44455653) && hotKeyID.id == 1 { // 'DEVS', DS2
                self.windowManager.showWindowSwitcher()
            } else if hotKeyID.signature == OSType(0x43543253) && hotKeyID.id == 2 { // 'CT2S', CT2
                // 检查CT2是否启用
                if self.settingsManager.settings.ct2Enabled {
                    self.windowManager.showAppSwitcher()
                }
            }
        }
    }
    
    // MARK: - CGEventTap实现
    
    private func needsEventTapForCT2() -> Bool {
        let settings = settingsManager.settings
        // 检查是否为系统保留的热键组合
        return settings.ct2ModifierKey == .command && settings.ct2TriggerKey == .tab
    }
    
    private func startEventTap() {
        // 停止现有的EventTap
        stopEventTap()
        
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue) | (1 << CGEventType.flagsChanged.rawValue)
        
        guard let eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                guard let refcon = refcon else { return Unmanaged.passUnretained(event) }
                let hotkeyManager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
                return hotkeyManager.handleEventTap(proxy: proxy, type: type, event: event)
            },
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("❌ 无法创建EventTap，可能需要辅助功能权限")
            return
        }
        
        self.eventTap = eventTap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        print("✅ EventTap已启动，用于拦截系统Command+Tab")
    }
    
    private func stopEventTap() {
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
            print("🔴 EventTap已停止")
        }
    }
    
    private func handleEventTap(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let settings = settingsManager.settings
        
        // 检查是否是我们感兴趣的事件
        if type == .keyDown && settings.ct2Enabled {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags
            
            // 检查是否匹配CT2热键
            if keyCode == Int64(settings.ct2TriggerKey.keyCode) &&
               flags.contains(settings.ct2ModifierKey.cgEventFlags) {
                
                // 检查是否按下了Shift键
                let isShiftPressed = flags.contains(.maskShift)
                
                print("🎯 EventTap拦截到CT2热键: \(settings.ct2ModifierKey.displayName) + \(isShiftPressed ? "Shift+" : "")\(settings.ct2TriggerKey.displayName)")
                
                // 在主线程执行
                DispatchQueue.main.async {
                    if self.isShowingCT2Switcher {
                        // 如果切换器已经显示，则根据Shift键决定方向
                        if isShiftPressed {
                            self.windowManager.selectPreviousApp()
                        } else {
                            self.windowManager.selectNextApp()
                        }
                    } else {
                        // 第一次按下，显示切换器
                        self.isShowingCT2Switcher = true
                        self.windowManager.showAppSwitcher()
                    }
                }
                
                // 阻止事件继续传播到系统
                return nil
            }
        } else if type == .flagsChanged {
            // 监听修饰键释放
            let flags = event.flags
            
            if settings.ct2Enabled && isShowingCT2Switcher {
                // 检查Command键是否被释放
                if !flags.contains(settings.ct2ModifierKey.cgEventFlags) {
                    print("🔄 检测到修饰键释放，激活选中的应用")
                    
                    DispatchQueue.main.async {
                        self.isShowingCT2Switcher = false
                        self.windowManager.activateSelectedApp()
                    }
                }
            }
        }
        
        // 让其他事件正常传播
        return Unmanaged.passUnretained(event)
    }
    
    // MARK: - WindowManager状态同步
    func resetCT2SwitcherState() {
        isShowingCT2Switcher = false
    }
} 
