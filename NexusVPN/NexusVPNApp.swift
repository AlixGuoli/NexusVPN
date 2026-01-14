//
//  NexusVPNApp.swift
//  NexusVPN
//
//  Created by ersao on 2026/1/8.
//

import SwiftUI

@main
struct NexusVPNApp: App {
    @StateObject private var viewModel = HomeSessionViewModel()
    @StateObject private var languageManager = AppLanguageManager.shared
    @State private var showSplash: Bool = true
    @State private var hasAcceptedPrivacy: Bool = UserDefaults.standard.bool(
        forKey: "NexusVPN.PrivacyAccepted"
    )
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(viewModel)
                    .environmentObject(languageManager)
                    .onAppear {
                        viewModel.initialize()
                    }
                
                // 启动页（只在首次进入期间覆盖）
                if showSplash {
                    SplashView {
                        showSplash = false
                    }
                    .environmentObject(viewModel)
                    .environmentObject(languageManager)
                    .ignoresSafeArea()
                }
                
                // 首次启动隐私页：启动页结束后再弹出
                if !showSplash && !hasAcceptedPrivacy {
                    NVPrivacyIntroView {
                        // 接受：记录标记，下次不再弹出
                        UserDefaults.standard.set(true, forKey: "NexusVPN.PrivacyAccepted")
                        hasAcceptedPrivacy = true
                    } onDecline: {
                        // 不同意：直接退出 App（符合业务要求）
                        exit(0)
                    }
                    .environmentObject(languageManager)
                    .ignoresSafeArea()
                }
            }
        }
    }
}
