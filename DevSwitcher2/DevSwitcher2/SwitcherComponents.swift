//
//  SwitcherComponents.swift
//  DevSwitcher2
//
//  Created for componentizing switcher views
//

import SwiftUI
import Foundation

// MARK: - 切换器类型枚举
enum SwitcherType {
    case ds2  // DevSwitcher2 (同应用窗口切换)
    case ct2  // Command+Tab 增强 (所有应用切换)
}

// MARK: - 切换器配置协议
protocol SwitcherConfig {
    var type: SwitcherType { get }
    var title: String { get }
    var hotkeyHint: String { get }
    var cancelHint: String { get }
    var selectHint: String { get }
}

// MARK: - DS2配置
struct DS2Config: SwitcherConfig {
    let type: SwitcherType = .ds2
    let title: String = LocalizedStrings.windowSwitcherTitle
    let hotkeyHint: String = LocalizedStrings.hotkeyHint
    let cancelHint: String = LocalizedStrings.cancelHint
    let selectHint: String = LocalizedStrings.selectHint
}

// MARK: - 通用切换器视图
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
            footerView
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
                .symbolEffect(.breathe.plain.byLayer, options: .repeat(.continuous))
                .foregroundColor(.accentColor)
                .font(.title2)
            
            Text(config.title)
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(config.hotkeyHint)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.regularMaterial)
    }
    
    // MARK: - Item List View
    private var itemListView: some View {
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
                    .onHover { isHovering in
                        hoveredIndex = isHovering ? index : nil
                    }
                }
            }
        }
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Footer View
    private var footerView: some View {
        HStack {
            Label(config.cancelHint, systemImage: "escape")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Label(config.selectHint, systemImage: "return")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }
    
    // MARK: - Helper Methods
    private var headerIcon: String {
        switch config.type {
        case .ds2:
            return "rectangle.2.swap"
        case .ct2:
            return "switch.2"
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

// MARK: - 窗口项内容视图
struct WindowItemContentView: View {
    let window: WindowInfo
    let isSelected: Bool
    let isHovered: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // 应用图标
            AppIconView(processID: window.processID)
                .frame(width: 48, height: 48)
            
            VStack(alignment: .leading, spacing: 4) {
                // 项目名（主要显示）
                Text(window.projectName)
                    .font(.headline)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                
                // 应用名称
                Text(window.appName)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                
                // 完整窗口标题（辅助信息）
                if window.title != window.projectName {
                    Text(window.title)
                        .font(.caption)
                        .foregroundColor(.secondary.opacity(0.7))
                        .lineLimit(1)
                }
            }
            
            Spacer()
            
            // 选中指示器
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

// MARK: - DS2切换器视图（使用通用组件）
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