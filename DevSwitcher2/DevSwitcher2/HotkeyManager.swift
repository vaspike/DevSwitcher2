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
    private var ct2EventHotKeyRef: EventHotKeyRef?  // Hotkey reference for CT2
    private let windowManager: WindowManager
    private var eventHandler: EventHandlerRef?
    private let settingsManager = SettingsManager.shared
    
    // CGEventTap related properties
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isShowingCT2Switcher = false  // Tracks if the CT2 switcher is currently visible
    
    init(windowManager: WindowManager) {
        self.windowManager = windowManager
        
        // Listen for hotkey settings changes
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
        Logger.log("Hotkey settings changed, re-registering hotkeys.")
        unregisterHotkey()
        registerHotkey()
    }
    
    func registerHotkey() {
        let settings = settingsManager.settings
        
        // Register DS2 hotkey
        registerDS2Hotkey()
        
        // Register CT2 hotkey if enabled
        if settings.ct2Enabled {
            registerCT2Hotkey()
            
            // If CT2 is Command+Tab, start the EventTap to intercept system events
            if needsEventTapForCT2() {
                startEventTap()
            }
        }
    }
    
    private func registerDS2Hotkey() {
        // Define DS2 hotkey ID
        let hotkeyId = EventHotKeyID(signature: OSType(0x44455653), id: 1) // 'DEVS'
        
        // Get hotkey configuration from settings
        let settings = settingsManager.settings
        let keyCode = settings.triggerKey.keyCode
        let modifiers = settings.modifierKey.carbonModifier
        
        Logger.log("Registering DS2 hotkey: \(settings.modifierKey.displayName) + \(settings.triggerKey.displayName)")
        
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: OSType(kEventHotKeyPressed))
        
        // Install the event handler if it hasn't been installed yet
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
                Logger.log("Install event handler failed: \(result)")
                return
            }
        }
        
        // Register the DS2 hotkey
        let registerResult = RegisterEventHotKey(keyCode, modifiers, hotkeyId, GetApplicationEventTarget(), 0, &eventHotKeyRef)
        
        if registerResult == noErr {
            Logger.log("DS2 hotkey registered successfully.")
        } else {
            Logger.log("Failed to register DS2 hotkey: \(registerResult)")
        }
    }
    
    private func registerCT2Hotkey() {
        // Define CT2 hotkey ID
        let ct2HotkeyId = EventHotKeyID(signature: OSType(0x43543253), id: 2) // 'CT2S'
        
        // Get CT2 hotkey configuration from settings
        let settings = settingsManager.settings
        let keyCode = settings.ct2TriggerKey.keyCode
        let modifiers = settings.ct2ModifierKey.carbonModifier
        
        Logger.log("Registering CT2 hotkey: \(settings.ct2ModifierKey.displayName) + \(settings.ct2TriggerKey.displayName)")
        
        // Register the CT2 hotkey
        let registerResult = RegisterEventHotKey(keyCode, modifiers, ct2HotkeyId, GetApplicationEventTarget(), 0, &ct2EventHotKeyRef)
        
        if registerResult == noErr {
            Logger.log("CT2 hotkey registered successfully.")
        } else {
            Logger.log("Failed to register CT2 hotkey: \(registerResult)")
        }
    }
    
    func unregisterHotkey() {
        // Unregister DS2 hotkey
        if let eventHotKeyRef = eventHotKeyRef {
            UnregisterEventHotKey(eventHotKeyRef)
            self.eventHotKeyRef = nil
        }
        
        // Unregister CT2 hotkey
        if let ct2EventHotKeyRef = ct2EventHotKeyRef {
            UnregisterEventHotKey(ct2EventHotKeyRef)
            self.ct2EventHotKeyRef = nil
        }
        
        if let eventHandler = eventHandler {
            RemoveEventHandler(eventHandler)
            self.eventHandler = nil
        }
        
        // Stop the EventTap
        stopEventTap()
    }
    
    // Temporarily disable the hotkey (e.g., when the switcher window is visible)
    func temporarilyDisableHotkey() {
        // Disable DS2 hotkey
        if let eventHotKeyRef = eventHotKeyRef {
            UnregisterEventHotKey(eventHotKeyRef)
            self.eventHotKeyRef = nil
            Logger.log("🔴 Temporarily disabled DS2 global hotkey")
        }
        
        // Disable CT2 hotkey
        if let ct2EventHotKeyRef = ct2EventHotKeyRef {
            UnregisterEventHotKey(ct2EventHotKeyRef)
            self.ct2EventHotKeyRef = nil
            Logger.log("🔴 Temporarily disabled CT2 global hotkey")
        }
    }
    
    // Re-enable the hotkey (e.g., when the switcher window is closed)
    func reEnableHotkey() {
        let settings = settingsManager.settings
        
        // Re-enable DS2 hotkey
        if eventHotKeyRef == nil {
            let hotkeyId = EventHotKeyID(signature: OSType(0x44455653), id: 1) // 'DEVS'
            let keyCode = settings.triggerKey.keyCode
            let modifiers = settings.modifierKey.carbonModifier
            
            let registerResult = RegisterEventHotKey(keyCode, modifiers, hotkeyId, GetApplicationEventTarget(), 0, &eventHotKeyRef)
            
            if registerResult == noErr {
                Logger.log("🟢 Re-enabled DS2 global hotkey: \(settings.modifierKey.displayName) + \(settings.triggerKey.displayName)")
            } else {
                Logger.log("❌ Failed to re-enable DS2 global hotkey: \(registerResult)")
            }
        }
        
        // Re-enable CT2 hotkey if enabled
        if settings.ct2Enabled && ct2EventHotKeyRef == nil {
            let ct2HotkeyId = EventHotKeyID(signature: OSType(0x43543253), id: 2) // 'CT2S'
            let keyCode = settings.ct2TriggerKey.keyCode
            let modifiers = settings.ct2ModifierKey.carbonModifier
            
            let registerResult = RegisterEventHotKey(keyCode, modifiers, ct2HotkeyId, GetApplicationEventTarget(), 0, &ct2EventHotKeyRef)
            
            if registerResult == noErr {
                Logger.log("🟢 Re-enabled CT2 global hotkey: \(settings.ct2ModifierKey.displayName) + \(settings.ct2TriggerKey.displayName)")
            } else {
                Logger.log("❌ Failed to re-enable CT2 global hotkey: \(registerResult)")
            }
            
            // Restart EventTap if needed
            if needsEventTapForCT2() {
                startEventTap()
            }
        }
    }
    
    private func handleHotkey(_ hotKeyID: EventHotKeyID) {
        DispatchQueue.main.async {
            // Determine which hotkey was pressed based on its ID
            if hotKeyID.signature == OSType(0x44455653) && hotKeyID.id == 1 { // 'DEVS', DS2
                self.windowManager.showWindowSwitcher()
            } else if hotKeyID.signature == OSType(0x43543253) && hotKeyID.id == 2 { // 'CT2S', CT2
                // Check if CT2 is enabled
                if self.settingsManager.settings.ct2Enabled {
                    self.windowManager.showAppSwitcher()
                }
            }
        }
    }
    
    // MARK: - CGEventTap Implementation
    
    private func needsEventTapForCT2() -> Bool {
        let settings = settingsManager.settings
        // Check if the hotkey combination is reserved by the system
        return settings.ct2ModifierKey == .command && settings.ct2TriggerKey == .tab
    }
    
    private func startEventTap() {
        // Stop any existing EventTap
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
            Logger.log("❌ Failed to create EventTap, Accessibility permissions may be required.")
            return
        }
        
        self.eventTap = eventTap
        self.runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, eventTap, 0)
        
        CFRunLoopAddSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
        CGEvent.tapEnable(tap: eventTap, enable: true)
        
        Logger.log("✅ EventTap started to intercept system Command+Tab.")
    }
    
    private func stopEventTap() {
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .commonModes)
            self.runLoopSource = nil
        }
        
        if let eventTap = eventTap {
            CGEvent.tapEnable(tap: eventTap, enable: false)
            self.eventTap = nil
            Logger.log("🔴 EventTap stopped.")
        }
    }
    
    private func handleEventTap(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        let settings = settingsManager.settings
        
        // Check if it's an event we are interested in
        if type == .keyDown && settings.ct2Enabled {
            let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
            let flags = event.flags
            
            // Check if it matches the CT2 hotkey
            if keyCode == Int64(settings.ct2TriggerKey.keyCode) &&
               flags.contains(settings.ct2ModifierKey.cgEventFlags) {
                
                // Check if the Shift key is also pressed
                let isShiftPressed = flags.contains(.maskShift)
                
                Logger.log("🎯 EventTap intercepted CT2 hotkey: \(settings.ct2ModifierKey.displayName) + \(isShiftPressed ? "Shift+" : "")\(settings.ct2TriggerKey.displayName)")
                
                // Execute on the main thread
                DispatchQueue.main.async {
                    if self.isShowingCT2Switcher {
                        // If the switcher is already visible, navigate based on the Shift key
                        if isShiftPressed {
                            self.windowManager.selectPreviousApp()
                        } else {
                            self.windowManager.selectNextApp()
                        }
                    } else {
                        // First press, show the switcher
                        self.isShowingCT2Switcher = true
                        self.windowManager.showAppSwitcher()
                    }
                }
                
                // Suppress the event from propagating to the system
                return nil
            }
        } else if type == .flagsChanged {
            // Listen for modifier key release
            let flags = event.flags
            
            if settings.ct2Enabled && isShowingCT2Switcher {
                // Check if the Command key was released
                if !flags.contains(settings.ct2ModifierKey.cgEventFlags) {
                    Logger.log("🔄 Modifier key released, activating selected app.")
                    
                    DispatchQueue.main.async {
                        self.isShowingCT2Switcher = false
                        self.windowManager.activateSelectedApp()
                    }
                }
            }
        }
        
        // Allow other events to pass through normally
        return Unmanaged.passUnretained(event)
    }
    
    // MARK: - WindowManager State Sync
    func resetCT2SwitcherState() {
        isShowingCT2Switcher = false
    }
}
 
