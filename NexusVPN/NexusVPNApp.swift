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
    @UIApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var viewModel = HomeSessionViewModel()
    @StateObject private var languageManager = AppLanguageManager.shared
    @State private var showSplash: Bool = true
    @State private var hasAcceptedPrivacy: Bool = UserDefaults.standard.bool(
        forKey: "NexusVPN.PrivacyAccepted"
    )
    @State private var resumeOverlayActive: Bool = false
    @State private var backgroundFlag: Bool = false
    
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
                
                // 启动页（20 秒超时，有网络拉配置+广告，无网络不拉；有广告走 onFinishWithAd，否则 onFinish）
                if showSplash {
                    SplashView(
                        onFinish: { showSplash = false },
                        onFinishWithAd: {
                            showSplash = false
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                // 与原项目一致：仅隐私同意后才展示启动广告
                                guard UserDefaults.standard.bool(forKey: "NexusVPN.PrivacyAccepted") else {
                                    NVLog.log("Ads", "隐私未同意，跳过展示")
                                    return
                                }
                                _ = AdMixer.shared.presentTopPriorityIfAvailable(from: nil, cue: .launch)
                            }
                        }
                    )
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
                
                // 后台切回前台覆盖页（2s 后尝试展示广告，3s 后自动关闭）
                if resumeOverlayActive {
                    ReturnOverlayView()
                        .background(Color(UIColor.systemBackground).opacity(1.0))
                        .ignoresSafeArea()
                        .onAppear {
                            NVLog.log("Ads", "后台覆盖页显示")
                            DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                                presentReturnOverlayAd()
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                                resumeOverlayActive = false
                            }
                        }
                        .zIndex(9999)
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
            handleForegroundReturn()
        case .inactive:
            break
        case .background:
            NVLog.log("App", "切后台")
            backgroundFlag = true
        @unknown default:
            break
        }
    }
    
    // MARK: - 后台切前台
    
    /// 仅当启动已完成且刚从后台回来时，拉广告并视条件展示覆盖页
    private func handleForegroundReturn() {
        guard backgroundFlag, !showSplash else { return }
        
        AdMixer.shared.primeAll(cue: .foreground)
        
        if shouldShowReturnOverlay() {
            NVLog.log("Ads", "显示后台覆盖页")
            resumeOverlayActive = true
        }
        backgroundFlag = false
    }
    
    /// 是否满足展示后台覆盖页条件：隐私已同意、未在连接中、无广告在展示、有可用广告
    private func shouldShowReturnOverlay() -> Bool {
        guard UserDefaults.standard.bool(forKey: "NexusVPN.PrivacyAccepted") else {
            NVLog.log("Ads", "隐私未同意，跳过后台页")
            return false
        }
        if viewModel.stage == .connecting {
            NVLog.log("Ads", "VPN 正在连接，跳过后台页")
            return false
        }
        if AdMixer.shared.mediaVisible {
            NVLog.log("Ads", "已有媒体在展示，跳过后台页")
            return false
        }
        guard AdMixer.shared.hasAnyPayload() else {
            NVLog.log("Ads", "无可用媒体，跳过后台页")
            return false
        }
        return true
    }
    
    /// 覆盖页出现 2s 后调用：隐私检查后按优先级展示一条广告，有展示则 0.1s 后关覆盖页
    private func presentReturnOverlayAd() {
        guard UserDefaults.standard.bool(forKey: "NexusVPN.PrivacyAccepted") else {
            NVLog.log("Ads", "隐私未同意，跳过展示")
            return
        }
        if AdMixer.shared.presentTopPriorityIfAvailable(from: nil, cue: .foreground) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                resumeOverlayActive = false
            }
        } else {
            NVLog.log("Ads", "无可用媒体，等待 3 秒超时关闭")
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
