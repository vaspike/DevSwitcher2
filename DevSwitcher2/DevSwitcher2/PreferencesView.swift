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
    @State private var selectedTab = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // 标题栏
            HStack {
                Text("偏好设置")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                        .font(.title2)
                }
                .buttonStyle(PlainButtonStyle())
            }
            .padding()
            .background(.regularMaterial)
            
            Divider()
            
            // Tab选择器
            HStack {
                TabButton(title: "核心功能", isSelected: selectedTab == 0) {
                    selectedTab = 0
                }
                
                TabButton(title: "关于", isSelected: selectedTab == 1) {
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
        .frame(width: 600, height: 500)
        .background(.ultraThinMaterial)
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
    @State private var selectedModifier: ModifierKey
    @State private var selectedTrigger: TriggerKey
    @State private var showingHotkeyWarning = false
    
    init() {
        let settings = SettingsManager.shared.settings
        _selectedModifier = State(initialValue: settings.modifierKey)
        _selectedTrigger = State(initialValue: settings.triggerKey)
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            // 快捷键设置
            VStack(alignment: .leading, spacing: 16) {
                Text("快捷键设置")
                    .font(.title3)
                    .fontWeight(.semibold)
                
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("修饰键")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("修饰键", selection: $selectedModifier) {
                            ForEach(ModifierKey.allCases, id: \.self) { key in
                                Text(key.displayName).tag(key)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 150)
                    }
                    
                    Text("+")
                        .font(.title2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("触发键")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        Picker("触发键", selection: $selectedTrigger) {
                            ForEach(TriggerKey.allCases, id: \.self) { key in
                                Text(key.displayName).tag(key)
                            }
                        }
                        .pickerStyle(MenuPickerStyle())
                        .frame(width: 150)
                    }
                    
                    Spacer()
                    
                    VStack(spacing: 8) {
                        Button("应用") {
                            applyHotkeySettings()
                        }
                        .buttonStyle(.borderedProminent)
                        
                        Button("重置") {
                            resetHotkeySettings()
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                
                Text("当前快捷键: \(selectedModifier.displayName) + \(selectedTrigger.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Divider()
            
            // 窗口标题配置
            WindowTitleConfigView()
        }
        .alert("快捷键冲突", isPresented: $showingHotkeyWarning) {
            Button("确定", role: .cancel) { }
        } message: {
            Text("该快捷键可能与系统或其他应用冲突，请选择其他组合。")
        }
    }
    
    private func applyHotkeySettings() {
        settingsManager.updateHotkey(modifier: selectedModifier, trigger: selectedTrigger)
        // 通知系统重新注册热键
        NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
    }
    
    private func resetHotkeySettings() {
        selectedModifier = .command
        selectedTrigger = .grave
        applyHotkeySettings()
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
            Text("窗口标题配置")
                .font(.title3)
                .fontWeight(.semibold)
            
            // 默认策略设置
            VStack(alignment: .leading, spacing: 12) {
                Text("默认提取策略")
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                HStack {
                    Picker("默认策略", selection: $selectedDefaultStrategy) {
                        ForEach(TitleExtractionStrategy.allCases, id: \.self) { strategy in
                            Text(strategy.displayName).tag(strategy)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                    .frame(width: 200)
                    
                    if selectedDefaultStrategy == .customSeparator {
                        TextField("自定义分隔符", text: $defaultCustomSeparator)
                            .textFieldStyle(RoundedBorderTextFieldStyle())
                            .frame(width: 100)
                    }
                    
                    Spacer()
                    
                    Button("应用") {
                        settingsManager.updateDefaultTitleStrategy(selectedDefaultStrategy, customSeparator: defaultCustomSeparator)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            }
            
            // 应用特定配置
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("应用特定配置")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    
                    Spacer()
                    
                    Button("添加应用") {
                        showingAddAppDialog = true
                    }
                    .buttonStyle(.borderedProminent)
                }
                
                if settingsManager.settings.appTitleConfigs.isEmpty {
                    Text("暂无应用特定配置")
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
                
                Text("策略: \(config.strategy.displayName)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Button("删除") {
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
            Text("添加应用配置")
                .font(.title2)
                .fontWeight(.semibold)
            
            VStack(alignment: .leading, spacing: 12) {
                Text("Bundle ID")
                    .font(.subheadline)
                TextField("例如: com.apple.dt.Xcode", text: $bundleId)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text("应用名称")
                    .font(.subheadline)
                TextField("例如: Xcode", text: $appName)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                
                Text("提取策略")
                    .font(.subheadline)
                Picker("策略", selection: $strategy) {
                    ForEach(TitleExtractionStrategy.allCases, id: \.self) { strategy in
                        Text(strategy.displayName).tag(strategy)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                
                if strategy == .customSeparator {
                    Text("自定义分隔符")
                        .font(.subheadline)
                    TextField("例如:  - ", text: $customSeparator)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
            }
            
            HStack {
                Button("取消") {
                    dismiss()
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("保存") {
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
                    
                    Text("版本 2.0.0")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 12) {
                Text("关于此应用")
                    .font(.headline)
                
                Text("DevSwitcher2 是一个高效的 macOS 窗口切换工具，帮助您快速在同一应用的不同窗口之间切换。")
                    .font(.body)
                    .foregroundColor(.secondary)
                
                Text("主要功能:")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .padding(.top, 8)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("• 快速窗口切换")
                    Text("• 自定义快捷键")
                    Text("• 智能标题识别")
                    Text("• 多应用支持")
                }
                .font(.body)
                .foregroundColor(.secondary)
            }
            
            Divider()
            
            VStack(alignment: .leading, spacing: 8) {
                Text("开发信息")
                    .font(.headline)
                
                Text("© 2025 DevSwitcher2. All rights reserved.")
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