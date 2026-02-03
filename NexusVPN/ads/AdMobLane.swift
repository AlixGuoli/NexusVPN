//
//  AdMobLane.swift
//  NexusVPN
//
//  AdMob 插屏广告加载与展示（单条 lane，仅负责 load/show，不负责优先级与触发时机）
//

import Foundation
import UIKit
import GoogleMobileAds

/// AdMob 插屏 lane：从 AdSettingsCache 取 unit id，支持多 unit 顺序尝试、120s 超时、关闭后预加载下一支
final class AdMobLane: NSObject {

    static let shared = AdMobLane()

    private var pipelineStart: Date?
    private var cachedPayload: InterstitialAd?
    private var slotCursor = 0
    private var isLoading = false
    private var slotList: [String] = []
    private var showingSlot: InterstitialAd?
    /// 当前展示的广告对应的 cue，用于关闭时判断是否拉下一支（断开场景不拉，避免浪费）
    private var presentingCue: String?

    var onFilled: (() -> Void)?
    var onMiss: (() -> Void)?
    var onTap: (() -> Void)?

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
        slotList = AdSettingsCache.shared.slotIDs(for: .admobInterstitial)
        if slotList.isEmpty {
            NVLog.log("Ads", "AdMob 未配置 slotList")
        }
    }

    // MARK: - 加载

    /// 仅当全局阶段为 .online 时真正发起加载
    func requestNext(cue: String? = nil) {
        let isOnline = WirePhaseHub.shared.currentPhase == .online
        if hasPayload() { return }
        if isLoading, let start = pipelineStart, Date().timeIntervalSince(start) <= 120 { return }
        if !isOnline { return }
        Task {
            await runFullPipeline(cue: cue)
        }
    }

    /// 准备 + 顺序尝试 slot 直到成功或耗尽或超时（kickoff 与 pipeline 合并为一条 async 链）
    private func runFullPipeline(cue: String? = nil) async {
        syncSlots()
        slotCursor = 0
        guard slotCursor < slotList.count else { return }
        isLoading = true
        pipelineStart = Date()
        while slotCursor < slotList.count {
            if let start = pipelineStart, Date().timeIntervalSince(start) > 120 {
                NVLog.log("Ads", "AdMob 加载超时 120s")
                isLoading = false
                markMiss()
                return
            }
            if await attemptCurrentSlot(cue: cue) { return }
            slotCursor += 1
        }
        markMiss()
    }

    /// 对当前 slot 尝试加载一次，成功返回 true 并设好 payload，失败返回 false
    private func attemptCurrentSlot(cue: String? = nil) async -> Bool {
        let adUnitId = slotList[slotCursor]
        NVLog.log("Ads", "AdMob 开始加载 | unit: \(adUnitId) | cue: \(cue ?? "nil")")
        do {
            ConnectSignalReporter.shared.reportAdRequest(adKey: adUnitId, cue: cue)
            let ad = try await InterstitialAd.load(with: adUnitId, request: Request())
            NVLog.log("Ads", "AdMob 加载成功 | unit: \(ad.adUnitID)")
            isLoading = false
            cachedPayload = ad
            cachedPayload?.fullScreenContentDelegate = self
            ConnectSignalReporter.shared.reportAdReady(adKey: ad.adUnitID, cue: cue)
            onFilled?()
            return true
        } catch {
            NVLog.log("Ads", "AdMob 加载失败 | unit: \(adUnitId) | error: \(error.localizedDescription)")
            return false
        }
    }

    /// 清空当前并重新请求；是否加载由全局阶段判断
    func resetAndRequest(cue: String? = nil) {
        dropCurrent()
        requestNext(cue: cue)
    }

    // MARK: - 展示

    func expose(from viewController: UIViewController, cue: String?) {
        guard let ad = cachedPayload else { return }
        presentingCue = cue
        let unitId = ad.adUnitID
        ConnectSignalReporter.shared.reportAdDisplay(adKey: unitId, cue: cue)
        ad.present(from: viewController)
        NVLog.log("Ads", "AdMob present | unit: \(unitId) | cue: \(cue ?? "nil")")
    }

    // MARK: - 清理

    func dropCurrent() {
        cachedPayload = nil
        NVLog.log("Ads", "AdMob 清空缓存")
    }

    private func markMiss() {
        isLoading = false
        onMiss?()
    }
}

// MARK: - FullScreenContentDelegate

extension AdMobLane: FullScreenContentDelegate {

    func adWillPresentFullScreenContent(_ ad: FullScreenPresentingAd) {
        NVLog.log("Ads", "AdMob 即将展示")
        AdMixer.shared.mediaVisible = true
        showingSlot = cachedPayload
        cachedPayload = nil
        let cue = presentingCue
        presentingCue = nil
        // 断开场景不拉下一支，下次连接会重新拉，避免浪费一次请求
        if cue == "disconnect" {
            dropCurrent()
        } else {
            resetAndRequest(cue: "closead")
        }
    }

    func adDidRecordImpression(_ ad: FullScreenPresentingAd) {
        NVLog.log("Ads", "AdMob 已展示")
    }

    func adDidRecordClick(_ ad: FullScreenPresentingAd) {
        NVLog.log("Ads", "AdMob 点击")
        onTap?()
    }

    func ad(_ ad: FullScreenPresentingAd, didFailToPresentFullScreenContentWithError error: Error) {
        NVLog.log("Ads", "AdMob 展示失败 | error: \(error.localizedDescription)")
        resetAndRequest()
    }

    func adWillDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        // 与原项目保持一致：在 willDismiss 阶段就认为「不再有媒体在展示」
        AdMixer.shared.mediaVisible = false
    }

    func adDidDismissFullScreenContent(_ ad: FullScreenPresentingAd) {
        NVLog.log("Ads", "AdMob 已关闭")
    }
}

