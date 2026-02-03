//
//  AdMixer.swift
//  NexusVPN
//
//  统一的广告调度入口：负责多条 lane 的预加载与展示优先级控制。
//

import Foundation
import UIKit
import YandexMobileAds

/// 广告调度中心（单例）：调度 AdMob 插屏、Yandex 插屏与 Banner 覆盖层。
final class AdMixer {

    static let shared = AdMixer()

    /// 当前是否有广告正在展示（类似原项目 GVAdCoordinator.isPresenting）
    var mediaVisible: Bool = false

    private init() {}

    // MARK: - 全局开关与能力检查

    /// AppSettings 中的 adsOff 标记（nil 表示未下发）
    private var isAdsDisabled: Bool {
        AppSettingsCache.shared.isAdsDisabled() ?? false
    }
    
    /// 当前是否为 VIP 用户（占位实现，后续接入内购时替换）
    private var isVipUser: Bool {
        // TODO: 接入内购后，用真实 VIP 状态替换
        return false
    }
    
    /// 当前广告总开关（受 VIP 与 adsOff 共同影响）
    private var isAdsEnabled: Bool {
        if isVipUser {
            NVLog.log("Ads", "Mixer 广告关闭 | 原因: VIP 用户")
            return false
        }
        if isAdsDisabled {
            NVLog.log("Ads", "Mixer 广告关闭 | 原因: adsOff=true")
            return false
        }
        return true
    }

    /// AppSettings 中的 adsType（例如 "y;a"）
    private var adsType: String? {
        AppSettingsCache.shared.currentAdsType()
    }

    /// Yandex 系列广告是否允许
    private var isYandexEnabled: Bool {
        guard let adType = adsType else { return false }
        let types = adType.components(separatedBy: ";")
        let enabled = types.contains("y")
        if !enabled {
            NVLog.log("Ads", "Mixer Yandex 已关闭（adsType 不包含 y）")
        }
        return enabled
    }

    /// AdMob 是否允许（需要 adsType 包含 "a"，且当前全局阶段为 online）
    private var isAdmobEnabled: Bool {
        guard let adType = adsType else { return false }
        let types = adType.components(separatedBy: ";")
        guard types.contains("a") else {
            return false
        }
        let online = WirePhaseHub.shared.currentPhase == .online
        if !online {
            NVLog.log("Ads", "Mixer AdMob 关闭 | 原因: 未在线")
        }
        return online
    }

    // MARK: - 状态检查（混淆名，对应原项目 queryBa/queryYa/queryGa、hasYa/hasAny）

    /// Banner 槽位是否就绪
    func slotBannerReady() -> Bool {
        BannerDeck.shared.hasPayload()
    }

    /// Yandex 插屏槽位是否就绪
    func slotIntReady() -> Bool {
        YandexIntLane.shared.hasPayload()
    }

    /// AdMob 槽位是否就绪（非 online 时清空并返回 false）
    func slotGaReady() -> Bool {
        if WirePhaseHub.shared.currentPhase == .online {
            return AdMobLane.shared.hasPayload()
        }
        AdMobLane.shared.dropCurrent()
        return false
    }

    /// 是否有任意 Yandex 槽位可用
    func hasYandexSlot() -> Bool {
        guard isAdsEnabled else { return false }
        return slotBannerReady() || slotIntReady()
    }

    /// 是否有任意广告槽位可用
    func hasAnySlot() -> Bool {
        guard isAdsEnabled else { return false }
        return hasYandexSlot() || slotGaReady()
    }

    /// 是否有任何 Yandex 媒体可用（Banner 或插屏）
    func hasYandexPayload() -> Bool {
        guard isAdsEnabled else { return false }
        return slotBannerReady() || slotIntReady()
    }

    /// 是否有任何媒体可用（AdMob / Yandex Banner / Yandex Int）
    func hasAnyPayload() -> Bool {
        hasAnySlot()
    }

    // MARK: - 预加载

    /// 按当前配置预热所有广告资源（混淆名，对应原项目 prepareAll）
    func primeAll(cue: AdCue? = nil) {
        NVLog.log("Ads", "Mixer 准备加载所有广告 | cue: \(cue?.rawValue ?? "nil")")

        guard isAdsEnabled else {
            NVLog.log("Ads", "Mixer 广告已禁用，跳过加载")
            return
        }

        let tag = cue?.rawValue

        if isYandexEnabled {
            YandexIntLane.shared.requestNext(cue: tag)
            BannerDeck.shared.requestNext(cue: tag)
        }

        if isAdmobEnabled {
            AdMobLane.shared.requestNext(cue: tag)
        }
    }

    /// 简单预热所有广告（别名）
    func primeUpAll(cue: AdCue? = nil) {
        primeAll(cue: cue)
    }

    /// 预热 Banner 槽位，可选成功/失败回调（混淆名，对应原项目 prepareBa）
    func primeBanner(onAdReady: (() -> Void)? = nil, onAdFailed: (() -> Void)? = nil) {
        NVLog.log("Ads", "Mixer 加载 Yandex Banner")
        if isAdsEnabled && isYandexEnabled {
            if slotBannerReady() {
                onAdReady?()
            } else {
                BannerDeck.shared.onFilled = onAdReady
                BannerDeck.shared.onMiss = onAdFailed
                BannerDeck.shared.requestNext(cue: nil)
            }
        } else {
            onAdReady?()
        }
    }

    /// 预热 Yandex 插屏槽位，可选成功/失败回调（混淆名，对应原项目 prepareYa）
    func primeInt(onAdReady: (() -> Void)? = nil, onAdFailed: (() -> Void)? = nil) {
        NVLog.log("Ads", "Mixer 加载 Yandex Int")
        if isAdsEnabled && isYandexEnabled {
            if slotIntReady() {
                onAdReady?()
            } else {
                YandexIntLane.shared.onFilled = onAdReady
                YandexIntLane.shared.onMiss = onAdFailed
                YandexIntLane.shared.requestNext(cue: nil)
            }
        } else {
            onAdReady?()
        }
    }

    /// 预热 AdMob 槽位，可选 cue 与成功/失败回调（混淆名，对应原项目 prepareGa）
    func primeGa(cue: AdCue? = nil, onAdReady: (() -> Void)? = nil, onAdFailed: (() -> Void)? = nil) {
        NVLog.log("Ads", "Mixer 加载 AdMob Int")
        if isAdsEnabled && isAdmobEnabled {
            AdMobLane.shared.onFilled = onAdReady
            AdMobLane.shared.onMiss = onAdFailed
            AdMobLane.shared.requestNext(cue: cue?.rawValue)
        } else {
            onAdReady?()
        }
    }

    // MARK: - 展示入口

    /// 在给定控制器上按优先级尝试展示一条广告。
    /// 默认优先级：AdMob 插屏 > Banner 覆盖层 > Yandex 插屏。
    /// - Returns: 是否成功展示。
    @discardableResult
    func presentTopPriorityIfAvailable(
        from viewController: UIViewController? = nil,
        cue: AdCue
    ) -> Bool {
        guard !mediaVisible else {
            NVLog.log("Ads", "Mixer 已有媒体在展示，跳过 present | cue: \(cue.rawValue)")
            return false
        }

        guard let host = viewController ?? Self.locateHostViewController() else {
            NVLog.log("Ads", "Mixer 未找到可用 host VC")
            return false
        }

        // 1. AdMob 插屏
        if slotGaReady() {
            NVLog.log("Ads", "Mixer 选择 AdMob 展示 | cue: \(cue.rawValue)")
            AdMobLane.shared.expose(from: host, cue: cue.rawValue)
            return true
        }

        // 2. Banner 覆盖层
        if slotBannerReady() {
            NVLog.log("Ads", "Mixer 选择 Banner 展示 | cue: \(cue.rawValue)")
            BannerDeck.shared.expose(from: host, cue: cue.rawValue)
            return true
        }

        // 3. Yandex 插屏
        if slotIntReady() {
            NVLog.log("Ads", "Mixer 选择 Yandex Int 展示 | cue: \(cue.rawValue)")
            YandexIntLane.shared.expose(from: host, cue: cue.rawValue)
            return true
        }

        NVLog.log("Ads", "Mixer 无可用媒体 | cue: \(cue.rawValue)")
        return false
    }

    // MARK: - 分类型展示（混淆名，对应原项目 presentBa/presentYa/presentGa）

    /// 展示 Banner 覆盖层
    func showBanner() {
        guard let host = Self.locateHostViewController() else { return }
        BannerDeck.shared.expose(from: host, cue: nil)
    }

    /// 展示 Yandex 插屏，可选关闭回调
    func showInt(onClose: (() -> Void)? = nil) {
        guard let host = Self.locateHostViewController() else { return }
        YandexIntLane.shared.onClosed = onClose
        YandexIntLane.shared.expose(from: host, cue: nil)
    }

    /// 展示 AdMob 插屏（仅 online 时可用）
    func showGa(cue: AdCue) {
        guard let host = Self.locateHostViewController() else { return }
        guard slotGaReady() else { return }
        AdMobLane.shared.expose(from: host, cue: cue.rawValue)
    }

    /// 取出当前 Banner 视图并触发下一支加载（混淆名，对应原项目 obtainBa）
    func takeBannerView() -> AdView? {
        BannerDeck.shared.takeCurrentAndReload(cue: nil)
    }

    /// 设置 Banner 点击回调（混淆名，对应原项目 setBannerClickCallback）
    func setBannerTap(_ callback: @escaping () -> Void) {
        BannerDeck.shared.onTap = callback
    }

    /// 查找当前可用于展示广告的宿主控制器（最顶部的可见 VC）。
    private static func locateHostViewController() -> UIViewController? {
        guard let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return nil
        }
        // 优先使用 keyWindow，如不存在则退回第一个 window
        guard let window = scene.windows.first(where: { $0.isKeyWindow }) ?? scene.windows.first else {
            return nil
        }
        var root = window.rootViewController

        // 逐层找到最上面的 presented VC
        while let presented = root?.presentedViewController {
            root = presented
        }

        // 如果是导航 / 标签栏控制器，则取可见控制器
        if let nav = root as? UINavigationController {
            return nav.visibleViewController ?? nav
        }
        if let tab = root as? UITabBarController {
            return tab.selectedViewController ?? tab
        }
        return root
    }
}

