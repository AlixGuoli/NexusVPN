//
//  EMIntLane.swift
//  NexusVPN
//
//  EM 插屏 lane：结构与 YandexIntLane 相同，slot 来自 AdSettingsCache.emInterstitial，
//  由 Yandex Mediation 下发 EM adUnit（Yandex_EMInt_List）。
//

import Foundation
import UIKit
import YandexMobileAds

final class EMIntLane: NSObject {

    static let shared = EMIntLane()

    private var pipelineStart: Date?
    private var cachedPayload: InterstitialAd?
    private var slotCursor = 0
    private var isLoading = false
    private var slotList: [String] = []
    private var showingSlot: InterstitialAd?
    private var slotLoader: InterstitialAdLoader?

    private var loadContinuation: CheckedContinuation<Bool, Never>?

    var onFilled: (() -> Void)?
    var onMiss: (() -> Void)?
    var onTap: (() -> Void)?
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
        slotList = AdSettingsCache.shared.slotIDs(for: .emInterstitial)
        if slotList.isEmpty {
            NVLog.log("Ads", "EM Int 未配置 slotList")
        }
    }

    // MARK: - 加载

    func requestNext(cue: String? = nil) {
        if hasPayload() { return }
        if isLoading, let start = pipelineStart, Date().timeIntervalSince(start) <= 100 { return }
        Task {
            await runFullPipeline(cue: cue)
        }
    }

    private func runFullPipeline(cue: String? = nil) async {
        syncSlots()
        slotCursor = 0
        guard slotCursor < slotList.count else { return }
        isLoading = true
        pipelineStart = Date()
        while slotCursor < slotList.count {
            if let start = pipelineStart, Date().timeIntervalSince(start) > 100 {
                NVLog.log("Ads", "EM Int 加载超时 100s")
                isLoading = false
                markMiss()
                return
            }
            if await attemptCurrentSlot(cue: cue) { return }
            slotCursor += 1
        }
        markMiss()
    }

    private func attemptCurrentSlot(cue: String? = nil) async -> Bool {
        let adUnitId = slotList[slotCursor]
        NVLog.log("Ads", "EM Int 开始加载 | unit: \(adUnitId) | cue: \(cue ?? "nil")")

        return await withCheckedContinuation { cont in
            loadContinuation = cont

            let loader = InterstitialAdLoader()
            loader.delegate = self
            slotLoader = loader

            let config = AdRequestConfiguration(adUnitID: adUnitId)
            loader.loadAd(with: config)
        }
    }

    private func markFilled(_ ad: InterstitialAd) {
        cachedPayload = ad
        isLoading = false
        pipelineStart = nil
        onFilled?()
        loadContinuation?.resume(returning: true)
        loadContinuation = nil
    }

    private func markMiss() {
        cachedPayload = nil
        isLoading = false
        pipelineStart = nil
        onMiss?()
        loadContinuation?.resume(returning: false)
        loadContinuation = nil
    }

    // MARK: - 展示

    func expose(from host: UIViewController, cue: String? = nil) {
        guard let ad = currentPayload() else {
            NVLog.log("Ads", "EM Int 无可用 payload，忽略 expose")
            return
        }
        mediaWillShow()
        showingSlot = ad
        ad.delegate = self
        ad.show(from: host)
        NVLog.log("Ads", "EM Int 开始展示 | unit: \(ad.adInfo?.adUnitId ?? "") | cue: \(cue ?? "nil")")
    }

    private func mediaWillShow() {
        AdMixer.shared.mediaVisible = true
    }

    private func mediaDidDismiss() {
        AdMixer.shared.mediaVisible = false
        showingSlot = nil
        cachedPayload = nil
        Task {
            await runFullPipeline(cue: nil)
        }
        onClosed?()
    }
}

// MARK: - InterstitialAdLoaderDelegate

extension EMIntLane: InterstitialAdLoaderDelegate {
    func interstitialAdLoader(_ adLoader: InterstitialAdLoader, didLoad interstitialAd: InterstitialAd) {
        NVLog.log("Ads", "EM Int 加载成功 | unit: \(interstitialAd.adInfo?.adUnitId ?? "")")
        markFilled(interstitialAd)
    }

    func interstitialAdLoader(_ adLoader: InterstitialAdLoader, didFailToLoadWithError error: AdRequestError) {
        NVLog.log("Ads", "EM Int 加载失败 | error: \(error.error.localizedDescription)")
        markMiss()
    }
}

// MARK: - InterstitialAdDelegate

extension EMIntLane: InterstitialAdDelegate {
    func interstitialAdDidShow(_ interstitialAd: InterstitialAd) {
        NVLog.log("Ads", "EM Int 已展示 | unit: \(interstitialAd.adInfo?.adUnitId ?? "")")
    }

    func interstitialAdDidDismiss(_ interstitialAd: InterstitialAd) {
        NVLog.log("Ads", "EM Int 已关闭 | unit: \(interstitialAd.adInfo?.adUnitId ?? "")")
        mediaDidDismiss()
    }

    func interstitialAd(_ interstitialAd: InterstitialAd, didFailToShowWithError error: Error) {
        NVLog.log("Ads", "EM Int 展示失败 | error: \(error.localizedDescription)")
        mediaDidDismiss()
    }

    func interstitialAdDidClick(_ interstitialAd: InterstitialAd) {
        NVLog.log("Ads", "EM Int 点击 | unit: \(interstitialAd.adInfo?.adUnitId ?? "")")
        onTap?()
    }
}

