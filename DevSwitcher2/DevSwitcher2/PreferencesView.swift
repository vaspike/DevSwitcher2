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
            
            // Tab选择器
            HStack {
                TabButton(title: LocalizedStrings.coreSettings, isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                
                TabButton(title: LocalizedStrings.about, isSelected: selectedTab == 1) {
                    selectedTab = 1
                }
                
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 16)
            
            // 内容区域
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    if selectedTab == 0 {
                        CoreSettingsView()
                    } else {
                        AboutView()
                    }
                }
                .padding()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 700, height: 500)
        .background(.ultraThinMaterial)
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            // 当语言变化时强制刷新视图
            // SwiftUI会自动重新计算LocalizedStrings的值
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
                .font(.headline)
                .foregroundColor(isSelected ? .primary : .secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
                )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - 核心功能设置视图
struct CoreSettingsView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    @StateObject private var languageManager = LanguageManager.shared
    @State private var selectedModifier: ModifierKey
    @State private var selectedTrigger: TriggerKey
    @State private var showingHotkeyWarning = false
    
    // CT2设置状态
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
        VStack(alignment: .leading, spacing: 24) {
            // 语言设置
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(LocalizedStrings.language)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Spacer()
                }
                
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedStrings.language)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker(LocalizedStrings.language, selection: $languageManager.currentLanguage) {
                            ForEach(AppLanguage.allCases, id: \.self) { language in
                                Text(language.displayName).tag(language)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: .infinity)
                        .onChange(of: languageManager.currentLanguage) { newLanguage in
                            languageManager.setLanguage(newLanguage)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedStrings.languageRestartHint)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Spacer()
                            .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            
            Divider()
            
            // DS2快捷键设置
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(LocalizedStrings.ds2SameAppWindowSwitching)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    HStack(spacing: 8) {
                        Button(LocalizedStrings.apply) {
                            applyDS2HotkeySettings()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button(LocalizedStrings.reset) {
                            resetDS2HotkeySettings()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                
                HStack(spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedStrings.modifierKey)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker(LocalizedStrings.modifierKey, selection: $selectedModifier) {
                            ForEach(ModifierKey.allCases, id: \.self) { key in
                                Text(key.displayName).tag(key)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                    
                    Text("+")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .frame(width: 20)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(LocalizedStrings.triggerKey)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker(LocalizedStrings.triggerKey, selection: $selectedTrigger) {
                            ForEach(TriggerKey.allCases, id: \.self) { key in
                                Text(key.displayName).tag(key)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(maxWidth: .infinity)
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                
                Text("\(LocalizedStrings.currentDS2Hotkey): \(selectedModifier.displayName) + \(selectedTrigger.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // CT2快捷键设置
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Text(LocalizedStrings.ct2AppSwitcher)
                        .font(.title3)
                        .fontWeight(.semibold)
                    
                    Spacer()
                    
                    Toggle(LocalizedStrings.enableCT2, isOn: $ct2Enabled)
                        .toggleStyle(SwitchToggleStyle())
                        .onChange(of: ct2Enabled) { newValue in
                            // 实时更新CT2启用状态
                            settingsManager.updateCT2Enabled(newValue)
                            NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
                        }
                }
                
                if ct2Enabled {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(LocalizedStrings.configuration)
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Spacer()
                            
                            HStack(spacing: 8) {
                                Button(LocalizedStrings.apply) {
                                    applyCT2HotkeySettings()
                                }
                                .buttonStyle(.borderedProminent)
                                
                                Button(LocalizedStrings.reset) {
                                    resetCT2HotkeySettings()
                                }
                                .buttonStyle(.bordered)
                            }
                        }
                        
                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 8) {
                                Text(LocalizedStrings.modifierKey)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Picker("CT2" + LocalizedStrings.modifierKey, selection: $selectedCT2Modifier) {
                                    ForEach(ModifierKey.allCases, id: \.self) { key in
                                        Text(key.displayName).tag(key)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .frame(maxWidth: .infinity)
                            }
                            .frame(maxWidth: .infinity)
                            
                            Text("+")
                                .font(.title2)
                                .foregroundColor(.secondary)
                                .frame(width: 20)
                            
                            VStack(alignment: .leading, spacing: 8) {
                                Text(LocalizedStrings.triggerKey)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                
                                Picker("CT2" + LocalizedStrings.triggerKey, selection: $selectedCT2Trigger) {
                                    ForEach(TriggerKey.allCases, id: \.self) { key in
                                        Text(key.displayName).tag(key)
                                    }
                                }
                                .pickerStyle(MenuPickerStyle())
                                .frame(maxWidth: .infinity)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                    .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                    
                    Text("\(LocalizedStrings.currentCT2Hotkey): \(selectedCT2Modifier.displayName) + \(selectedCT2Trigger.displayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text(LocalizedStrings.ct2FunctionDisabled)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding()
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            
            Divider()
            
            // 窗口标题配置
            WindowTitleConfigView()
        }
        .alert(LocalizedStrings.hotkeyConflictTitle, isPresented: $showingHotkeyWarning) {
            Button(LocalizedStrings.confirm, role: .cancel) { }
        } message: {
            Text(LocalizedStrings.hotkeyConflictMessage)
        }
    }
    
    // DS2热键设置方法
    private func applyDS2HotkeySettings() {
        settingsManager.updateHotkey(modifier: selectedModifier, trigger: selectedTrigger)
        // 通知系统重新注册热键
        NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
    }
    
    private func resetDS2HotkeySettings() {
        selectedModifier = .command
        selectedTrigger = .grave
        applyDS2HotkeySettings()
    }
    
    // CT2热键设置方法
    private func applyCT2HotkeySettings() {
        settingsManager.updateCT2Enabled(ct2Enabled)
        settingsManager.updateCT2Hotkey(modifier: selectedCT2Modifier, trigger: selectedCT2Trigger)
        // 通知系统重新注册热键
        NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
    }
    
    private func resetCT2HotkeySettings() {
        ct2Enabled = true
        selectedCT2Modifier = .command
        selectedCT2Trigger = .tab
        applyCT2HotkeySettings()
    }
}

// MARK: - 窗口标题配置视图
struct WindowTitleConfigView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var selectedDefaultStrategy: TitleExtractionStrategy
    @State private var defaultCustomSeparator: String
    @State private var showingAddAppDialog = false
    @State private var newAppBundleId = ""
    @State private var newAppName = ""
    @State private var newAppStrategy: TitleExtractionStrategy = .beforeFirstSeparator
    @State private var newAppCustomSeparator = " - "
    
    init() {
        let settings = SettingsManager.shared.settings
        _selectedDefaultStrategy = State(initialValue: settings.defaultTitleStrategy)
        _defaultCustomSeparator = State(initialValue: settings.defaultCustomSeparator)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(LocalizedStrings.windowTitleConfig)
                .font(.title3)
                .fontWeight(.semibold)
            
            // 默认策略设置
            VStack(alignment: .leading, spacing: 12) {

                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        
                        Button(LocalizedStrings.apply) {
                            settingsManager.updateDefaultTitleStrategy(selectedDefaultStrategy, customSeparator: defaultCustomSeparator)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    
                    HStack(spacing: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(LocalizedStrings.defaultExtractionStrategy)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            Picker(LocalizedStrings.defaultExtractionStrategy, selection: $selectedDefaultStrategy) {
                                ForEach(TitleExtractionStrategy.allCases, id: \.self) { strategy in
                                    Text(strategy.displayName).tag(strategy)
                                }
                            }
                            .pickerStyle(MenuPickerStyle())
                            .frame(maxWidth: .infinity)
                        }
                        .frame(maxWidth: .infinity)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            Text(selectedDefaultStrategy == .customSeparator ? LocalizedStrings.customSeparator : "")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            if selectedDefaultStrategy == .customSeparator {
                                TextField(LocalizedStrings.customSeparator, text: $defaultCustomSeparator)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .frame(maxWidth: .infinity)
                            } else {
                                Spacer()
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            
            // 应用特定配置
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text(LocalizedStrings.appSpecificConfig)
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Button(LocalizedStrings.addApp) {
                        showingAddAppDialog = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                if settingsManager.settings.appTitleConfigs.isEmpty {
                    Text(LocalizedStrings.noAppConfigs)
                        .foregroundColor(.secondary)
                        .italic()
                        .padding()
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
            .padding()
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
        }
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
                    customSeparator: newAppStrategy == .customSeparator ? newAppCustomSeparator : nil
                )
                settingsManager.setAppTitleConfig(config)
                showingAddAppDialog = false
                // 重置表单
                newAppBundleId = ""
                newAppName = ""
                newAppStrategy = .beforeFirstSeparator
                newAppCustomSeparator = " - "
            }
        }
    }
}

struct AppConfigRowView: View {
    let config: AppTitleConfig
    let onDelete: () -> Void
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(config.appName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(config.bundleId)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text("\(LocalizedStrings.strategy): \(config.strategy.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button(LocalizedStrings.delete) {
                onDelete()
            }
            .buttonStyle(.bordered)
            .foregroundColor(.red)
        }
        .padding()
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

struct AddAppConfigView: View {
    @Binding var bundleId: String
    @Binding var appName: String
    @Binding var strategy: TitleExtractionStrategy
    @Binding var customSeparator: String
    let onSave: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text(LocalizedStrings.addAppConfig)
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                Text(LocalizedStrings.bundleId)
                    .font(.subheadline)
                TextField(LocalizedStrings.bundleIdPlaceholder, text: $bundleId)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text(LocalizedStrings.appName)
                    .font(.subheadline)
                TextField(LocalizedStrings.appNamePlaceholder, text: $appName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text(LocalizedStrings.extractionStrategy)
                    .font(.subheadline)
                Picker(LocalizedStrings.strategy, selection: $strategy) {
                    ForEach(TitleExtractionStrategy.allCases, id: \.self) { strategy in
                        Text(strategy.displayName).tag(strategy)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                if strategy == .customSeparator {
                    Text(LocalizedStrings.customSeparator)
                        .font(.subheadline)
                    TextField(LocalizedStrings.customSeparatorPlaceholder, text: $customSeparator)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            
            HStack {
                Button(LocalizedStrings.cancel) {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button(LocalizedStrings.save) {
                    onSave()
                }
                .buttonStyle(.borderedProminent)
                .disabled(bundleId.isEmpty || appName.isEmpty)
            }
        }
        .padding()
        .frame(width: 400, height: 300)
    }
}

// MARK: - 关于视图
struct AboutView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Image(systemName: "rectangle.3.group")
                    .font(.largeTitle)
                    .foregroundColor(.accentColor)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("DevSwitcher2")
                        .font(.title)
                        .fontWeight(.bold)
                    
                    Text(LocalizedStrings.version)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text(LocalizedStrings.aboutApp)
                    .font(.headline)
                
                Text(LocalizedStrings.appDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text(LocalizedStrings.mainFeatures)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.top, 8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStrings.feature1)
                    Text(LocalizedStrings.feature2)
                    Text(LocalizedStrings.feature3)
                    Text(LocalizedStrings.feature4)
                }
                .font(.body)
                .foregroundColor(.secondary)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text(LocalizedStrings.developmentInfo)
                    .font(.headline)
                
                Text(LocalizedStrings.copyright)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
        }
        .padding()
    }
}

// MARK: - 通知扩展
extension Notification.Name {
    static let hotkeySettingsChanged = Notification.Name("hotkeySettingsChanged")
}

#Preview {
    PreferencesView()
}
