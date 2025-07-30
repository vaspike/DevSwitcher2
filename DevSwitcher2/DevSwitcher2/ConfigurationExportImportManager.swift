//
//  ConfigurationExportImportManager.swift
//  DevSwitcher2
//
//  Created by river on 2025-07-30.
//

import Foundation
import AppKit

// MARK: - 导出/导入数据结构

struct ExportedConfiguration: Codable {
    let version: String
    let exportDate: String
    let appTitleConfigs: [AppTitleConfig]
    
    // 元数据
    struct Metadata: Codable {
        let appVersion: String
        let systemVersion: String
        let totalConfigs: Int
    }
    
    let metadata: Metadata
    
    init(appTitleConfigs: [AppTitleConfig]) {
        self.version = "1.0"
        self.exportDate = ISO8601DateFormatter().string(from: Date())
        self.appTitleConfigs = appTitleConfigs
        self.metadata = Metadata(
            appVersion: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "Unknown",
            systemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            totalConfigs: appTitleConfigs.count
        )
    }
}

// MARK: - 导入结果

struct ImportResult {
    let totalImported: Int
    let newConfigs: Int
    let updatedConfigs: Int
    let errors: [String]
    
    var isSuccess: Bool {
        return errors.isEmpty && totalImported > 0
    }
    
    var isEmpty: Bool {
        return totalImported == 0
    }
}

// MARK: - 配置导出/导入管理器

class ConfigurationExportImportManager: ObservableObject {
    @Published var isProcessing = false
    private let settingsManager = SettingsManager.shared
    
    // MARK: - 导出功能
    
    func exportConfiguration() -> Result<String, Error> {
        do {
            let configs = Array(settingsManager.settings.appTitleConfigs.values)
            let exportedConfig = ExportedConfiguration(appTitleConfigs: configs)
            
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            encoder.dateEncodingStrategy = .iso8601
            
            let jsonData = try encoder.encode(exportedConfig)
            guard let jsonString = String(data: jsonData, encoding: .utf8) else {
                throw ConfigurationError.encodingFailed
            }
            
            Logger.log("📤 Successfully exported \(configs.count) configurations")
            return .success(jsonString)
            
        } catch {
            Logger.log("❌ Export failed: \(error)")
            return .failure(error)
        }
    }
    
    func saveConfigurationToFile() -> Result<URL, Error> {
        switch exportConfiguration() {
        case .success(let jsonString):
            return saveJSONToFile(jsonString)
        case .failure(let error):
            return .failure(error)
        }
    }
    
    private func saveJSONToFile(_ jsonString: String) -> Result<URL, Error> {
        let savePanel = NSSavePanel()
        savePanel.title = LocalizedStrings.exportConfiguration
        savePanel.message = LocalizedStrings.chooseExportLocation
        savePanel.nameFieldLabel = LocalizedStrings.fileName
        savePanel.nameFieldStringValue = generateExportFileName()
        savePanel.allowedContentTypes = [.json]
        savePanel.canCreateDirectories = true
        
        let response = savePanel.runModal()
        guard response == .OK, let url = savePanel.url else {
            return .failure(ConfigurationError.userCancelled)
        }
        
        do {
            try jsonString.write(to: url, atomically: true, encoding: .utf8)
            Logger.log("💾 Configuration saved to: \(url.path)")
            return .success(url)
        } catch {
            Logger.log("❌ Failed to save file: \(error)")
            return .failure(error)
        }
    }
    
    private func generateExportFileName() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
        let timestamp = formatter.string(from: Date())
        return "DevSwitcher2_Config_\(timestamp).json"
    }
    
    // MARK: - 导入功能
    
    func importConfigurationFromFile() -> Result<ImportResult, Error> {
        let openPanel = NSOpenPanel()
        openPanel.title = LocalizedStrings.importConfiguration
        openPanel.message = LocalizedStrings.chooseImportFile
        openPanel.allowedContentTypes = [.json]
        openPanel.allowsMultipleSelection = false
        openPanel.canChooseDirectories = false
        openPanel.canChooseFiles = true
        
        let response = openPanel.runModal()
        guard response == .OK, let url = openPanel.urls.first else {
            return .failure(ConfigurationError.userCancelled)
        }
        
        return importConfigurationFromURL(url)
    }
    
    func importConfigurationFromURL(_ url: URL) -> Result<ImportResult, Error> {
        do {
            let jsonData = try Data(contentsOf: url)
            return importConfigurationFromData(jsonData)
        } catch {
            Logger.log("❌ Failed to read file: \(error)")
            return .failure(ConfigurationError.fileReadFailed(error))
        }
    }
    
    func importConfigurationFromData(_ jsonData: Data) -> Result<ImportResult, Error> {
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let exportedConfig = try decoder.decode(ExportedConfiguration.self, from: jsonData)
            
            Logger.log("📥 Importing \(exportedConfig.appTitleConfigs.count) configurations from export version \(exportedConfig.version)")
            
            let result = mergeConfigurations(exportedConfig.appTitleConfigs)
            
            if result.isSuccess {
                settingsManager.saveSettings()
                Logger.log("✅ Import completed: \(result.newConfigs) new, \(result.updatedConfigs) updated")
            }
            
            return .success(result)
            
        } catch {
            Logger.log("❌ Import failed: \(error)")
            return .failure(ConfigurationError.decodingFailed(error))
        }
    }
    
    private func mergeConfigurations(_ importedConfigs: [AppTitleConfig]) -> ImportResult {
        var newConfigs = 0
        var updatedConfigs = 0
        var errors: [String] = []
        
        for config in importedConfigs {
            do {
                if settingsManager.settings.appTitleConfigs[config.bundleId] != nil {
                    // 更新现有配置
                    settingsManager.setAppTitleConfig(config)
                    updatedConfigs += 1
                    Logger.log("🔄 Updated config for: \(config.appName) (\(config.bundleId))")
                } else {
                    // 添加新配置
                    settingsManager.setAppTitleConfig(config)
                    newConfigs += 1
                    Logger.log("➕ Added new config for: \(config.appName) (\(config.bundleId))")
                }
            } catch {
                let errorMsg = "Failed to import \(config.appName): \(error.localizedDescription)"
                errors.append(errorMsg)
                Logger.log("❌ \(errorMsg)")
            }
        }
        
        return ImportResult(
            totalImported: newConfigs + updatedConfigs,
            newConfigs: newConfigs,
            updatedConfigs: updatedConfigs,
            errors: errors
        )
    }
    
    // MARK: - 工具方法
    
    func validateConfigurationFile(_ url: URL) -> Result<ExportedConfiguration.Metadata, Error> {
        do {
            let jsonData = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            
            let exportedConfig = try decoder.decode(ExportedConfiguration.self, from: jsonData)
            return .success(exportedConfig.metadata)
        } catch {
            return .failure(ConfigurationError.invalidFormat(error))
        }
    }
}

// MARK: - 错误类型

enum ConfigurationError: LocalizedError {
    case encodingFailed
    case decodingFailed(Error)
    case fileReadFailed(Error)
    case invalidFormat(Error)
    case userCancelled
    
    var errorDescription: String? {
        switch self {
        case .encodingFailed:
            return LocalizedStrings.exportEncodingError
        case .decodingFailed(let error):
            return LocalizedStrings.importDecodingError + ": \(error.localizedDescription)"
        case .fileReadFailed(let error):
            return LocalizedStrings.fileReadError + ": \(error.localizedDescription)"
        case .invalidFormat(let error):
            return LocalizedStrings.invalidFileFormat + ": \(error.localizedDescription)"
        case .userCancelled:
            return LocalizedStrings.operationCancelled
        }
    }
}