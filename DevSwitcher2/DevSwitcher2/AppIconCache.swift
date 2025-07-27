//
//  AppIconCache.swift
//  DevSwitcher2
//
//  Created by river on 2025-07-27.
//

import Foundation
import AppKit

// MARK: - Cache Item Structure
private struct CacheItem {
    let icon: NSImage
    var lastAccessTime: Date
    
    init(icon: NSImage) {
        self.icon = icon
        self.lastAccessTime = Date()
    }
    
    mutating func updateAccessTime() {
        self.lastAccessTime = Date()
    }
}

// MARK: - App Icon Cache Manager
class AppIconCache: ObservableObject {
    static let shared = AppIconCache()
    
    // Cache configuration
    private let maxCacheSize = 50  // Max number of icons to cache
    private let cacheCleanupThreshold = 60  // Start cleanup when cache reaches this many icons
    
    // Use CacheItem to track access time for LRU implementation
    private var iconCache: [pid_t: CacheItem] = [:]
    private let cacheQueue = DispatchQueue(label: "com.devswitcher2.iconcache", qos: .utility)
    private var cleanupTimer: Timer? // Timer for periodic cleanup
    
    private init() {
        setupApplicationTerminationMonitoring()
        setupMemoryWarningMonitoring()
    }
    
    deinit {
        // Invalidate the timer
        cleanupTimer?.invalidate()
        cleanupTimer = nil
        
        // Remove notification observers
        NotificationCenter.default.removeObserver(self)
        
        Logger.log("🗑️ AppIconCache deinitialized, released \(iconCache.count) icons and related resources")
    }
    
    // MARK: - Public Interface
    
    // Helper function to resize an image, creating a thumbnail.
    private func resizeImage(_ image: NSImage, to size: NSSize) -> NSImage {
        let newImage = NSImage(size: size)
        newImage.lockFocus()
        image.draw(in: NSRect(origin: .zero, size: size),
                   from: NSRect(origin: .zero, size: image.size),
                   operation: .sourceOver,
                   fraction: 1.0)
        newImage.unlockFocus()
        // Ensure the image has a high-quality bitmap representation
        if let tiff = newImage.tiffRepresentation, let bitmap = NSBitmapImageRep(data: tiff) {
            return NSImage(data: bitmap.representation(using: .png, properties: [:])!) ?? newImage
        }
        return newImage
    }
    
    func getIcon(for processID: pid_t) -> NSImage? {
        return cacheQueue.sync {
            // If icon is in cache, update access time and return it
            if var cachedItem = iconCache[processID] {
                cachedItem.updateAccessTime()
                iconCache[processID] = cachedItem
                return cachedItem.icon
            }
            
            // Verify that the process still exists
            guard let app = NSRunningApplication(processIdentifier: processID),
                  let originalIcon = app.icon else {
                return nil
            }
            
            // Create a thumbnail to significantly reduce memory footprint
            let thumbnailSize = NSSize(width: 128, height: 128)
            let thumbnailIcon = resizeImage(originalIcon, to: thumbnailSize)
            
            // Check cache size before adding a new item
            checkAndCleanupCache()
            
            // Cache the new icon thumbnail
            iconCache[processID] = CacheItem(icon: thumbnailIcon)
            Logger.log("📦 Caching app icon thumbnail: \(app.localizedName ?? "Unknown") (PID: \(processID)), current cache size: \(iconCache.count)")
            
            return thumbnailIcon
        }
    }
    
    func clearCache() {
        cacheQueue.sync {
            let oldCount = iconCache.count
            iconCache.removeAll()
            Logger.log("🗑️ App icon cache cleared, released \(oldCount) icons")
        }
    }
    
    func getCacheInfo() -> (count: Int, maxSize: Int, dataSize: Int) {
        return cacheQueue.sync {
            // Calculate the total data size of all cached images
            let totalSize = iconCache.values.reduce(0) { (result, item) -> Int in
                // Estimate image data size using tiffRepresentation
                let imageSize = item.icon.tiffRepresentation?.count ?? 0
                return result + imageSize
            }
            return (count: iconCache.count, maxSize: maxCacheSize, dataSize: totalSize)
        }
    }
    
    // MARK: - Private Methods
    
    // Check cache size and clean up if necessary
    private func checkAndCleanupCache() {
        guard iconCache.count >= cacheCleanupThreshold else { return }
        
        Logger.log("🧹 Starting LRU cache cleanup, current size: \(iconCache.count)")
        
        // Sort entries by last access time, oldest first
        let sortedEntries = iconCache.sorted { $0.value.lastAccessTime < $1.value.lastAccessTime }
        
        // Keep the most recently accessed items up to maxCacheSize
        let itemsToKeep = Array(sortedEntries.suffix(maxCacheSize))
        var newCache: [pid_t: CacheItem] = [:]
        for (key, value) in itemsToKeep {
            newCache[key] = value
        }
        
        let removedCount = iconCache.count - newCache.count
        iconCache = newCache
        
        Logger.log("🧹 LRU cleanup finished, removed \(removedCount) icons, current size: \(iconCache.count)")
    }
    
    // Clean up icons for terminated processes
    private func cleanupTerminatedProcesses() {
        cacheQueue.async {
            let runningProcesses = Set(NSWorkspace.shared.runningApplications.map { $0.processIdentifier })
            let cachedProcesses = Set(self.iconCache.keys)
            let terminatedProcesses = cachedProcesses.subtracting(runningProcesses)
            
            for pid in terminatedProcesses {
                self.iconCache.removeValue(forKey: pid)
            }
            
            if !terminatedProcesses.isEmpty {
                Logger.log("🗑️ Cleaned up icons for terminated processes: \(terminatedProcesses.count), current cache size: \(self.iconCache.count)")
            }
        }
    }
    
    // MARK: - System Monitoring Setup
    
    private func setupApplicationTerminationMonitoring() {
        // Listen for application termination notifications
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(applicationDidTerminate(_:)),
            name: NSWorkspace.didTerminateApplicationNotification,
            object: nil
        )
        
        // Periodically clean up cache for terminated processes (every 30 seconds)
        cleanupTimer = Timer.scheduledTimer(withTimeInterval: 30.0, repeats: true) { [weak self] _ in
            self?.cleanupTerminatedProcesses()
        }
    }
    
    private func setupMemoryWarningMonitoring() {
        // Listen for memory pressure warnings (using system notifications)
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleMemoryWarning),
            name: NSApplication.didBecomeActiveNotification, // As an alternative, can also clean up periodically
            object: nil
        )
    }
    
    @objc private func applicationDidTerminate(_ notification: Notification) {
        guard let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else {
            return
        }
        
        cacheQueue.async {
            if self.iconCache.removeValue(forKey: app.processIdentifier) != nil {
                Logger.log("🗑️ Removed icon for terminated app: \(app.localizedName ?? "Unknown") (PID: \(app.processIdentifier))")
            }
        }
    }
    
    @objc private func handleMemoryWarning() {
        Logger.log("⚠️ Received memory warning, clearing icon cache")
        cacheQueue.async {
            // On memory warning, clear half of the cache
            let targetSize = max(self.maxCacheSize / 2, 10)
            let sortedEntries = self.iconCache.sorted { $0.value.lastAccessTime < $1.value.lastAccessTime }
            let itemsToKeep = Array(sortedEntries.suffix(targetSize))
            
            let oldCount = self.iconCache.count
            var newCache: [pid_t: CacheItem] = [:]
            for (key, value) in itemsToKeep {
                newCache[key] = value
            }
            self.iconCache = newCache
            
            Logger.log("⚠️ Memory warning cleanup finished, reduced from \(oldCount) to \(self.iconCache.count) icons")
        }
    }
}
