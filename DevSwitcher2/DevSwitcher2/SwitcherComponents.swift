//
//  SwitcherComponents.swift
//  DevSwitcher2
//
//  Created for componentizing switcher views
//

import SwiftUI
import Foundation
import AppKit

// MARK: - Switcher Type Enum
enum SwitcherType {
    case ds2  // DevSwitcher2 (same app window switching)
    case ct2  // Command+Tab enhanced (all app switching)
}

// MARK: - Switcher Configuration Protocol
protocol SwitcherConfig {
    var type: SwitcherType { get }
    var title: String { get }
}

// MARK: - App Info Data Structure
struct AppInfo {
    let bundleId: String
    let processID: pid_t
    let appName: String
    let firstWindow: WindowInfo?  // First window of this app
    let windowCount: Int         // Total window count of this app
    let isActive: Bool           // Whether it's the currently active app
    let lastUsedTime: Date?      // Last used time
    
    init(bundleId: String, processID: pid_t, appName: String, windows: [WindowInfo], isActive: Bool = false, lastUsedTime: Date? = nil) {
        self.bundleId = bundleId
        self.processID = processID
        self.appName = appName
        self.firstWindow = windows.first
        self.windowCount = windows.count
        self.isActive = isActive
        self.lastUsedTime = lastUsedTime
    }
}

// MARK: - DS2 Configuration
struct DS2Config: SwitcherConfig {
    let type: SwitcherType = .ds2
    let title: String = LocalizedStrings.windowSwitcherTitle
}

// MARK: - CT2 Configuration
struct CT2Config: SwitcherConfig {
    let type: SwitcherType = .ct2
    let title: String = LocalizedStrings.appSwitcherTitle
}

// MARK: - Generic Switcher View
struct BaseSwitcherView<ItemType>: View {
    let config: SwitcherConfig
    let items: [ItemType]
    let currentIndex: Int
    let onItemSelect: (Int) -> Void
    let itemContentBuilder: (ItemType, Bool, Bool) -> AnyView
    
    @State private var hoveredIndex: Int? = nil
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            itemListView
        }
        .background(.ultraThinMaterial)
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.1), radius: 20, x: 0, y: 10)
        .frame(maxWidth: 600, maxHeight: 400)
    }
    
    // MARK: - Header View
    private var headerView: some View {
        HStack {
            Image(systemName: headerIcon)
//                .symbolEffect(.breathe.plain.byLayer, options: .repeat(.continuous))
                .foregroundColor(.accentColor)
                .font(.title2)
            
            Text(config.title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.regularMaterial)
    }
    
    // MARK: - Item List View
    private var itemListView: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                        Button(action: {
                            onItemSelect(index)
                        }) {
                            itemContentBuilder(
                                item,
                                index == currentIndex,
                                index == hoveredIndex
                            )
                        }
                        .buttonStyle(PlainButtonStyle())
                        .background(backgroundColorForIndex(index))
                        .id(index) // Add ID for scroll positioning
                        .onHover { isHovering in
                            hoveredIndex = isHovering ? index : nil
                        }
                    }
                }
            }
            .background(.ultraThinMaterial)
            .onChange(of: currentIndex) { newIndex in
                // Auto scroll to item when selection changes
                // Use shorter animation time to support fast switching
                withAnimation(.easeOut(duration: 0.15)) {
                    proxy.scrollTo(newIndex, anchor: .center)
                }
            }
            .onAppear {
                // Scroll to current selected item on initial display
                if currentIndex < items.count {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            proxy.scrollTo(currentIndex, anchor: .center)
                        }
                    }
                }
            }
        }
    }
    
    
    // MARK: - Helper Methods
    private var headerIcon: String {
        switch config.type {
        case .ds2:
            return "rectangle.2.swap"
        case .ct2:
            return "rectangle.3.group"
        }
    }
    
    private func backgroundColorForIndex(_ index: Int) -> Color {
        if index == currentIndex {
            return Color.accentColor.opacity(0.15)
        } else if index == hoveredIndex {
            return Color.accentColor.opacity(0.05)
        } else {
            return Color.clear
        }
    }
}

// MARK: - Window Item Content View
struct WindowItemContentView: View {
    let window: WindowInfo
    let isSelected: Bool
    let isHovered: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // App icon
            AppIconView(processID: window.processID)
                .frame(width: 48, height: 48)
            
            VStack(alignment: .leading, spacing: 4) {
                // Project name (main display)
                Text(window.projectName)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // App name
                Text(window.appName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                // Full window title (auxiliary info)
                if window.title != window.projectName {
                    Text(window.title)
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Selection indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.title3)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - App Item Content View
struct AppItemContentView: View {
    let app: AppInfo
    let isSelected: Bool
    let isHovered: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // App icon
            AppIconView(processID: app.processID)
                .frame(width: 48, height: 48)
            
            VStack(alignment: .leading, spacing: 4) {
                // App name (main display)
                Text(app.appName)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // Window count info
                if app.windowCount > 1 {
                    Text(LocalizedStrings.multipleWindows(app.windowCount))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                } else {
                    Text(LocalizedStrings.singleWindow)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                // If there's a first window, show its title as auxiliary info
                if let firstWindow = app.firstWindow, !firstWindow.projectName.isEmpty {
                    Text(firstWindow.projectName)
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // Selection indicator
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
                    .font(.title3)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

// MARK: - DS2 Switcher View (Using Generic Components)
struct DS2SwitcherView: View {
    @ObservedObject var windowManager: WindowManager
    
    var body: some View {
        BaseSwitcherView(
            config: DS2Config(),
            items: windowManager.windows,
            currentIndex: windowManager.currentWindowIndex,
            onItemSelect: { index in
                windowManager.selectWindow(at: index)
            },
            itemContentBuilder: { window, isSelected, isHovered in
                AnyView(
                    WindowItemContentView(
                        window: window,
                        isSelected: isSelected,
                        isHovered: isHovered
                    )
                )
            }
        )
    }
}

// MARK: - CT2 Switcher View (Using Generic Components)
struct CT2SwitcherView: View {
    @ObservedObject var windowManager: WindowManager
    
    var body: some View {
        BaseSwitcherView(
            config: CT2Config(),
            items: windowManager.apps,
            currentIndex: windowManager.currentAppIndex,
            onItemSelect: { index in
                windowManager.selectApp(at: index)
            },
            itemContentBuilder: { app, isSelected, isHovered in
                AnyView(
                    AppItemContentView(
                        app: app,
                        isSelected: isSelected,
                        isHovered: isHovered
                    )
                )
            }
        )
    }
}
