//
//  NexusVPNApp.swift
//  NexusVPN
//
//  Created by ersao on 2026/1/8.
//

import SwiftUI
import AppTrackingTransparency

@main
struct NexusVPNApp: App {
    @StateObject private var viewModel = HomeSessionViewModel()
    @StateObject private var languageManager = AppLanguageManager.shared
    @State private var showSplash: Bool = true
    @State private var hasAcceptedPrivacy: Bool = UserDefaults.standard.bool(
        forKey: "NexusVPN.PrivacyAccepted"
    )
    
    @Environment(\.scenePhase) private var scenePhase
    
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
            .onChange(of: scenePhase) { newPhase in
                processScenePhaseChange(newPhase)
            }
        }
    }
    
    // MARK: - App lifecycle & ATT
    
    private func processScenePhaseChange(_ newPhase: ScenePhase) {
        switch newPhase {
        case .active:
            requestAppTrackingAuthorization()
        case .inactive, .background:
            break
        @unknown default:
            break
        }
    }
    
    /// App 切回前台时触发一次 ATT 权限请求（仅 iOS 14+）
    private func requestAppTrackingAuthorization() {
        guard #available(iOS 14, *) else { return }
        
        // 延迟一点时间，确保应用完全启动
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            ATTrackingManager.requestTrackingAuthorization { status in
                switch status {
                case .authorized:
                    NVLog.log("ATT", "Tracking authorized")
                case .denied:
                    NVLog.log("ATT", "Tracking denied")
                case .notDetermined:
                    NVLog.log("ATT", "Tracking not determined")
                case .restricted:
                    NVLog.log("ATT", "Tracking restricted")
                @unknown default:
                    NVLog.log("ATT", "Tracking unknown status")
                }
            }
        }
    }
}
