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
    private let windowManager: WindowManager
    private var eventHandler: EventHandlerRef?
    
    init(windowManager: WindowManager) {
        self.windowManager = windowManager
    }
    
    deinit {
        unregisterHotkey()
    }
    
    func registerHotkey() {
        // 定义热键 ID
        let hotkeyId = EventHotKeyID(signature: OSType(0x44455653), id: 1) // 'DEVS'
        
        // 注册 Command + ` 热键
        let keyCode = UInt32(kVK_ANSI_Grave) // ` 键
        let modifiers = UInt32(cmdKey)
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        
        // 安装事件处理器
        let result = InstallEventHandler(GetApplicationEventTarget(), { (handler, event, userData) -> OSStatus in
            guard let userData = userData else { return OSStatus(eventNotHandledErr) }
            let hotkeyManager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
            
            var hotKeyID = EventHotKeyID()
            let getHotKeyResult = GetEventParameter(event, OSType(kEventParamDirectObject), OSType(typeEventHotKeyID), nil, MemoryLayout<EventHotKeyID>.size, nil, &hotKeyID)
            
            if getHotKeyResult == noErr {
                hotkeyManager.handleHotkey()
            }
            
            return noErr
        }, 1, &eventType, Unmanaged.passUnretained(self).toOpaque(), &eventHandler)
        
        if result == noErr {
            // 注册热键
            let registerResult = RegisterEventHotKey(keyCode, modifiers, hotkeyId, GetApplicationEventTarget(), 0, &eventHotKeyRef)
            
            if registerResult == noErr {
                print(LocalizedStrings.hotkeyRegistrationSuccess)
            } else {
                print(LocalizedStrings.hotkeyRegistrationFailed + ": \(registerResult)")
            }
        } else {
            print("Install event handler failed: \(result)")
        }
    }
    
    func unregisterHotkey() {
        if let eventHotKeyRef = eventHotKeyRef {
            UnregisterEventHotKey(eventHotKeyRef)
            self.eventHotKeyRef = nil
        }
        
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
    }
    
    // 暂时禁用热键（当DS2窗口显示时）
    func temporarilyDisableHotkey() {
        if let eventHotKeyRef = eventHotKeyRef {
            UnregisterEventHotKey(eventHotKeyRef)
            self.eventHotKeyRef = nil
            print("🔴 暂时禁用全局热键")
        }
    }
    
    // 重新启用热键（当DS2窗口关闭时）
    func reEnableHotkey() {
        guard eventHotKeyRef == nil else { return } // 如果已经注册了就不重复注册
        
        let hotkeyId = EventHotKeyID(signature: OSType(0x44455653), id: 1) // 'DEVS'
        let keyCode = UInt32(kVK_ANSI_Grave) // ` 键
        let modifiers = UInt32(cmdKey)
        
        let registerResult = RegisterEventHotKey(keyCode, modifiers, hotkeyId, GetApplicationEventTarget(), 0, &eventHotKeyRef)
        
        if registerResult == noErr {
            print("🟢 重新启用全局热键")
        } else {
            print("❌ 重新启用全局热键失败: \(registerResult)")
        }
    }
    
    private func handleHotkey() {
        DispatchQueue.main.async {
            self.windowManager.showWindowSwitcher()
        }
    }
} 
