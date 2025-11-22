//
//  LinkUApp.swift
//  LinkU
//
//  Created on 2025-01-20.
//

import SwiftUI

@main
struct LinkUApp: App {
    @StateObject private var authViewModel = AuthViewModel()
    @StateObject private var appState = AppState()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authViewModel)
                .environmentObject(appState)
                .onAppear {
                    // 初始化推送通知
                    NotificationManager.shared.requestAuthorization()
                }
        }
    }
}

