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
    var accessibilityCheckTimer: Timer? // Timer reference for management
    
    deinit {
        // Clean up Timer resource
        accessibilityCheckTimer?.invalidate()
        accessibilityCheckTimer = nil
        NotificationCenter.default.removeObserver(self, name: .menuBarIconVisibilityChanged, object: nil)
        Logger.log("🗑️ AppDelegate deinitialized, Timer resource released")
    }
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(menuBarIconVisibilityChanged),
            name: .menuBarIconVisibilityChanged,
            object: nil
        )
        updateStatusItemVisibility()
        
        // Initialize managers regardless of whether the status item is visible
        windowManager = WindowManager()
        hotkeyManager = HotkeyManager(windowManager: windowManager!)
        
        // Set up the bidirectional reference
        windowManager?.hotkeyManager = hotkeyManager
        
        // Hosted unit tests must not show permission alerts or intercept real keyboard input.
        guard NSClassFromString("XCTestCase") == nil else { return }

        // Request accessibility permissions
        requestAccessibilityPermission()
        
        // Register the hotkey
        hotkeyManager?.registerHotkey()
    }
    
    @objc private func menuBarIconVisibilityChanged() {
        updateStatusItemVisibility()
    }

    private func updateStatusItemVisibility() {
        if SettingsManager.shared.settings.showMenuBarIcon {
            createStatusItemIfNeeded()
        } else {
            removeStatusItemIfNeeded()
        }
    }

    private func createStatusItemIfNeeded() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem = item

        if let button = item.button {
            button.image = NSImage(systemSymbolName: "rectangle.2.swap", accessibilityDescription: LocalizedStrings.statusItemTooltip)
            button.action = #selector(statusBarButtonClicked)
            button.target = self
            button.toolTip = LocalizedStrings.statusItemTooltip
        }

        setupStatusBarMenu()
    }

    private func removeStatusItemIfNeeded() {
        guard let item = statusItem else { return }
        NSStatusBar.system.removeStatusItem(item)
        statusItem = nil
    }

    @objc func statusBarButtonClicked() {
        // Left-click now shows the menu instead of triggering the main logic
        if let menu = statusItem?.menu {
            statusItem?.popUpMenu(menu)
        }
    }
    
    private func setupStatusBarMenu() {
        let menu = NSMenu()
        
        // Preferences menu item
        let preferencesItem = NSMenuItem(title: LocalizedStrings.preferences, action: #selector(showPreferences), keyEquivalent: ",")
        preferencesItem.target = self
        menu.addItem(preferencesItem)
        
        menu.addItem(NSMenuItem.separator())
        
        // Quit App menu item
        let quitItem = NSMenuItem(title: LocalizedStrings.quitApp, action: #selector(quitApplication), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)
        
        statusItem?.menu = menu
    }
    
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        // Reopening from Applications, Finder, or Spotlight remains a settings entry
        // even when the menu bar icon is hidden. Do not force the icon back on.
        showPreferences()
        return true
    }

    @objc func showPreferences() {
        // If the preferences window already exists, bring it to the front
        if let window = preferencesWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activateCompat()
            return
        }
        
        // Create the preferences window
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
        
        // Set up cleanup for when the window is closed
        window.delegate = self
        
        preferencesWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activateCompat()
    }
    
    @objc func quitApplication() {
        NSApplication.shared.terminate(nil)
    }
    
    func requestAccessibilityPermission() {
        let accessibilityEnabled = AXIsProcessTrusted()
        
        if !accessibilityEnabled {
            Logger.log(LocalizedStrings.accessibilityPermissionRequired)
            
            // Show permission prompt dialog
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = LocalizedStrings.accessibilityPermissionTitle
                alert.informativeText = LocalizedStrings.accessibilityPermissionMessage
                alert.alertStyle = .informational
                alert.addButton(withTitle: LocalizedStrings.openSystemPreferencesButton)
                alert.addButton(withTitle: LocalizedStrings.setupLater)
                
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    // Open System Settings
                    NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
                }
            }
            
            // Periodically check the permission status
            accessibilityCheckTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] timer in
                if AXIsProcessTrusted() {
                    Logger.log(LocalizedStrings.accessibilityPermissionGranted)
                    timer.invalidate()
                    self?.accessibilityCheckTimer = nil
                    
                    // Show restart required dialog
                    DispatchQueue.main.async {
                        self?.showRestartRequiredDialog()
                    }
                    
                    // Re-register hotkey once permission is granted
                    self?.hotkeyManager?.registerHotkey()
                }
            }
        } else {
            Logger.log(LocalizedStrings.accessibilityPermissionGranted)
        }
    }
    
    // MARK: - Restart Required Dialog
    func showRestartRequiredDialog() {
        let alert = NSAlert()
        alert.messageText = LocalizedStrings.restartRequiredTitle
        alert.informativeText = LocalizedStrings.restartRequiredMessage
        alert.alertStyle = .informational
        alert.addButton(withTitle: LocalizedStrings.restartNow)
        alert.addButton(withTitle: LocalizedStrings.restartLater)
        
        let response = alert.runModal()
        if response == .alertFirstButtonReturn {
            // User chose to restart now
            restartApplication()
        }
    }
    
    // MARK: - Application Restart
    func restartApplication() {
        Logger.log("🔄 Restarting application...")
        
        // Get the path to the current application
        let appPath = Bundle.main.bundlePath
        
        // Use shell script to restart the application
        let restartScript = """
        #!/bin/bash
        sleep 1
        open "\(appPath)"
        """
        
        // Write the script to a temporary file
        let tempURL = URL(fileURLWithPath: NSTemporaryDirectory()).appendingPathComponent("restart_devswitcher2.sh")
        
        do {
            try restartScript.write(to: tempURL, atomically: true, encoding: .utf8)
            
            // Make the script executable
            let process = Process()
            process.launchPath = "/bin/chmod"
            process.arguments = ["+x", tempURL.path]
            process.launch()
            process.waitUntilExit()
            
            // Execute the restart script
            let restartProcess = Process()
            restartProcess.launchPath = "/bin/bash"
            restartProcess.arguments = [tempURL.path]
            restartProcess.launch()
            
            // Quit the current application
            NSApplication.shared.terminate(nil)
            
        } catch {
            Logger.log("❌ Failed to restart application: \(error)")
        }
    }
    
    // MARK: - NSWindowDelegate
    func windowWillClose(_ notification: Notification) {
        if let window = notification.object as? NSWindow, window == preferencesWindow {
            preferencesWindow = nil
        }
    }
}

