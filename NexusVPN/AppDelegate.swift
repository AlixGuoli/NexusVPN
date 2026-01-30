//
//  AppDelegate.swift
//  NexusVPN
//

import UIKit
import GameAnalytics
import GoogleMobileAds
import YandexMobileAds

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        initAdVendors()
        //configureAnalytics()
        return true
    }

    // MARK: - 广告 SDK

    private func initAdVendors() {
        initGoogleAds()
        initYandexAds()
    }

    private func initGoogleAds() {
        GoogleMobileAds.MobileAds.shared.start { status in
            let ready = status.adapterStatusesByClassName.values.contains { $0.state == .ready }
            NVLog.log("Ads", "[Ads] Google init \(ready ? "ok" : "fail")")
        }
    }

    private func initYandexAds() {
        YandexMobileAds.MobileAds.initializeSDK {
            NVLog.log("Ads", "[Ads] Yandex init ok")
        }
    }

    // MARK: - 分析 SDK

    /// 初始化分析 SDK
    private func configureAnalytics() {
        NVLog.log("GA", "开始初始化分析 SDK")
        let appVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0"

        GameAnalytics.setEnabledInfoLog(true)
        GameAnalytics.setEnabledVerboseLog(true)
        GameAnalytics.configureAutoDetectAppVersion(true)
        GameAnalytics.configureBuild(appVersion)
        GameAnalytics.initialize(
            withGameKey: "b58ec366ca796f3a0d1e874cc397ce26",
            gameSecret: "f4caea858a3f7ac9dff543cc6fce152a824c9d35"
        )
    }
}

