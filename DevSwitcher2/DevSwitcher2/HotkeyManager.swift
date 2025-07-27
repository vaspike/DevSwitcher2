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
} 
