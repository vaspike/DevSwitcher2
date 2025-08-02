//
//  PreferencesView.swift
//  DevSwitcher2
//
//  Created by river on 2025-07-26.
//

import SwiftUI

struct PreferencesView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var languageManager = LanguageManager.shared
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // 顶部标题栏
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DevSwitcher2")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(LocalizedStrings.preferencesSubtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Tab selector
                HStack(spacing: 4) {
                    TabButton(title: LocalizedStrings.settingsTabTitle, isSelected: selectedTab == 0) {
                        selectedTab = 0
                    }
                    
                    TabButton(title: LocalizedStrings.aboutTabTitle, isSelected: selectedTab == 1) {
                        selectedTab = 1
                    }
                }
                .padding(4)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 24)
            .padding(.top, 20)
            .padding(.bottom, 16)
            .background(.ultraThinMaterial)
            
            // Content area
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    if selectedTab == 0 {
                        CoreSettingsView()
                    } else {
                        AboutView()
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 800, height: 600)
        .background(Color(NSColor.windowBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            // Force refresh view when language changes
            // SwiftUI will automatically recalculate LocalizedStrings values
        }
    }
}

struct TabButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(isSelected ? .white : .primary)
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(isSelected ? Color.accentColor : Color.clear)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - General Settings Section
struct GeneralSettingsSection: View {
    @ObservedObject var settingsManager: SettingsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(LocalizedStrings.generalSettingsSectionTitle)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(LocalizedStrings.launchAtStartup)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        
                        Text(LocalizedStrings.launchAtStartupDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Toggle("", isOn: Binding(
                        get: { settingsManager.settings.launchAtStartup },
                        set: { newValue in
                            settingsManager.updateLaunchAtStartup(newValue)
                        }
                    ))
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                }
            }
            .padding(20)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.gray.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Language Settings Section
struct LanguageSettingsSection: View {
    @ObservedObject var languageManager: LanguageManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(LocalizedStrings.languageSectionTitle)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Picker(LocalizedStrings.language, selection: $languageManager.currentLanguage) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 150)
                .onChange(of: languageManager.currentLanguage) { newLanguage in
                    languageManager.setLanguage(newLanguage)
                }
            }
            
            HStack {
                Text(LocalizedStrings.languageRestartNote)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Button(LocalizedStrings.languageRestartNowButton) {
                    restartApplication()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(.horizontal, 32)
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.accentColor.opacity(0.1), lineWidth: 1)
        )
    }
    
    // MARK: - Private Methods
    private func restartApplication() {
        Logger.log("🔄 Restarting application from preferences...")
        
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
            
            // Terminate current application
            NSApplication.shared.terminate(nil)
            
        } catch {
            Logger.log("❌ Failed to restart application: \(error)")
        }
    }
}

// MARK: - DS2 Hotkey Settings Section
struct DS2HotkeySettingsSection: View {
    @Binding var selectedModifier: ModifierKey
    @Binding var selectedTrigger: TriggerKey
    let onApply: () -> Void
    let onReset: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(LocalizedStrings.ds2HotkeySectionTitle)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(LocalizedStrings.hotkeyApply) {
                        onApply()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    
                    Button(LocalizedStrings.hotkeyReset) {
                        onReset()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
            
            VStack(alignment: .leading, spacing: 12) {
                Text(LocalizedStrings.ds2HotkeyDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(LocalizedStrings.modifierKeyLabel)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Picker(LocalizedStrings.modifierKey, selection: $selectedModifier) {
                            ForEach(ModifierKey.allCases, id: \.self) { key in
                                Text(key.displayName).tag(key)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: .infinity)
                    }
                    
                    Text("+")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .padding(.top, 16)
                    
                    VStack(alignment: .leading, spacing: 6) {
                        Text(LocalizedStrings.triggerKeyLabel)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        Picker(LocalizedStrings.triggerKey, selection: $selectedTrigger) {
                            ForEach(TriggerKey.allCases, id: \.self) { key in
                                Text(key.displayName).tag(key)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: .infinity)
                    }
                }
                
                HStack {
                    Image(systemName: "keyboard")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                    Text(LocalizedStrings.currentHotkeyDisplay(selectedModifier.displayName, selectedTrigger.displayName))
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.accentColor)
                }
                .padding(.top, 4)
            }
            .padding(20)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.blue.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - CT2 Hotkey Settings Section
struct CT2HotkeySettingsSection: View {
    @Binding var ct2Enabled: Bool
    @Binding var selectedModifier: ModifierKey
    @Binding var selectedTrigger: TriggerKey
    let onApply: () -> Void
    let onReset: () -> Void
    let settingsManager: SettingsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(LocalizedStrings.ct2HotkeySectionTitle)
                    .font(.title3)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Toggle(LocalizedStrings.ct2EnableToggle, isOn: $ct2Enabled)
                    .toggleStyle(SwitchToggleStyle(tint: .green))
                    .onChange(of: ct2Enabled) { newValue in
                        settingsManager.updateCT2Enabled(newValue)
                        NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
                    }
            }
            
            if ct2Enabled {
                VStack(alignment: .leading, spacing: 12) {
                    Text(LocalizedStrings.ct2HotkeyDescription)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        HStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(LocalizedStrings.modifierKeyLabel)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                Picker("CT2" + LocalizedStrings.modifierKey, selection: $selectedModifier) {
                                    ForEach(ModifierKey.allCases, id: \.self) { key in
                                        Text(key.displayName).tag(key)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .frame(maxWidth: .infinity)
                            }
                            
                            Text("+")
                                .font(.title2)
                                .foregroundColor(.secondary)
                                .padding(.top, 16)
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(LocalizedStrings.triggerKeyLabel)
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(.secondary)
                                
                                Picker("CT2" + LocalizedStrings.triggerKey, selection: $selectedTrigger) {
                                    ForEach(TriggerKey.allCases, id: \.self) { key in
                                        Text(key.displayName).tag(key)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .frame(maxWidth: .infinity)
                            }
                        }
                        
                        Spacer()
                        
                        VStack(spacing: 8) {
                            Button(LocalizedStrings.hotkeyApply) {
                                onApply()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            
                            Button(LocalizedStrings.hotkeyReset) {
                                onReset()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                    
                    HStack {
                        Image(systemName: "keyboard")
                            .font(.caption)
                            .foregroundColor(.green)
                        Text(LocalizedStrings.currentHotkeyDisplay(selectedModifier.displayName, selectedTrigger.displayName))
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                    .padding(.top, 4)
                }
                .padding(20)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            } else {
                Text(LocalizedStrings.ct2DisabledMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .italic()
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
        }
        .padding(20)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.green.opacity(0.1), lineWidth: 1)
        )
    }
}

// MARK: - Core Settings View
struct CoreSettingsView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var languageManager = LanguageManager.shared
    @State private var selectedModifier: ModifierKey
    @State private var selectedTrigger: TriggerKey
    @State private var showingHotkeyWarning = false
    
    // CT2 settings state
    @State private var ct2Enabled: Bool
    @State private var selectedCT2Modifier: ModifierKey
    @State private var selectedCT2Trigger: TriggerKey
    
    init() {
        let settings = SettingsManager.shared.settings
        _selectedModifier = State(initialValue: settings.modifierKey)
        _selectedTrigger = State(initialValue: settings.triggerKey)
        _ct2Enabled = State(initialValue: settings.ct2Enabled)
        _selectedCT2Modifier = State(initialValue: settings.ct2ModifierKey)
        _selectedCT2Trigger = State(initialValue: settings.ct2TriggerKey)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 32) {
            LanguageSettingsSection(languageManager: languageManager)
            
            GeneralSettingsSection(settingsManager: settingsManager)
            
            DS2HotkeySettingsSection(
                selectedModifier: $selectedModifier,
                selectedTrigger: $selectedTrigger,
                onApply: applyDS2HotkeySettings,
                onReset: resetDS2HotkeySettings
            )
            
            CT2HotkeySettingsSection(
                ct2Enabled: $ct2Enabled,
                selectedModifier: $selectedCT2Modifier,
                selectedTrigger: $selectedCT2Trigger,
                onApply: applyCT2HotkeySettings,
                onReset: resetCT2HotkeySettings,
                settingsManager: settingsManager
            )
            
            // 窗口标题配置
            WindowTitleConfigView()
        }
        .alert(LocalizedStrings.hotkeyConflictTitle, isPresented: $showingHotkeyWarning) {
            Button(LocalizedStrings.confirm, role: .cancel) { }
        } message: {
            Text(LocalizedStrings.hotkeyConflictMessage)
        }
    }
    
    // DS2 hotkey setting methods
    private func applyDS2HotkeySettings() {
        settingsManager.updateHotkey(modifier: selectedModifier, trigger: selectedTrigger)
        // Notify system to re-register hotkeys
        NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
    }
    
    private func resetDS2HotkeySettings() {
        selectedModifier = .command
        selectedTrigger = .grave
        applyDS2HotkeySettings()
    }
    
    // CT2 hotkey setting methods
    private func applyCT2HotkeySettings() {
        settingsManager.updateCT2Enabled(ct2Enabled)
        settingsManager.updateCT2Hotkey(modifier: selectedCT2Modifier, trigger: selectedCT2Trigger)
        // Notify system to re-register hotkeys
        NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
    }
    
    private func resetCT2HotkeySettings() {
        ct2Enabled = true
        selectedCT2Modifier = .command
        selectedCT2Trigger = .tab
        applyCT2HotkeySettings()
    }
}

// MARK: - Window Title Header View
struct WindowTitleHeaderView: View {
    var body: some View {
        HStack {
            Text(LocalizedStrings.windowTitleSectionTitle)
                .font(.title3)
                .fontWeight(.semibold)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.top, 20)
    }
}

// MARK: - Window Title Settings Content View
struct WindowTitleSettingsContentView: View {
    @Binding var selectedDefaultStrategy: TitleExtractionStrategy
    @Binding var defaultCustomSeparator: String
    @ObservedObject var configManager: ConfigurationExportImportManager
    @ObservedObject var settingsManager: SettingsManager
    @Binding var showingAddAppDialog: Bool
    let onImport: () -> Void
    let onExport: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            DefaultStrategySection(
                selectedDefaultStrategy: $selectedDefaultStrategy,
                defaultCustomSeparator: $defaultCustomSeparator,
                settingsManager: settingsManager
            )
            
            AppConfigsSection(
                configManager: configManager,
                settingsManager: settingsManager,
                showingAddAppDialog: $showingAddAppDialog,
                onImport: onImport,
                onExport: onExport
            )
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 20)
    }
}

// MARK: - Default Strategy Section
struct DefaultStrategySection: View {
    @Binding var selectedDefaultStrategy: TitleExtractionStrategy
    @Binding var defaultCustomSeparator: String
    @ObservedObject var settingsManager: SettingsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(LocalizedStrings.defaultStrategyDescription)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                Button(LocalizedStrings.defaultStrategyApply) {
                    settingsManager.updateDefaultTitleStrategy(selectedDefaultStrategy, customSeparator: defaultCustomSeparator)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(LocalizedStrings.extractionStrategyLabel)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    
                    Picker(LocalizedStrings.defaultExtractionStrategy, selection: $selectedDefaultStrategy) {
                        ForEach(TitleExtractionStrategy.allCases, id: \.self) { strategy in
                            Text(strategy.displayName).tag(strategy)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity)
                }
                
                if selectedDefaultStrategy != .fullTitle {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(LocalizedStrings.customSeparatorLabel)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.secondary)
                        
                        TextField(LocalizedStrings.separatorExample, text: $defaultCustomSeparator)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(maxWidth: .infinity)
                    }
                }
            }
        }
        .padding(20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - App Configs Section
struct AppConfigsSection: View {
    @ObservedObject var configManager: ConfigurationExportImportManager
    @ObservedObject var settingsManager: SettingsManager
    @Binding var showingAddAppDialog: Bool
    let onImport: () -> Void
    let onExport: () -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text(LocalizedStrings.appConfigsDescription)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Spacer()
                
                HStack(spacing: 8) {
                    Button(LocalizedStrings.appConfigImport) {
                        onImport()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(configManager.isProcessing)
                    
                    Button(LocalizedStrings.appConfigExport) {
                        onExport()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .disabled(settingsManager.settings.appTitleConfigs.isEmpty || configManager.isProcessing)
                    
                    Button(LocalizedStrings.appConfigAdd) {
                        showingAddAppDialog = true
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
            }
            
            if settingsManager.settings.appTitleConfigs.isEmpty {
                VStack {
                    Image(systemName: "tray")
                        .font(.title)
                        .foregroundColor(.secondary)
                    Text(LocalizedStrings.noAppConfigsMessage)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(30)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(settingsManager.settings.appTitleConfigs.values), id: \.bundleId) { config in
                        AppConfigRowView(config: config) {
                            settingsManager.removeAppTitleConfig(for: config.bundleId)
                        }
                    }
                }
            }
        }
        .padding(20)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Window Title Configuration View
struct WindowTitleConfigView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var configManager = ConfigurationExportImportManager()
    @State private var selectedDefaultStrategy: TitleExtractionStrategy
    @State private var defaultCustomSeparator: String
    @State private var showingAddAppDialog = false
    @State private var newAppBundleId = ""
    @State private var newAppName = ""
    @State private var newAppStrategy: TitleExtractionStrategy = .beforeFirstSeparator
    @State private var newAppCustomSeparator = " - "
    
    // 导出/导入状态
    @State private var showingImportResult = false
    @State private var importResultMessage = ""
    @State private var importResultTitle = ""
    @State private var importResultIsSuccess = false
    
    init() {
        let settings = SettingsManager.shared.settings
        _selectedDefaultStrategy = State(initialValue: settings.defaultTitleStrategy)
        _defaultCustomSeparator = State(initialValue: settings.defaultCustomSeparator)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            WindowTitleHeaderView()
            WindowTitleSettingsContentView(
                selectedDefaultStrategy: $selectedDefaultStrategy,
                defaultCustomSeparator: $defaultCustomSeparator,
                configManager: configManager,
                settingsManager: settingsManager,
                showingAddAppDialog: $showingAddAppDialog,
                onImport: importConfiguration,
                onExport: exportConfiguration
            )
        }
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color.purple.opacity(0.1), lineWidth: 1)
        )
        .sheet(isPresented: $showingAddAppDialog) {
            AddAppConfigView(
                bundleId: $newAppBundleId,
                appName: $newAppName,
                strategy: $newAppStrategy,
                customSeparator: $newAppCustomSeparator
            ) {
                let config = AppTitleConfig(
                    bundleId: newAppBundleId,
                    appName: newAppName,
                    strategy: newAppStrategy,
                    customSeparator: newAppStrategy == .fullTitle ? nil : (newAppCustomSeparator.isEmpty ? getDefaultSeparator(for: newAppStrategy) : newAppCustomSeparator)
                )
                settingsManager.setAppTitleConfig(config)
                showingAddAppDialog = false
                // Reset form
                newAppBundleId = ""
                newAppName = ""
                newAppStrategy = .beforeFirstSeparator
                newAppCustomSeparator = " - "
            }
        }
        .alert(importResultTitle, isPresented: $showingImportResult) {
            Button(LocalizedStrings.confirm, role: .cancel) { }
        } message: {
            Text(importResultMessage)
        }
    }
    
    // MARK: - 导出/导入方法
    
    private func exportConfiguration() {
        Task { @MainActor in
            switch configManager.saveConfigurationToFile() {
            case .success(let url):
                showImportResult(
                    title: LocalizedStrings.exportSuccess,
                    message: LocalizedStrings.exportSuccessMessage(url.lastPathComponent),
                    isSuccess: true
                )
            case .failure(let error):
                if case ConfigurationError.userCancelled = error {
                    return // 用户取消，不显示错误
                }
                showImportResult(
                    title: LocalizedStrings.exportFailed,
                    message: error.localizedDescription,
                    isSuccess: false
                )
            }
        }
    }
    
    private func importConfiguration() {
        Task { @MainActor in
            switch configManager.importConfigurationFromFile() {
            case .success(let result):
                if result.isEmpty {
                    showImportResult(
                        title: LocalizedStrings.importNoData,
                        message: LocalizedStrings.importNoDataMessage,
                        isSuccess: false
                    )
                } else if result.isSuccess {
                    showImportResult(
                        title: LocalizedStrings.importSuccess,
                        message: LocalizedStrings.importSuccessMessage(result.newConfigs, result.updatedConfigs),
                        isSuccess: true
                    )
                } else {
                    let errorMsg = result.errors.joined(separator: "\n")
                    showImportResult(
                        title: LocalizedStrings.importPartialSuccess,
                        message: LocalizedStrings.importPartialSuccessMessage(result.totalImported) + "\n\n" + errorMsg,
                        isSuccess: false
                    )
                }
            case .failure(let error):
                if case ConfigurationError.userCancelled = error {
                    return // 用户取消，不显示错误
                }
                showImportResult(
                    title: LocalizedStrings.importFailed,
                    message: error.localizedDescription,
                    isSuccess: false
                )
            }
        }
    }
    
    private func showImportResult(title: String, message: String, isSuccess: Bool) {
        importResultTitle = title
        importResultMessage = message
        importResultIsSuccess = isSuccess
        showingImportResult = true
    }
    
    // 为不同策略提供默认分隔符
    private func getDefaultSeparator(for strategy: TitleExtractionStrategy) -> String {
        switch strategy {
        case .firstPart, .lastPart:
            return " - "
        case .beforeFirstSeparator:
            return " — "
        case .afterLastSeparator:
            return " - "
        case .fullTitle:
            return ""
        }
    }
}

// MARK: - Preview Section View
struct PreviewSectionView: View {
    let windowTitles: [String]
    @Binding var selectedWindowTitle: String
    let strategy: TitleExtractionStrategy
    let customSeparator: String
    let isLoading: Bool
    let errorMessage: String
    let settingsManager: SettingsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStrings.previewWindowTitles)
                .font(.subheadline)
                .fontWeight(.medium)
            
            if isLoading {
                HStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text(LocalizedStrings.loading)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if !errorMessage.isEmpty {
                Text(errorMessage)
                    .font(.caption)
                    .foregroundColor(.red)
                    .italic()
            } else if windowTitles.isEmpty {
                Text(LocalizedStrings.noWindowsFound)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .italic()
            } else {
                // 窗口标题选择器
                VStack(alignment: .leading, spacing: 8) {
                    Picker(LocalizedStrings.selectWindowTitle, selection: $selectedWindowTitle) {
                        ForEach(windowTitles, id: \.self) { title in
                            Text(title).tag(title)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(maxWidth: .infinity, alignment: .leading)
                    
                    // 可复制的标题展示
                    if !selectedWindowTitle.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(LocalizedStrings.selectedTitle + ":")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            ScrollView(.horizontal, showsIndicators: false) {
                                Text(selectedWindowTitle)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 6))
                                    .help(LocalizedStrings.copyTitle)
                            }
                            .frame(height: 44)
                        }
                        
                        // 实时提取结果预览
                        VStack(alignment: .leading, spacing: 12) {
                            // 提取结果标题和调试信息分开显示
                            Text(LocalizedStrings.extractionResult)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            // 显示当前使用的策略和分隔符
                            HStack(spacing: 20) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(LocalizedStrings.currentStrategy): \(strategy.displayName)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    if strategy != .fullTitle {
                                        let currentSeparator = customSeparator.isEmpty ? getDefaultSeparator(for: strategy) : customSeparator
                                        Text("\(LocalizedStrings.currentSeparator): \"\(currentSeparator)\"")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                Spacer()
                            }
                            .padding(8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
                            
                            // 提取结果显示
                            HStack {
                                Text(getExtractionResult())
                                    .font(.system(.title3, design: .monospaced))
                                    .fontWeight(.semibold)
                                    .foregroundColor(.accentColor)
                                    .textSelection(.enabled)
                                    .padding(12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.accentColor.opacity(0.3), lineWidth: 2)
                                    )
                            }
                        }
                    }
                }
            }
        }
        .padding()
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        .onChange(of: strategy) { _ in
            // 策略改变时触发重新计算
        }
        .onChange(of: customSeparator) { _ in
            // 分隔符改变时触发重新计算
        }
    }
    
    // 获取实时提取结果
    private func getExtractionResult() -> String {
        guard !selectedWindowTitle.isEmpty else { return "" }
        
        let separator = strategy == .fullTitle ? nil : (customSeparator.isEmpty ? getDefaultSeparator(for: strategy) : customSeparator)
        
        return settingsManager.extractProjectName(
            from: selectedWindowTitle,
            using: strategy,
            customSeparator: separator
        )
    }
    
    // 为不同策略提供默认分隔符
    private func getDefaultSeparator(for strategy: TitleExtractionStrategy) -> String {
        switch strategy {
        case .firstPart, .lastPart:
            return " - "
        case .beforeFirstSeparator:
            return " — "
        case .afterLastSeparator:
            return " - "
        case .fullTitle:
            return ""
        }
    }
}

struct AppConfigRowView: View {
    let config: AppTitleConfig
    let onDelete: () -> Void
    
    var body: some View {
        HStack(spacing: 16) {
            // 应用信息
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text(config.appName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    // 策略标签
                    Text(config.strategy.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.accentColor, in: RoundedRectangle(cornerRadius: 4))
                }
                
                Text(config.bundleId)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                if let separator = config.customSeparator, !separator.isEmpty, config.strategy != .fullTitle {
                    HStack(spacing: 4) {
                        Image(systemName: "scissors")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(LocalizedStrings.separatorLabel(separator))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            // 删除按钮
            Button {
                onDelete()
            } label: {
                Image(systemName: "trash")
                    .font(.caption)
                    .foregroundColor(.red)
            }
            .buttonStyle(.borderless)
            .help(LocalizedStrings.deleteConfigTooltip)
        }
        .padding(16)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.primary.opacity(0.05), lineWidth: 1)
        )
    }
}

struct AddAppConfigView: View {
    @Binding var bundleId: String
    @Binding var appName: String
    @Binding var strategy: TitleExtractionStrategy
    @Binding var customSeparator: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    // 预览功能状态
    @State private var windowTitles: [String] = []
    @State private var selectedWindowTitle: String = ""
    @State private var isLoadingPreview = false
    @State private var previewErrorMessage: String = ""
    @State private var showingPreview = false
    @StateObject private var windowManager = WindowManager()
    @StateObject private var settingsManager = SettingsManager.shared
    
    // 应用选择状态
    @State private var selectedApp: InstalledAppInfo? = nil
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 标题区域
            HStack {
                Text(LocalizedStrings.addAppConfig)
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.accentColor.opacity(0.1), lineWidth: 1),
                alignment: .top
            )
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 应用选择区域
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(LocalizedStrings.appSelectionSection)
                                .font(.headline)
                                .fontWeight(.medium)
                        }
                        
                        AppSelectionView(
                            selectedApp: $selectedApp,
                            bundleId: $bundleId,
                            appName: $appName
                        )
                    }
                    .padding(20)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.blue.opacity(0.1), lineWidth: 1)
                    )
                    
                    // 基本信息区域
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(LocalizedStrings.basicInfoSection)
                                .font(.headline)
                                .fontWeight(.medium)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(LocalizedStrings.bundleId)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                HStack(spacing: 12) {
                                    TextField(LocalizedStrings.bundleIdPlaceholder, text: $bundleId)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                    
                                    Button(LocalizedStrings.preview) {
                                        loadPreview()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .disabled(bundleId.isEmpty || isLoadingPreview)
                                    .frame(minWidth: 120)
                                    .controlSize(.regular)
                                }
                            }
                            
                            VStack(alignment: .leading, spacing: 6) {
                                Text(LocalizedStrings.appName)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                TextField(LocalizedStrings.appNamePlaceholder, text: $appName)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                            }
                        }
                    }
                    .padding(20)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.green.opacity(0.1), lineWidth: 1)
                    )
                    
                    // 提取策略区域
                    VStack(alignment: .leading, spacing: 16) {
                        HStack {
                            Text(LocalizedStrings.extractionStrategySection)
                                .font(.headline)
                                .fontWeight(.medium)
                        }
                        
                        VStack(alignment: .leading, spacing: 12) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text(LocalizedStrings.extractionStrategy)
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                
                                Picker(LocalizedStrings.strategy, selection: $strategy) {
                                    ForEach(TitleExtractionStrategy.allCases, id: \.self) { strategy in
                                        Text(strategy.displayName).tag(strategy)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .onChange(of: strategy) { newStrategy in
                                    // 当策略改变时，自动设置默认分隔符
                                    if customSeparator.isEmpty || customSeparator == " - " {
                                        customSeparator = getDefaultSeparator(for: newStrategy)
                                    }
                                }
                            }
                            
                            // 为所有策略都显示分隔符设置（除了 fullTitle）
                            if strategy != .fullTitle {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text(LocalizedStrings.customSeparator)
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.primary)
                                    
                                    TextField(getDefaultSeparatorPlaceholder(for: strategy), text: $customSeparator)
                                        .textFieldStyle(RoundedBorderTextFieldStyle())
                                        .help(getSeparatorHelpText(for: strategy))
                                }
                            }
                        }
                    }
                    .padding(20)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.orange.opacity(0.1), lineWidth: 1)
                    )
                    
                    // 预览区域
                    if showingPreview {
                        VStack(alignment: .leading, spacing: 16) {
                            HStack {
                                Text(LocalizedStrings.previewResultsSection)
                                    .font(.headline)
                                    .fontWeight(.medium)
                            }
                            
                            PreviewSectionView(
                                windowTitles: windowTitles,
                                selectedWindowTitle: $selectedWindowTitle,
                                strategy: strategy,
                                customSeparator: customSeparator,
                                isLoading: isLoadingPreview,
                                errorMessage: previewErrorMessage,
                                settingsManager: settingsManager
                            )
                        }
                        .padding(20)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.purple.opacity(0.1), lineWidth: 1)
                        )
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            
            // 底部操作按钮
            HStack {
                Button(LocalizedStrings.cancel) {
                    dismiss()
                }
                .buttonStyle(.bordered)
                .controlSize(.regular)
                
                Spacer()
                
                Button(LocalizedStrings.save) {
                    onSave()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
                .disabled(bundleId.isEmpty || appName.isEmpty)
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.secondary.opacity(0.1), lineWidth: 1),
                alignment: .bottom
            )
        }
        .frame(width: 650, height: showingPreview ? 800 : 620)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .stroke(Color.primary.opacity(0.1), lineWidth: 1)
        )
    }
    
    // 预览功能方法
    private func loadPreview() {
        guard !bundleId.isEmpty else { return }
        
        isLoadingPreview = true
        previewErrorMessage = ""
        showingPreview = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let titles = windowManager.getWindowTitlesForPreview(bundleId)
            
            DispatchQueue.main.async {
                isLoadingPreview = false
                
                if titles.isEmpty {
                    previewErrorMessage = LocalizedStrings.appNotRunning
                    windowTitles = []
                    selectedWindowTitle = ""
                } else {
                    windowTitles = titles
                    selectedWindowTitle = titles.first ?? ""
                    previewErrorMessage = ""
                }
            }
        }
    }
    
    // 为不同策略提供默认分隔符占位符
    private func getDefaultSeparatorPlaceholder(for strategy: TitleExtractionStrategy) -> String {
        switch strategy {
        case .firstPart, .lastPart:
            return LocalizedStrings.separatorPlaceholderFirstLastPart
        case .beforeFirstSeparator:
            return LocalizedStrings.separatorPlaceholderBeforeFirst
        case .afterLastSeparator:
            return LocalizedStrings.separatorPlaceholderAfterLast

        case .fullTitle:
            return ""
        }
    }
    
    // 为不同策略提供帮助文本
    private func getSeparatorHelpText(for strategy: TitleExtractionStrategy) -> String {
        switch strategy {
        case .firstPart:
            return LocalizedStrings.separatorHelpFirstPart
        case .lastPart:
            return LocalizedStrings.separatorHelpLastPart
        case .beforeFirstSeparator:
            return LocalizedStrings.separatorHelpBeforeFirst
        case .afterLastSeparator:
            return LocalizedStrings.separatorHelpAfterLast

        case .fullTitle:
            return ""
        }
    }
    
    // 为不同策略提供默认分隔符
    private func getDefaultSeparator(for strategy: TitleExtractionStrategy) -> String {
        switch strategy {
        case .firstPart, .lastPart:
            return " - "
        case .beforeFirstSeparator:
            return " — "
        case .afterLastSeparator:
            return " - "
        case .fullTitle:
            return ""
        }
    }
}

// MARK: - About View
struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                AppMainIconView()
                    .frame(width: 48, height: 48)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("DevSwitcher2")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(LocalizedStrings.version)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
            }
            
            // 分隔线
            Divider()
                .padding(.vertical, 8)
            
            // 链接按钮区域 - 重新设计为更美观的卡片式布局
            HStack(spacing: 16) {
                // 官网按钮 - 主要按钮，稍大一些
                Button(action: {
                    if let url = URL(string: "https://rivermao.com/dev/devswitcher2") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: "globe")
                            .font(.system(size: 20, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 32, height: 32)
                            .background(
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [Color.green.opacity(0.8), Color.teal.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                            )
                        
                        Text(LocalizedStrings.openWebsite)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(LinearGradient(
                                colors: [Color.green.opacity(0.3), Color.teal.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .help(LocalizedStrings.website)
                .scaleEffect(1.0)
                .onHover { isHovered in
                    withAnimation(.easeInOut(duration: 0.2)) {
                        // 可以添加悬停效果
                    }
                }
                
                // GitHub按钮
                Button(action: {
                    if let url = URL(string: "https://github.com/vaspike/DevSwitcher2") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: "star.fill")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [Color.blue.opacity(0.8), Color.purple.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                            )
                        
                        Text(LocalizedStrings.openGitHub)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(LinearGradient(
                                colors: [Color.blue.opacity(0.3), Color.purple.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .help(LocalizedStrings.gitHub)
                
                // Buy Me a Coffee按钮
                Button(action: {
                    if let url = URL(string: "https://rivermao.com/about/") {
                        NSWorkspace.shared.open(url)
                    }
                }) {
                    VStack(spacing: 6) {
                        Image(systemName: "cup.and.saucer")
                            .font(.system(size: 18, weight: .medium))
                            .foregroundColor(.white)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [Color.orange.opacity(0.8), Color.yellow.opacity(0.8)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                            )
                        
                        Text(LocalizedStrings.buyMeCoffee)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.primary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .padding(.horizontal, 12)
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(LinearGradient(
                                colors: [Color.orange.opacity(0.3), Color.yellow.opacity(0.3)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .help(LocalizedStrings.supportDevelopment)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text(LocalizedStrings.aboutApp)
                    .font(.headline)
                
                Text(LocalizedStrings.appDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                
                Text(LocalizedStrings.mainFeatures)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.top, 8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStrings.feature1)
                    Text(LocalizedStrings.feature2)
                    Text(LocalizedStrings.feature3)
                    Text(LocalizedStrings.feature4)
                    Text(LocalizedStrings.feature5)
                    Text(LocalizedStrings.feature6)
                }
                .font(.body)
                .foregroundColor(.secondary)
            }
            
            Divider()
            
            // Support Development Section
            VStack(alignment: .leading, spacing: 12) {
                Text(LocalizedStrings.supportDevelopment)
                    .font(.headline)
                
                Text(LocalizedStrings.coffeeDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedStrings.developmentInfo)
                    .font(.headline)
                
                Text(LocalizedStrings.author)
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text(LocalizedStrings.copyright)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - App Main Icon View
struct AppMainIconView: View {
    var body: some View {
        if let nsImage = loadAppIcon() {
            Image(nsImage: nsImage)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            // 备用图标
            Image(systemName: "rectangle.3.group")
                .font(.largeTitle)
                .foregroundColor(.accentColor)
        }
    }
    
    private func loadAppIcon() -> NSImage? {
        // 方法1: 尝试使用应用程序的图标
        if let appIcon = NSApp.applicationIconImage {
            return appIcon
        }
        
        // 方法2: 尝试从bundle中加载.icns文件
        if let iconPath = Bundle.main.path(forResource: "AppIcon", ofType: "icns"),
           let nsImage = NSImage(contentsOfFile: iconPath) {
            return nsImage
        }
        
        return nil
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let hotkeySettingsChanged = Notification.Name("hotkeySettingsChanged")
}

#Preview {
    PreferencesView()
}
