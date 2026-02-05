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
    @StateObject private var premiumCenter = SubscriptionAccessStore.sharedStore
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
                    .environmentObject(premiumCenter)
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
                    .environmentObject(premiumCenter)
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
                    .environmentObject(premiumCenter)
                    .ignoresSafeArea()
                }
                
                // 后台切回前台覆盖页（2s 后尝试展示广告，3s 后自动关闭）
                if resumeOverlayActive {
                    ReturnOverlayView()
                        .environmentObject(languageManager)
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
            // 每次回到前台时刷新订阅与配置缓存，再按条件拉广告
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
    
    /// 前台检查配置缓存是否过期，必要时在后台刷新（基础配置 6 小时、广告配置 4 小时）
    private func validateConfigCache(
        baseExpiry: TimeInterval = 6 * 3600,
        adsExpiry: TimeInterval = 4 * 3600
    ) {
        refreshConfigIfNeeded(
            lastSave: AppSettingsCache.shared.lastUpdateTime(),
            expiry: baseExpiry,
            refreshAction: { await EducationRoutes.callAppSettings() },
            configName: "基础配置"
        )
        
        refreshConfigIfNeeded(
            lastSave: AdSettingsCache.shared.lastRefreshTime(),
            expiry: adsExpiry,
            refreshAction: { await EducationRoutes.callAdSettings() },
            configName: "广告配置"
        )
    }
    
    private func refreshConfigIfNeeded(
        lastSave: Date?,
        expiry: TimeInterval,
        refreshAction: @escaping () async -> Void,
        configName: String
    ) {
        let currentTime = Date()
        
        if let timestamp = lastSave {
            if currentTime.timeIntervalSince(timestamp) >= expiry {
                NVLog.log("Wire", "[Config] \(configName)超过阈值，触发刷新")
                Task {
                    await refreshAction()
                }
            }
        } else {
            NVLog.log("Wire", "[Config] 未找到\(configName)时间戳，首次拉取")
            Task {
                await refreshAction()
            }
        }
    }
    
    // MARK: - 后台切前台
    
    /// 仅当启动已完成且刚从后台回来时，刷新订阅、校验配置并拉广告与返回覆盖页
    private func handleForegroundReturn() {
        guard backgroundFlag, !showSplash else { return }
        Task {
            // 先刷新订阅，避免过期仍按旧状态处理广告/参数
            await premiumCenter.refreshSubscriptionStatus()
            // 然后检查基础配置 / 广告配置是否过期（基础 6 小时，广告 4 小时）
            validateConfigCache()
            // 最后按条件拉前台广告与返回覆盖页
            AdMixer.shared.primeAll(cue: .foreground)
            
            if shouldShowReturnOverlay() {
                NVLog.log("Ads", "显示后台覆盖页")
                resumeOverlayActive = true
            }
            backgroundFlag = false
        }
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
