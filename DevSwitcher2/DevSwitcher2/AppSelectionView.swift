//
//  AppSelectionView.swift
//  DevSwitcher2
//
//  Created by river on 2025-07-30.
//

import SwiftUI
import AppKit

struct AppSelectionView: View {
    @Binding var selectedApp: InstalledAppInfo?
    @Binding var bundleId: String
    @Binding var appName: String
    
    // 使用本地实例而非单例，配置窗口关闭时自动释放
    @StateObject private var appsManager = InstalledAppsManager()
    @State private var isDropdownExpanded = false
    @State private var searchText = ""
    @State private var hoveredAppId: String? = nil
    
    private var filteredApps: [InstalledAppInfo] {
        if searchText.isEmpty {
            return appsManager.installedApps
        } else {
            return appsManager.searchApps(query: searchText)
        }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(LocalizedStrings.selectFromInstalledApps)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            ZStack {
                // 主按钮
                Button(action: {
                    toggleDropdown()
                }) {
                    HStack {
                        if let selectedApp = selectedApp {
                            // 显示选中的应用
                            HStack(spacing: 8) {
                                if let icon = selectedApp.icon {
                                    Image(nsImage: icon)
                                        .resizable()
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 20, height: 20)
                                } else {
                                    Image(systemName: "app.fill")
                                        .frame(width: 20, height: 20)
                                        .foregroundColor(.secondary)
                                }
                                
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(selectedApp.name)
                                        .font(.body)
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    
                                    Text(selectedApp.bundleId)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                        .lineLimit(1)
                                }
                            }
                        } else {
                            // 默认状态
                            HStack(spacing: 8) {
                                Image(systemName: "app.fill")
                                    .frame(width: 20, height: 20)
                                    .foregroundColor(.secondary)
                                
                                Text(LocalizedStrings.selectApplicationPlaceholder)
                                    .foregroundColor(.secondary)
                            }
                        }
                        
                        Spacer()
                        
                        // 下拉箭头或加载指示器
                        if appsManager.isLoading && isDropdownExpanded {
                            ProgressView()
                                .scaleEffect(0.6)
                        } else {
                            Image(systemName: isDropdownExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption)
                                .foregroundColor(.secondary)
                                .animation(.easeInOut(duration: 0.2), value: isDropdownExpanded)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 6)
                            .fill(Color(NSColor.controlBackgroundColor))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                            )
                    )
                }
                .buttonStyle(PlainButtonStyle())
                
                // 下拉列表
                if isDropdownExpanded {
                    VStack(spacing: 0) {
                        Spacer()
                            .frame(height: 44) // 为主按钮留空间
                        
                        VStack(spacing: 0) {
                            // 搜索框
                            HStack {
                                Image(systemName: "magnifyingglass")
                                    .foregroundColor(.secondary)
                                    .font(.system(size: 14))
                                
                                TextField(LocalizedStrings.searchApplications, text: $searchText)
                                    .textFieldStyle(PlainTextFieldStyle())
                                    .font(.body)
                                
                                if !searchText.isEmpty {
                                    Button(action: {
                                        searchText = ""
                                    }) {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundColor(.secondary)
                                            .font(.system(size: 14))
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color(NSColor.controlBackgroundColor))
                            
                            Divider()
                            
                            // 应用列表
                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    if appsManager.isLoading {
                                        LoadingView()
                                    } else if filteredApps.isEmpty {
                                        EmptyStateView(searchText: searchText)
                                    } else {
                                        AppListView(
                                            apps: Array(filteredApps.prefix(50)),
                                            hoveredAppId: $hoveredAppId,
                                            onSelectApp: selectApp
                                        )
                                        
                                        if filteredApps.count > 50 {
                                            Text(LocalizedStrings.moreThan50Results)
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                                .padding(.vertical, 8)
                                        }
                                    }
                                }
                            }
                            .frame(maxHeight: 250)
                        }
                        .background(
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color(NSColor.controlBackgroundColor))
                                .shadow(color: .black.opacity(0.15), radius: 8, x: 0, y: 4)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 6)
                                        .stroke(Color(NSColor.separatorColor), lineWidth: 1)
                                )
                        )
                    }
                    .zIndex(1)
                }
            }
        }
        .onDisappear {
            // 视图消失时清理资源
            appsManager.cleanup()
        }
        .onTapGesture {
            // 点击外部关闭下拉菜单
            if isDropdownExpanded {
                closeDropdown()
            }
        }
    }
    
    private func toggleDropdown() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isDropdownExpanded.toggle()
        }
        
        // 首次打开时才开始加载应用
        if isDropdownExpanded && appsManager.installedApps.isEmpty {
            appsManager.loadInstalledApps()
        }
    }
    
    private func closeDropdown() {
        withAnimation(.easeInOut(duration: 0.2)) {
            isDropdownExpanded = false
        }
    }
    
    private func selectApp(_ app: InstalledAppInfo) {
        selectedApp = app
        bundleId = app.bundleId
        appName = app.name
        
        closeDropdown()
        
        // 清空搜索
        searchText = ""
    }
}

// MARK: - 子视图组件

struct LoadingView: View {
    var body: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            VStack(alignment: .leading, spacing: 4) {
                Text(LocalizedStrings.loading)
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(LocalizedStrings.loadingAppsHint)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

struct EmptyStateView: View {
    let searchText: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: searchText.isEmpty ? "app.dashed" : "magnifyingglass")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Text(searchText.isEmpty ? LocalizedStrings.noApplicationsFound : LocalizedStrings.noSearchResults)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding()
    }
}

struct AppListView: View {
    let apps: [InstalledAppInfo]
    @Binding var hoveredAppId: String?
    let onSelectApp: (InstalledAppInfo) -> Void
    
    var body: some View {
        ForEach(apps, id: \.bundleId) { app in
            AppRowView(
                app: app,
                isHovered: hoveredAppId == app.bundleId,
                onSelect: { onSelectApp(app) }
            )
            .onHover { isHovered in
                hoveredAppId = isHovered ? app.bundleId : nil
            }
            
            if app.bundleId != apps.last?.bundleId {
                Divider()
            }
        }
    }
}

struct AppRowView: View {
    let app: InstalledAppInfo
    let isHovered: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 10) {
                // 应用图标 - 懒加载优化
                if let icon = app.icon {
                    Image(nsImage: icon)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 24, height: 24)
                } else {
                    // 占位图标
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.secondary.opacity(0.2))
                        .frame(width: 24, height: 24)
                        .overlay(
                            Image(systemName: "app.fill")
                                .font(.system(size: 12))
                                .foregroundColor(.secondary)
                        )
                }
                
                // 应用信息
                VStack(alignment: .leading, spacing: 2) {
                    Text(app.name)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    Text(app.bundleId)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
                
                Spacer()
                
                // 选择指示器
                if isHovered {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(
                isHovered ? Color.accentColor.opacity(0.1) : Color.clear
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(PlainButtonStyle())
    }
}