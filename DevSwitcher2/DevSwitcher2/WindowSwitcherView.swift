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
        DS2SwitcherView(windowManager: windowManager)
    }
}


struct AppIconView: View {
    let processID: pid_t
    @StateObject private var iconCache = AppIconCache.shared
    
    var body: some View {
        Group {
            if let icon = iconCache.getIcon(for: processID) {
                Image(nsImage: icon)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.accentColor.opacity(0.2))
                    .overlay(
                        Image(systemName: "app.dashed")
                            .foregroundColor(.accentColor)
                            .font(.title2)
                    )
            }
        }
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
