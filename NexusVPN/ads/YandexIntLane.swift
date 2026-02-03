//
//  YandexIntLane.swift
//  NexusVPN
//
//  Yandex 插屏广告加载与展示（与 AdMobLane 同风格：requestNext / runFullPipeline / attemptCurrentSlot / expose）
//

import Foundation
import UIKit
import YandexMobileAds

/// Yandex 插屏 lane：从 AdSettingsCache 取 slot id，支持多 slot 顺序尝试、100s 超时、关闭后预加载下一支
final class YandexIntLane: NSObject {

    static let shared = YandexIntLane()

    private var pipelineStart: Date?
    private var cachedPayload: InterstitialAd?
    private var slotCursor = 0
    private var isLoading = false
    private var slotList: [String] = []
    private var showingSlot: InterstitialAd?
    private var slotLoader: InterstitialAdLoader?

    /// 用于将 delegate 回调桥接到 async（一次只会有一次 load 在飞）
    private var loadContinuation: CheckedContinuation<Bool, Never>?

    var onFilled: (() -> Void)?
    var onMiss: (() -> Void)?
    var onTap: (() -> Void)?
    /// 插屏关闭回调（AdMixer.showInt(onClose:) 使用）
    var onClosed: (() -> Void)?

    private override init() {
        super.init()
    }

    // MARK: - 状态

    func hasPayload() -> Bool {
        cachedPayload != nil
    }

    func currentPayload() -> InterstitialAd? {
        hasPayload() ? cachedPayload : nil
    }

    // MARK: - 配置

    private func syncSlots() {
        slotList = AdSettingsCache.shared.slotIDs(for: .yandexInterstitial)
        if slotList.isEmpty {
            NVLog.log("Ads", "Yandex Int 未配置 slotList")
        }
    }

    // MARK: - 加载

    /// 无「仅在线」限制，有 payload 或未超时加载中则不重复发起
    func requestNext(cue: String? = nil) {
        if hasPayload() { return }
        if isLoading, let start = pipelineStart, Date().timeIntervalSince(start) <= 100 { return }
        Task {
            await runFullPipeline(cue: cue)
        }
    }

    /// 准备 + 顺序尝试 slot 直到成功或耗尽或超时（100s）
    private func runFullPipeline(cue: String? = nil) async {
        syncSlots()
        slotCursor = 0
        guard slotCursor < slotList.count else { return }
        isLoading = true
        pipelineStart = Date()
        while slotCursor < slotList.count {
            if let start = pipelineStart, Date().timeIntervalSince(start) > 100 {
                NVLog.log("Ads", "Yandex Int 加载超时 100s")
                isLoading = false
                markMiss()
                return
            }
            if await attemptCurrentSlot(cue: cue) { return }
            slotCursor += 1
        }
        markMiss()
    }

    /// 对当前 slot 发起一次 Yandex 加载（delegate 回调后通过 continuation 返回成功/失败）
    private func attemptCurrentSlot(cue: String? = nil) async -> Bool {
        let adUnitId = slotList[slotCursor]
        NVLog.log("Ads", "Yandex Int 开始加载 | unit: \(adUnitId) | cue: \(cue ?? "nil")")
        return await withCheckedContinuation { [weak self] cont in
            guard let self = self else { return }
            self.loadContinuation = cont
            DispatchQueue.main.async {
                let loader = InterstitialAdLoader()
                loader.delegate = self
                self.slotLoader = loader
                let config = AdRequestConfiguration(adUnitID: adUnitId)
                loader.loadAd(with: config)
            }
        }
    }

    /// 清空当前并重新请求
    func resetAndRequest(cue: String? = nil) {
        dropCurrent()
        requestNext(cue: cue)
    }

    // MARK: - 展示

    func expose(from viewController: UIViewController, cue: String?) {
        guard let ad = cachedPayload else { return }
        ad.show(from: viewController)
        NVLog.log("Ads", "Yandex Int present | cue: \(cue ?? "nil")")
    }

    // MARK: - 清理

    func dropCurrent() {
        cachedPayload = nil
        slotLoader = nil
        NVLog.log("Ads", "Yandex Int 清空缓存")
    }

    private func markMiss() {
        isLoading = false
        onMiss?()
    }

    private func resumeLoad(success: Bool) {
        loadContinuation?.resume(returning: success)
        loadContinuation = nil
        slotLoader = nil
    }
}

// MARK: - InterstitialAdLoaderDelegate

extension YandexIntLane: InterstitialAdLoaderDelegate {

    func interstitialAdLoader(_ loader: InterstitialAdLoader, didLoad ad: InterstitialAd) {
        NVLog.log("Ads", "Yandex Int 加载成功 | unit: \(ad.adInfo?.adUnitId ?? "")")
        isLoading = false
        cachedPayload = ad
        cachedPayload?.delegate = self
        onFilled?()
        resumeLoad(success: true)
    }

    func interstitialAdLoader(_ loader: InterstitialAdLoader, didFailToLoadWithError error: AdRequestError) {
        NVLog.log("Ads", "Yandex Int 加载失败 | error: \(error.error.localizedDescription)")
        resumeLoad(success: false)
    }
}

// MARK: - InterstitialAdDelegate

extension YandexIntLane: InterstitialAdDelegate {

    func interstitialAdDidShow(_ ad: InterstitialAd) {
        NVLog.log("Ads", "Yandex Int 即将展示")
        AdMixer.shared.mediaVisible = true
        showingSlot = cachedPayload
        cachedPayload = nil
        resetAndRequest(cue: "closead")
    }

    func interstitialAdDidDismiss(_ ad: InterstitialAd) {
        NVLog.log("Ads", "Yandex Int 已关闭")
        onClosed?()
        onClosed = nil
        AdMixer.shared.mediaVisible = false
    }

    func interstitialAdDidClick(_ ad: InterstitialAd) {
        NVLog.log("Ads", "Yandex Int 点击")
        onTap?()
    }

    func interstitialAd(_ ad: InterstitialAd, didFailToShowWithError error: Error) {
        NVLog.log("Ads", "Yandex Int 展示失败 | error: \(error.localizedDescription)")
        resetAndRequest()
    }
}
