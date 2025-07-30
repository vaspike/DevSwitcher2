//
//  InstalledAppsManager.swift
//  DevSwitcher2
//
//  Created by river on 2025-07-30.
//

import Foundation
import AppKit

struct InstalledAppInfo {
    let bundleId: String
    let name: String
    let icon: NSImage?
    let path: String
    
    init(bundleId: String, name: String, icon: NSImage? = nil, path: String) {
        self.bundleId = bundleId
        self.name = name
        self.icon = icon
        self.path = path
    }
}

// 不再使用单例模式，每次配置窗口打开时创建新实例
class InstalledAppsManager: ObservableObject {
    @Published var installedApps: [InstalledAppInfo] = []
    @Published var isLoading = false
    
    private var loadTask: Task<Void, Never>?
    
    init() {
        // 移除自动加载，改为按需加载
    }
    
    deinit {
        // 取消正在进行的任务
        loadTask?.cancel()
        Logger.log("🗑️ InstalledAppsManager deallocated")
    }
    
    func loadInstalledApps() {
        // 如果已经在加载或已经有数据，不重复加载
        guard !isLoading && installedApps.isEmpty else { return }
        
        isLoading = true
        Logger.log("📱 Starting to load installed applications...")
        
        // 使用Task来支持取消操作
        loadTask = Task { @MainActor in
            do {
                let apps = await loadAppsInBackground()
                
                // 检查任务是否被取消
                guard !Task.isCancelled else {
                    Logger.log("📱 App loading task was cancelled")
                    return
                }
                
                self.installedApps = apps
                self.isLoading = false
                Logger.log("📱 Successfully loaded \(apps.count) applications")
            } catch {
                Logger.log("❌ Failed to load applications: \(error)")
                self.isLoading = false
            }
        }
    }
    
    // 清理资源
    func cleanup() {
        loadTask?.cancel()
        installedApps.removeAll()
        Logger.log("🧹 InstalledAppsManager cleaned up")
    }
    
    private func loadAppsInBackground() async -> [InstalledAppInfo] {
        return await withTaskGroup(of: [InstalledAppInfo].self) { group in
            var allApps: [InstalledAppInfo] = []
            
            // 并行加载不同来源的应用
            
            // 1. 加载运行中的应用（最快，优先显示）
            group.addTask {
                await self.getRunningApps()
            }
            
            // 2. 加载用户应用目录
            group.addTask {
                await self.getAppsFromDirectories(["/Applications"])
            }
            
            // 3. 加载系统应用目录（可能较慢）
            group.addTask {
                await self.getAppsFromDirectories(["/System/Applications"])
            }
            
            // 4. 加载用户家目录下的应用
            group.addTask {
                if let userAppsPath = FileManager.default.urls(for: .applicationDirectory, in: .userDomainMask).first?.path {
                    return await self.getAppsFromDirectories([userAppsPath])
                }
                return []
            }
            
            // 收集所有结果
            for await apps in group {
                allApps.append(contentsOf: apps)
            }
            
            // 去重并排序
            let uniqueApps = self.removeDuplicatesAndSort(allApps)
            return uniqueApps
        }
    }
    
    private func getRunningApps() async -> [InstalledAppInfo] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var apps: [InstalledAppInfo] = []
                
                let runningApps = NSWorkspace.shared.runningApplications
                for runningApp in runningApps {
                    // 检查任务是否被取消
                    guard !Task.isCancelled else {
                        continuation.resume(returning: [])
                        return
                    }
                    
                    guard let bundleId = runningApp.bundleIdentifier,
                          let appName = runningApp.localizedName,
                          !bundleId.isEmpty,
                          runningApp.activationPolicy == .regular else {
                        continue
                    }
                    
                    let appPath = runningApp.bundleURL?.path ?? ""
                    // 对于运行中的应用，图标通常已经在内存中，获取速度较快
                    let appIcon = runningApp.icon
                    
                    let appInfo = InstalledAppInfo(
                        bundleId: bundleId,
                        name: appName,
                        icon: appIcon,
                        path: appPath
                    )
                    apps.append(appInfo)
                }
                
                continuation.resume(returning: apps)
            }
        }
    }
    
    private func getAppsFromDirectories(_ directories: [String]) async -> [InstalledAppInfo] {
        return await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .utility).async {
                var allApps: [InstalledAppInfo] = []
                
                for directory in directories {
                    // 检查任务是否被取消
                    guard !Task.isCancelled else {
                        continuation.resume(returning: [])
                        return
                    }
                    
                    let apps = self.getAppsFromDirectory(directory)
                    allApps.append(contentsOf: apps)
                    
                    // 每处理完一个目录就检查一次取消状态
                    if Task.isCancelled {
                        continuation.resume(returning: [])
                        return
                    }
                }
                
                continuation.resume(returning: allApps)
            }
        }
    }
    
    private func getAppsFromDirectory(_ directoryPath: String) -> [InstalledAppInfo] {
        var apps: [InstalledAppInfo] = []
        
        guard FileManager.default.fileExists(atPath: directoryPath) else {
            return apps
        }
        
        do {
            let contents = try FileManager.default.contentsOfDirectory(atPath: directoryPath)
            
            for fileName in contents {
                // 检查任务是否被取消
                guard !Task.isCancelled else { break }
                
                if fileName.hasSuffix(".app") {
                    let appPath = "\(directoryPath)/\(fileName)"
                    
                    // 优化：先快速检查基本信息，延迟加载图标
                    if let appInfo = getAppInfoOptimized(from: appPath) {
                        apps.append(appInfo)
                    }
                }
            }
        } catch {
            Logger.log("⚠️ Failed to read directory \(directoryPath): \(error)")
        }
        
        return apps
    }
    
    private func getAppInfoOptimized(from appPath: String) -> InstalledAppInfo? {
        let bundleURL = URL(fileURLWithPath: appPath)
        
        guard let bundle = Bundle(url: bundleURL),
              let bundleId = bundle.bundleIdentifier else {
            return nil
        }
        
        // 快速获取应用名称
        let appName = bundle.localizedInfoDictionary?["CFBundleDisplayName"] as? String ??
                     bundle.infoDictionary?["CFBundleDisplayName"] as? String ??
                     bundle.localizedInfoDictionary?["CFBundleName"] as? String ??
                     bundle.infoDictionary?["CFBundleName"] as? String ??
                     bundleURL.deletingPathExtension().lastPathComponent
        
        // 延迟加载图标 - 只为前50个应用加载图标以提高性能
        var appIcon: NSImage? = nil
        
        // 可以考虑只为常用应用加载图标，或者使用更轻量的图标获取方式
        if shouldLoadIcon(for: bundleId) {
            appIcon = NSWorkspace.shared.icon(forFile: appPath)
        }
        
        return InstalledAppInfo(
            bundleId: bundleId,
            name: appName,
            icon: appIcon,
            path: appPath
        )
    }
    
    private func shouldLoadIcon(for bundleId: String) -> Bool {
        // 为常用应用优先加载图标
        let commonApps = [
            "com.apple.dt.Xcode",
            "com.microsoft.VSCode",
            "com.todesktop.230313mzl4w4u92", // Cursor
            "com.apple.Safari",
            "com.google.Chrome",
            "com.apple.finder",
            "com.apple.mail",
            "com.apple.notes",
            "com.apple.calculator",
            "com.apple.systempreferences",
            "com.jetbrains.intellij",
            "com.sublimetext.4",
            "com.figma.Desktop"
        ]
        
        return commonApps.contains(bundleId)
    }
    
    private func removeDuplicatesAndSort(_ apps: [InstalledAppInfo]) -> [InstalledAppInfo] {
        let uniqueApps = Dictionary(grouping: apps, by: { $0.bundleId })
            .compactMapValues { appGroup in
                // 优先选择有图标的版本
                return appGroup.first { $0.icon != nil } ?? appGroup.first
            }
            .values
            .sorted { app1, app2 in
                // 有图标的应用排在前面
                if app1.icon != nil && app2.icon == nil {
                    return true
                } else if app1.icon == nil && app2.icon != nil {
                    return false
                } else {
                    return app1.name.localizedCaseInsensitiveCompare(app2.name) == .orderedAscending
                }
            }
        
        return Array(uniqueApps)
    }
    
    // 搜索应用的功能
    func searchApps(query: String) -> [InstalledAppInfo] {
        guard !query.isEmpty else { return installedApps }
        
        return installedApps.filter { app in
            app.name.localizedCaseInsensitiveContains(query) ||
            app.bundleId.localizedCaseInsensitiveContains(query)
        }
    }
    
    // 懒加载图标 - 当应用即将显示时才加载图标
    func loadIconIfNeeded(for app: InstalledAppInfo) -> InstalledAppInfo {
        guard app.icon == nil else { return app }
        
        let icon = NSWorkspace.shared.icon(forFile: app.path)
        return InstalledAppInfo(
            bundleId: app.bundleId,
            name: app.name,
            icon: icon,
            path: app.path
        )
    }
}