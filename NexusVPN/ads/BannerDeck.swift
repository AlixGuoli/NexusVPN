//
//  BannerDeck.swift
//  NexusVPN
//
//  Yandex Banner 全屏：加载 AdView，expose 时用 BannerDeckViewController 展示（倒计时 + 跳过 + 穿透逻辑）
//

import Foundation
import UIKit
import YandexMobileAds

/// Yandex Banner 全屏 lane：从 AdSettingsCache 取 slot，100s 超时，多 slot 顺序尝试；展示由 BannerDeckViewController 负责
final class BannerDeck: NSObject {

    static let shared = BannerDeck()

    private var pipelineStart: Date?
    private var cachedPayload: AdView?
    private var slotCursor = 0
    private var isLoading = false
    private var slotList: [String] = []
    private var loadingView: AdView?

    private var loadContinuation: CheckedContinuation<Bool, Never>?

    var onFilled: (() -> Void)?
    var onMiss: (() -> Void)?
    var onTap: (() -> Void)?

    /// 当前全屏展示的 VC（用于 adViewDidClick 时通知「已点击广告」，便于从后台回前台时关闭）
    weak var presentedDeckVC: DeckOverlayController?

    private override init() {
        super.init()
    }

    // MARK: - 状态

    func hasPayload() -> Bool {
        cachedPayload != nil
    }

    func currentPayload() -> AdView? {
        hasPayload() ? cachedPayload : nil
    }

    // MARK: - 配置

    private func syncSlots() {
        slotList = AdSettingsCache.shared.slotIDs(for: .yandexBanner)
        if slotList.isEmpty {
            NVLog.log("Ads", "Banner 未配置 slotList")
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
        guard slotCursor < slotList.count else {
            NVLog.log("Ads", "Banner 无可用 slot，视为失败")
            markMiss()
            return
        }
        isLoading = true
        pipelineStart = Date()
        while slotCursor < slotList.count {
            if let start = pipelineStart, Date().timeIntervalSince(start) > 100 {
                NVLog.log("Ads", "Banner 加载超时 100s")
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
        return await withCheckedContinuation { [weak self] cont in
            guard let self = self else { return }
            self.loadContinuation = cont
            DispatchQueue.main.async {
                self.createAndLoadBanner(adUnitId: adUnitId, cue: cue)
            }
        }
    }

    @MainActor
    private func createAndLoadBanner(adUnitId: String, cue: String? = nil) {
        NVLog.log("Ads", "Banner 开始加载 | unit: \(adUnitId) | cue: \(cue ?? "nil")")
        let screenWidth = UIScreen.main.bounds.width
        let screenHeight = UIScreen.main.bounds.height
        var safeInsets = UIEdgeInsets.zero
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first {
            safeInsets = window.safeAreaInsets
        }
        let maxHeight = screenHeight - safeInsets.top - safeInsets.bottom
        let adSize = BannerAdSize.inlineSize(withWidth: screenWidth, maxHeight: maxHeight)
        let adView = AdView(adUnitID: adUnitId, adSize: adSize)
        adView.delegate = self
        adView.translatesAutoresizingMaskIntoConstraints = false
        loadingView = adView
        adView.loadAd()
    }

    func resetAndRequest(cue: String? = nil) {
        dropCurrent()
        requestNext(cue: cue)
    }

    // MARK: - 展示

    /// 取当前 Banner 视图，用 BannerDeckViewController 全屏展示（倒计时 + 跳过 + 穿透）；取后立即清空并预加载下一支
    func expose(from viewController: UIViewController, cue: String?) {
        guard let bannerView = currentPayload() else { return }
        dropCurrent()
        requestNext(cue: "closead")
        let deckVC = DeckOverlayController(bannerView: bannerView)
        deckVC.onDismiss = { [weak self] in
            AdMixer.shared.mediaVisible = false
            self?.presentedDeckVC = nil
        }
        presentedDeckVC = deckVC
        deckVC.modalPresentationStyle = .fullScreen
        viewController.present(deckVC, animated: true) { [weak self] in
            AdMixer.shared.mediaVisible = true
        }
    }

    // MARK: - 清理

    func dropCurrent() {
        cachedPayload = nil
        NVLog.log("Ads", "Banner 清空缓存")
    }

    private func markMiss() {
        isLoading = false
        onMiss?()
    }

    /// 取出当前 Banner 视图并清空缓存、触发下一支加载（供 AdMixer.takeBannerView 使用）
    func takeCurrentAndReload(cue: String? = nil) -> AdView? {
        let view = currentPayload()
        dropCurrent()
        requestNext(cue: cue)
        return view
    }

    private func resumeLoad(success: Bool) {
        loadContinuation?.resume(returning: success)
        loadContinuation = nil
    }
}

// MARK: - AdViewDelegate

extension BannerDeck: AdViewDelegate {

    func adViewDidLoad(_ adView: AdView) {
        NVLog.log("Ads", "Banner 加载成功 | unit: \(adView.adUnitID)")
        isLoading = false
        cachedPayload = loadingView
        loadingView = nil
        onFilled?()
        resumeLoad(success: true)
    }

    func adViewDidFailLoading(_ adView: AdView, error: Error) {
        NVLog.log("Ads", "Banner 加载失败 | unit: \(adView.adUnitID) | error: \(error.localizedDescription)")
        loadingView = nil
        resumeLoad(success: false)
    }

    func adViewDidClick(_ adView: AdView) {
        NVLog.log("Ads", "Banner 点击")
        onTap?()
        presentedDeckVC?.markAdClicked()
    }
}
