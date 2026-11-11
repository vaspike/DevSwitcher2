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
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    AppMainIconView()
                        .frame(width: 30, height: 30)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("DevSwitcher2")
                            .font(.title3)
                            .fontWeight(.semibold)
                        Text(LocalizedStrings.preferencesSubtitle)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()
                }

                HStack(spacing: 6) {
                    TabButton(title: LocalizedStrings.generalSettingsTabTitle, systemImage: "slider.horizontal.3", isSelected: selectedTab == 0) {
                        selectedTab = 0
                    }
                    TabButton(title: LocalizedStrings.switcherSettingsTabTitle, systemImage: "rectangle.3.group", isSelected: selectedTab == 1) {
                        selectedTab = 1
                    }
                    TabButton(title: LocalizedStrings.windowTitleSectionTitle, systemImage: "textformat", isSelected: selectedTab == 2) {
                        selectedTab = 2
                    }
                    TabButton(title: LocalizedStrings.aboutTabTitle, systemImage: "info.circle", isSelected: selectedTab == 3) {
                        selectedTab = 3
                    }
                }
                .padding(4)
                .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 10))
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 12)
            .background(.regularMaterial)

            Divider()

            ScrollView {
                Group {
                    switch selectedTab {
                    case 0:
                        GeneralSettingsView()
                    case 1:
                        SwitcherDisplaySettingsView()
                    case 2:
                        WindowTitleConfigView()
                    default:
                        AboutView()
                    }
                }
                .padding(20)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 840, height: 640)
        .background(Color(NSColor.windowBackgroundColor))
        .onReceive(NotificationCenter.default.publisher(for: .languageChanged)) { _ in
            // Force refresh view when language changes
            // SwiftUI will automatically recalculate LocalizedStrings values
        }
    }
}

struct TabButton: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .medium))
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
            }
            .foregroundColor(isSelected ? .accentColor : .secondary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 7)
                    .fill(isSelected ? Color.accentColor.opacity(0.12) : Color.clear)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct SettingsGroup<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)
                .foregroundColor(.primary)

            VStack(spacing: 0) {
                content
            }
            .padding(.horizontal, 16)
            .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
        }
    }
}

struct SettingRow<Accessory: View>: View {
    let title: String
    let description: String?
    let accessory: Accessory

    init(_ title: String, description: String? = nil, @ViewBuilder accessory: () -> Accessory) {
        self.title = title
        self.description = description
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let description = description {
                    Text(description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .layoutPriority(1)

            Spacer(minLength: 12)
            accessory
        }
        .padding(.vertical, 12)
    }
}

// MARK: - General Settings Section
struct GeneralSettingsSection: View {
    @ObservedObject var settingsManager: SettingsManager
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsGroup(LocalizedStrings.generalSettingsSectionTitle) {
                SettingRow(
                    LocalizedStrings.launchAtStartup,
                    description: LocalizedStrings.launchAtStartupDescription
                ) {
                    Toggle("", isOn: Binding(
                        get: { settingsManager.settings.launchAtStartup },
                        set: { settingsManager.updateLaunchAtStartup($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                }

                Divider()

                SettingRow(
                    LocalizedStrings.showMenuBarIcon,
                    description: LocalizedStrings.showMenuBarIconDescription
                ) {
                    Toggle("", isOn: Binding(
                        get: { settingsManager.settings.showMenuBarIcon },
                        set: { settingsManager.updateShowMenuBarIcon($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                }
            }

            HStack {
                Spacer()
                Button(LocalizedStrings.quitApp, role: .destructive) {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.borderless)
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 4)
            }
        }
    }
}

// MARK: - Language Settings Section
struct LanguageSettingsSection: View {
    @ObservedObject var languageManager: LanguageManager
    
    var body: some View {
        SettingsGroup(LocalizedStrings.languageSectionTitle) {
            SettingRow(LocalizedStrings.language) {
                Picker("", selection: $languageManager.currentLanguage) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(language.displayName).tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(MenuPickerStyle())
                .fixedSize()
                .onChange(of: languageManager.currentLanguage) { newLanguage in
                    languageManager.setLanguage(newLanguage)
                }
            }

            Divider()

            SettingRow(LocalizedStrings.languageRestartNote) {
                Button(LocalizedStrings.languageRestartNowButton) {
                    restartApplication()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
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
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStrings.ds2HotkeySectionTitle)
                    .font(.headline)
                Text(LocalizedStrings.ds2HotkeyDescription)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            HStack(spacing: 12) {
                HotkeyField(
                    title: LocalizedStrings.modifierKeyLabel,
                    selection: $selectedModifier,
                    items: Array(ModifierKey.allCases),
                    displayName: { $0.displayName }
                )

                Text("+")
                    .font(.headline)
                    .foregroundColor(.secondary)
                    .padding(.top, 20)

                HotkeyField(
                    title: LocalizedStrings.triggerKeyLabel,
                    selection: $selectedTrigger,
                    items: Array(TriggerKey.allCases),
                    displayName: { $0.displayName }
                )
            }

            HStack {
                HotkeyValuePreview(
                    LocalizedStrings.currentHotkeyDisplay(
                        selectedModifier.displayName,
                        selectedTrigger.displayName
                    )
                )

                Spacer()

                Button(LocalizedStrings.hotkeyReset, action: onReset)
                    .buttonStyle(.bordered)
                    .controlSize(.small)

                Button(LocalizedStrings.hotkeyApply, action: onApply)
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
            }
        }
        .hotkeyCardStyle()
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
            HStack(alignment: .center) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(LocalizedStrings.ct2HotkeySectionTitle)
                        .font(.headline)
                    Text(LocalizedStrings.ct2HotkeyDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Toggle(LocalizedStrings.ct2EnableToggle, isOn: $ct2Enabled)
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                    .onChange(of: ct2Enabled) { newValue in
                        settingsManager.updateCT2Enabled(newValue)
                        NotificationCenter.default.post(name: .hotkeySettingsChanged, object: nil)
                    }
            }

            if ct2Enabled {
                HStack(spacing: 12) {
                    HotkeyField(
                        title: LocalizedStrings.modifierKeyLabel,
                        selection: $selectedModifier,
                        items: Array(ModifierKey.allCases),
                        displayName: { $0.displayName }
                    )

                    Text("+")
                        .font(.headline)
                        .foregroundColor(.secondary)
                        .padding(.top, 20)

                    HotkeyField(
                        title: LocalizedStrings.triggerKeyLabel,
                        selection: $selectedTrigger,
                        items: Array(TriggerKey.allCases),
                        displayName: { $0.displayName }
                    )
                }

                HStack {
                    HotkeyValuePreview(
                        LocalizedStrings.currentHotkeyDisplay(
                            selectedModifier.displayName,
                            selectedTrigger.displayName
                        )
                    )

                    Spacer()

                    Button(LocalizedStrings.hotkeyReset, action: onReset)
                        .buttonStyle(.bordered)
                        .controlSize(.small)

                    Button(LocalizedStrings.hotkeyApply, action: onApply)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.small)
                }
            } else {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle")
                    Text(LocalizedStrings.ct2DisabledMessage)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 4)
            }
        }
        .hotkeyCardStyle()
    }
}

struct HotkeyField<Key: Hashable>: View {
    let title: String
    @Binding var selection: Key
    let items: [Key]
    let displayName: (Key) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Picker(title, selection: $selection) {
                ForEach(items, id: \.self) { item in
                    Text(displayName(item)).tag(item)
                }
            }
            .labelsHidden()
            .pickerStyle(MenuPickerStyle())
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity)
    }
}

struct HotkeyValuePreview: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "keyboard")
            Text(text)
                .lineLimit(1)
                .minimumScaleFactor(0.85)
        }
        .font(.system(size: 12, weight: .medium))
        .foregroundColor(.accentColor)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.accentColor.opacity(0.08), in: RoundedRectangle(cornerRadius: 7))
    }
}

extension View {
    func hotkeyCardStyle() -> some View {
        padding(16)
            .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
    }
}

// MARK: - General Settings View
struct GeneralSettingsView: View {
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
        VStack(alignment: .leading, spacing: 20) {
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

            LanguageSettingsSection(languageManager: languageManager)
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

// MARK: - Advanced Settings View
struct AdvancedSettingsView: View {
    @State private var expandedSections: Set<String> = []
    
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 切换器视图显示设置
            CollapsibleSection(
                id: "switcher_display_settings",
                title: LocalizedStrings.switcherDisplaySectionTitle,
                isExpanded: expandedSections.contains("switcher_display_settings")
            ) {
                SwitcherDisplaySettingsView()
            } onToggle: { isExpanded in
                if isExpanded {
                    expandedSections.insert("switcher_display_settings")
                } else {
                    expandedSections.remove("switcher_display_settings")
                }
            }
            
            // 窗口标题配置区域
            CollapsibleSection(
                id: "window_title_config",
                title: LocalizedStrings.windowTitleSectionTitle,
                isExpanded: expandedSections.contains("window_title_config")
            ) {
                WindowTitleConfigView()
            } onToggle: { isExpanded in
                if isExpanded {
                    expandedSections.insert("window_title_config")
                } else {
                    expandedSections.remove("window_title_config")
                }
            }
        }
        .onAppear {
            // 默认展开第一个区域
            expandedSections.insert("switcher_display_settings")
        }
    }
}

// MARK: - Collapsible Section Component
struct CollapsibleSection<Content: View>: View {
    let id: String
    let title: String
    let isExpanded: Bool
    let content: () -> Content
    let onToggle: (Bool) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header with toggle button
            Button(action: {
                withAnimation(.easeInOut(duration: 0.2)) {
                    onToggle(!isExpanded)
                }
            }) {
                HStack {
                    Text(title)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: isExpanded ? "chevron.down" : "chevron.right")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(isExpanded ? 0 : 0))
                        .animation(.easeInOut(duration: 0.2), value: isExpanded)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.secondary.opacity(0.1), lineWidth: 1)
                )
            }
            .buttonStyle(PlainButtonStyle())
            
            // Content area with animation
            if isExpanded {
                VStack(spacing: 0) {
                    content()
                }
                .transition(.asymmetric(
                    insertion: .opacity.combined(with: .scale(scale: 0.95, anchor: .top)),
                    removal: .opacity.combined(with: .scale(scale: 0.95, anchor: .top))
                ))
                .padding(.top, 16)
            }
        }
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
        WindowTitleSettingsContentView(
            selectedDefaultStrategy: $selectedDefaultStrategy,
            defaultCustomSeparator: $defaultCustomSeparator,
            configManager: configManager,
            settingsManager: settingsManager,
            showingAddAppDialog: $showingAddAppDialog,
            onImport: importConfiguration,
            onExport: exportConfiguration
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
                Text(LocalizedStrings.previewNoWindowsFound)
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
        VStack(alignment: .leading, spacing: 24) {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 14) {
                    AppMainIconView()
                        .frame(width: 60, height: 60)

                    VStack(alignment: .leading, spacing: 6) {
                        Text("DevSwitcher2")
                            .font(.title2)
                            .fontWeight(.semibold)

                        Text(LocalizedStrings.version)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.secondary.opacity(0.08), in: Capsule())
                    }

                    Spacer()
                }

                Text(LocalizedStrings.appDescription)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineSpacing(3)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 12) {
                Text(LocalizedStrings.supportDevelopment)
                    .font(.headline)

                Text(LocalizedStrings.coffeeDescription)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                HStack(spacing: 12) {
                    AboutActionCard(
                        title: LocalizedStrings.openGitHub,
                        systemImage: "star.fill",
                        tint: .yellow,
                        help: LocalizedStrings.gitHub
                    ) {
                        openURL("https://github.com/vaspike/DevSwitcher2")
                    }

                    AboutActionCard(
                        title: LocalizedStrings.buyMeCoffee,
                        systemImage: "cup.and.saucer.fill",
                        tint: .orange,
                        help: LocalizedStrings.supportDevelopment
                    ) {
                        openURL("https://rivermao.com/about/")
                    }
                }
            }

            SettingsGroup(LocalizedStrings.developmentInfo) {
                HStack(spacing: 8) {
                    Image(systemName: "person")
                        .foregroundColor(.secondary)
                        .frame(width: 16)
                    Text(LocalizedStrings.author)
                        .foregroundColor(.secondary)
                        .frame(width: 88, alignment: .leading)
                    Text("River")
                        .foregroundColor(.primary)
                    Spacer()
                }
                .font(.subheadline)
                .padding(.vertical, 12)

                Divider()

                Button {
                    openURL("mailto:rivermao@foxmail.com")
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "envelope")
                            .foregroundColor(.secondary)
                            .frame(width: 16)
                        Text(LocalizedStrings.contactEmail)
                            .foregroundColor(.secondary)
                            .frame(width: 88, alignment: .leading)
                        Text("rivermao@foxmail.com")
                            .foregroundColor(.accentColor)
                        Spacer()
                    }
                    .font(.subheadline)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.vertical, 12)

                Divider()

                Text(LocalizedStrings.copyright)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 12)
            }

            Spacer(minLength: 0)
        }
        .padding(4)
        .frame(maxWidth: 580)
        .frame(maxWidth: .infinity)
    }

    private func openURL(_ string: String) {
        guard let url = URL(string: string) else { return }
        NSWorkspace.shared.open(url)
    }
}

struct AboutActionCard: View {
    let title: String
    let systemImage: String
    let tint: Color
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.12), in: Circle())

                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color(NSColor.controlBackgroundColor), in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
        .help(help)
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

// MARK: - Switcher Display Settings View
struct SwitcherDisplaySettingsView: View {
    @StateObject private var settingsManager = SettingsManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            SettingsGroup(LocalizedStrings.coreSettings) {
                SettingRow(
                    LocalizedStrings.showNumberKeysLabel,
                    description: LocalizedStrings.showNumberKeysDescription
                ) {
                    Toggle("", isOn: Binding(
                        get: { settingsManager.settings.showNumberKeys },
                        set: { settingsManager.updateShowNumberKeys($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                }

                Divider()

                SettingRow(
                    LocalizedStrings.followActiveWindowLabel,
                    description: LocalizedStrings.followActiveWindowDescription
                ) {
                    Toggle("", isOn: Binding(
                        get: { settingsManager.settings.switcherFollowActiveWindow },
                        set: { settingsManager.updateSwitcherFollowActiveWindow($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                }

                Divider()

                SettingRow(
                    LocalizedStrings.selectNextItemOnOpen,
                    description: LocalizedStrings.selectNextItemOnOpenDescription
                ) {
                    Toggle("", isOn: Binding(
                        get: { settingsManager.settings.selectNextItemOnOpen },
                        set: { settingsManager.updateSelectNextItemOnOpen($0) }
                    ))
                    .labelsHidden()
                    .toggleStyle(SwitchToggleStyle(tint: .accentColor))
                }

                Divider()

                VStack(alignment: .leading, spacing: 12) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(LocalizedStrings.switcherVerticalPositionLabel)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(LocalizedStrings.switcherVerticalPositionDescription)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    VerticalPositionControl()
                }
                .padding(.vertical, 12)
            }

            SettingsGroup(LocalizedStrings.switcherDisplaySectionTitle) {
                SettingRow(
                    LocalizedStrings.switcherHeaderStyleLabel,
                    description: LocalizedStrings.switcherHeaderStyleDescription
                ) {
                    Picker("", selection: Binding(
                        get: { settingsManager.settings.switcherHeaderStyle },
                        set: { settingsManager.updateSwitcherHeaderStyle($0) }
                    )) {
                        ForEach(SwitcherHeaderStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 190)
                }

                Divider()

                SettingRow(
                    LocalizedStrings.switcherLayoutStyleLabel,
                    description: LocalizedStrings.switcherLayoutStyleDescription
                ) {
                    Picker("", selection: Binding(
                        get: { settingsManager.settings.switcherLayoutStyle },
                        set: { settingsManager.updateSwitcherLayoutStyle($0) }
                    )) {
                        ForEach(SwitcherLayoutStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 190)
                }

                if settingsManager.settings.switcherLayoutStyle == .circular {
                    Divider()

                    SettingRow(
                        LocalizedStrings.circularLayoutSizeLabel,
                        description: LocalizedStrings.circularLayoutSizeDescription
                    ) {
                        VStack(spacing: 4) {
                            Slider(
                                value: Binding(
                                    get: { settingsManager.settings.circularLayoutSize },
                                    set: { settingsManager.updateCircularLayoutSize($0) }
                                ),
                                in: 1.0...2.0,
                                step: 0.1
                            )
                            .frame(width: 170)

                            HStack {
                                Text(LocalizedStrings.circularLayoutSizeSmall)
                                Spacer()
                                Text(LocalizedStrings.circularLayoutSizeLarge)
                            }
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .frame(width: 170)
                        }
                    }

                    Divider()

                    SettingRow(
                        LocalizedStrings.circularLayoutOuterRingStyleLabel,
                        description: LocalizedStrings.circularLayoutOuterRingStyleDescription
                    ) {
                        Picker("", selection: Binding(
                            get: { settingsManager.settings.circularLayoutOuterRingStyle },
                            set: { settingsManager.updateCircularLayoutOuterRingStyle($0) }
                        )) {
                            ForEach(CircularOuterRingStyle.allCases, id: \.self) { style in
                                Text(style.displayName).tag(style)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(SegmentedPickerStyle())
                        .frame(width: 190)
                    }
                }

                Divider()

                SettingRow(
                    LocalizedStrings.selectedItemDisplayStyleLabel,
                    description: LocalizedStrings.selectedItemDisplayStyleDescription
                ) {
                    Picker("", selection: Binding(
                        get: { settingsManager.settings.selectedItemDisplayStyle },
                        set: { settingsManager.updateSelectedItemDisplayStyle($0) }
                    )) {
                        ForEach(SelectedItemDisplayStyle.allCases, id: \.self) { style in
                            Text(style.displayName).tag(style)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(SegmentedPickerStyle())
                    .frame(width: 190)
                }
            }

            SettingsGroup(LocalizedStrings.colorSchemeSectionTitle) {
                VStack(alignment: .leading, spacing: 16) {
                    Text(LocalizedStrings.colorSchemeDescription)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    ColorSchemePickerView()
                    ColorSchemePreviewView()
                }
                .padding(.vertical, 16)
            }
        }
    }
}

// MARK: - Vertical Position Control
struct VerticalPositionControl: View {
    @StateObject private var settingsManager = SettingsManager.shared
    @State private var textFieldValue: String = ""
    
    private var currentPosition: Double {
        settingsManager.settings.switcherVerticalPosition
    }
    
    var body: some View {
        VStack(spacing: 12) {
            // Slider and TextField row
            HStack(spacing: 12) {
                // Slider
                Slider(
                    value: Binding(
                        get: { currentPosition },
                        set: { newValue in
                            settingsManager.updateSwitcherVerticalPosition(newValue)
                            textFieldValue = String(format: "%.2f", newValue)
                        }
                    ),
                    in: 0.1...0.8,
                    step: 0.01
                )
                .frame(minWidth: 120)
                
                
                // Reset button
                Button(LocalizedStrings.resetToGoldenRatio) {
                    settingsManager.updateSwitcherVerticalPosition(0.39)
                    textFieldValue = "0.39"
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
            
            // Current value display
            Text(LocalizedStrings.currentPosition(String(format: "%.1f%%", currentPosition * 100)))
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .onAppear {
            textFieldValue = String(format: "%.2f", currentPosition)
        }
        .onChange(of: currentPosition) { newValue in
            textFieldValue = String(format: "%.2f", newValue)
        }
    }
}

// MARK: - Color Scheme Picker View
struct ColorSchemePickerView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 5), spacing: 12) {
            ForEach(ColorScheme.allCases, id: \.self) { scheme in
                ColorSchemeCardView(
                    scheme: scheme,
                    isSelected: settingsManager.settings.colorScheme == scheme
                ) {
                    settingsManager.updateColorScheme(scheme)
                }
            }
        }
    }
}

// MARK: - Color Scheme Preview View
struct ColorSchemePreviewView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(LocalizedStrings.colorSchemePreviewTitle)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)
            
            HStack {
                // Circular layout preview
                VStack(spacing: 8) {
                    Text(LocalizedStrings.colorSchemeCircularPreview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    CircularPreviewView()
                        .frame(width: 120, height: 120)
                }
                
                Spacer()
                
                // List layout preview
                VStack(spacing: 8) {
                    Text(LocalizedStrings.colorSchemeListPreview)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    ListPreviewView()
                        .frame(width: 200, height: 80)
                }
            }
        }
        .padding(12)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Circular Preview View
struct CircularPreviewView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        let colorScheme = settingsManager.settings.colorScheme
        
        ZStack {
            // Background
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle()
                        .fill(colorScheme.backgroundGradient)
                        .opacity(0.2)
                )
            
            // Outer ring sectors
            ForEach(0..<6, id: \.self) { index in
                let angle = Double(index) * 60.0
                let isSelected = index == 0
                
                Path { path in
                    let center = CGPoint(x: 60, y: 60)
                    let outerRadius: CGFloat = 50
                    let innerRadius: CGFloat = 30
                    
                    path.addArc(center: center, radius: outerRadius, startAngle: Angle(degrees: angle), endAngle: Angle(degrees: angle + 60), clockwise: false)
                    path.addArc(center: center, radius: innerRadius, startAngle: Angle(degrees: angle + 60), endAngle: Angle(degrees: angle), clockwise: true)
                    path.closeSubpath()
                }
                .fill(isSelected ? colorScheme.primaryColor.opacity(0.3) : colorScheme.secondaryColor.opacity(0.1))
            }
            
            // Center area
            Circle()
                .fill(.ultraThinMaterial)
                .overlay(
                    Circle()
                        .fill(colorScheme.backgroundGradient)
                        .opacity(0.3)
                )
                .overlay(
                    Circle()
                        .stroke(colorScheme.glowColor, lineWidth: 1)
                        .blur(radius: 2)
                        .opacity(0.6)
                )
                .frame(width: 50, height: 50)
                .shadow(color: colorScheme.primaryColor.opacity(0.3), radius: 4, x: 0, y: 2)
        }
    }
}

// MARK: - List Preview View
struct ListPreviewView: View {
    @StateObject private var settingsManager = SettingsManager.shared
    
    var body: some View {
        let colorScheme = settingsManager.settings.colorScheme
        
        VStack(spacing: 2) {
            // Header
            HStack {
                Circle()
                    .fill(colorScheme.primaryColor)
                    .frame(width: 8, height: 8)
                Text(LocalizedStrings.colorSchemeSampleApp)
                    .font(.caption2)
                    .foregroundColor(.primary)
                Spacer()
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(colorScheme.primaryColor.opacity(0.15))
            .cornerRadius(4)
            
            // Item
            HStack {
                Circle()
                    .fill(colorScheme.secondaryColor)
                    .frame(width: 6, height: 6)
                Text(LocalizedStrings.colorSchemeSampleWindow)
                    .font(.caption2)
                    .foregroundColor(.primary)
                Spacer()
                Circle()
                    .fill(colorScheme.accentColor)
                    .frame(width: 6, height: 6)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(colorScheme.primaryColor.opacity(0.05))
            .cornerRadius(4)
        }
        .padding(4)
        .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 6))
    }
}

// MARK: - Color Scheme Card View
struct ColorSchemeCardView: View {
    let scheme: ColorScheme
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 8) {
                // Color preview circle with enhanced design
                ZStack {
                    // Background gradient
                    Circle()
                        .fill(scheme.backgroundGradient)
                        .frame(width: 40, height: 40)
                    
                    // Primary color ring
                    Circle()
                        .stroke(scheme.primaryColor, lineWidth: 2)
                        .frame(width: 40, height: 40)
                        .opacity(0.8)
                    
                    // Secondary color accent
                    Circle()
                        .fill(scheme.secondaryColor)
                        .frame(width: 20, height: 20)
                        .opacity(0.6)
                    
                    // Accent color center
                    Circle()
                        .fill(scheme.accentColor)
                        .frame(width: 12, height: 12)
                        .opacity(0.9)
                }
                
                // Scheme name
                Text(scheme.displayName)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .padding(8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? scheme.primaryColor.opacity(0.1) : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isSelected ? scheme.primaryColor : Color.gray.opacity(0.2), lineWidth: isSelected ? 2 : 1)
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
        .scaleEffect(isSelected ? 1.05 : 1.0)
        .animation(.easeInOut(duration: 0.2), value: isSelected)
    }
}

// MARK: - Notification Extensions
extension Notification.Name {
    static let hotkeySettingsChanged = Notification.Name("hotkeySettingsChanged")
    static let menuBarIconVisibilityChanged = Notification.Name("menuBarIconVisibilityChanged")
}

#Preview {
    PreferencesView()
}
