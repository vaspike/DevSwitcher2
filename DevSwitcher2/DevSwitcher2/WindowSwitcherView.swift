//
//  WindowSwitcherView.swift
//  DevSwitcher2
//
//  Created by river on 2025-07-26.
//

import SwiftUI
import Foundation

struct WindowSwitcherView: View {
    @ObservedObject var windowManager: WindowManager
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            Divider()
            windowListView
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
            Image(systemName: "rectangle.3.group")
                .foregroundColor(.accentColor)
                .font(.title2)
            
            Text(LocalizedStrings.windowSwitcherTitle)
                .font(.headline)
                .foregroundColor(.primary)
            
            Spacer()
            
            Text(LocalizedStrings.hotkeyHint)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(.regularMaterial)
    }
    
    // MARK: - Window List View
    private var windowListView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(windowManager.windows.enumerated()), id: \.offset) { index, window in
                    WindowRowView(
                        window: window,
                        isSelected: index == windowManager.currentWindowIndex,
                        onTap: {
                            windowManager.selectWindow(at: index)
                        }
                    )
                    .background(index == windowManager.currentWindowIndex ? 
                              Color.accentColor.opacity(0.1) : Color.clear)
                    .onHover { isHovering in
                        if isHovering {
                            windowManager.currentWindowIndex = index
                        }
                    }
                }
            }
        }
        .background(.ultraThinMaterial)
    }
    
    // MARK: - Footer View
    private var footerView: some View {
        HStack {
            Label(LocalizedStrings.cancelHint, systemImage: "escape")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Label(LocalizedStrings.selectHint, systemImage: "return")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.regularMaterial)
    }
}

struct WindowRowView: View {
    let window: WindowInfo
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // 应用图标占位符
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.2))
                    .frame(width: 48, height: 48)
                    .overlay(
                        Image(systemName: "app.dashed")
                            .foregroundColor(.accentColor)
                            .font(.title2)
                    )
                
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
        .buttonStyle(PlainButtonStyle())
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
    }
}

#Preview {
    WindowSwitcherView(windowManager: {
        let manager = WindowManager()
        manager.windows = [
            WindowInfo(windowID: 1, title: "main.swift — DevSwitcher2 — Edited", projectName: "DevSwitcher2", appName: "Xcode", processID: 1234, axWindowIndex: 0),
            WindowInfo(windowID: 2, title: "README.md - MyProject", projectName: "MyProject", appName: "VS Code", processID: 5678, axWindowIndex: 1),
            WindowInfo(windowID: 3, title: "[WebApp] - index.html", projectName: "WebApp", appName: "IntelliJ IDEA", processID: 9012, axWindowIndex: 2)
        ]
        return manager
    }())
    .frame(width: 600, height: 400)
} 