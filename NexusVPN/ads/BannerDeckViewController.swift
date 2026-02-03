//
//  BannerDeckViewController.swift
//  NexusVPN
//
//  全屏 Banner 展示：嵌入 Yandex AdView、倒计时、跳过按钮、穿透率与点击延迟逻辑
//

import Foundation
import UIKit

/// 全屏 Banner 页：穿透率决定是否展示；倒计时结束后按 tapDelayWeight 决定是否延迟可点跳过
final class DeckOverlayController: UIViewController {

    var onDismiss: (() -> Void)?

    private let overlayView: UIView
    private var clicked = false
    private var delayEnabled = false
    private var penetrateEnabled = false
    private var countdown = 6
    private let chromeBox = UIView()
    private let captionLabel = UILabel()
    private var countdownTimer: Timer?

    init(bannerView: UIView) {
        self.overlayView = bannerView
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        setupOverlay()
        registerObservers()
        startTicker()
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
        countdownTimer?.invalidate()
    }

    /// 广告被点击时调用（从 BannerDeck.adViewDidClick 回调），用于从后台回前台时关闭
    func markAdClicked() {
        clicked = true
    }

    // MARK: - 覆盖层规则

    private func setupOverlay() {
        configureOverlayRules()
        guard penetrateEnabled else {
            close()
            return
        }
        embedBanner()
        prepareInterface()
    }

    private func configureOverlayRules() {
        let delayThreshold = Int.random(in: 1...100)
        let penetrationThreshold = Int.random(in: 1...100)
        let penetration = AdSettingsCache.shared.overlayRate()
        let clickDelay = AdSettingsCache.shared.tapDelayWeight()
        penetrateEnabled = penetration >= penetrationThreshold
        delayEnabled = clickDelay >= delayThreshold
        NVLog.log("Ads", "Banner 穿透率: \(penetration)% 随机: \(penetrationThreshold)")
        NVLog.log("Ads", "Banner 点击延迟: \(clickDelay)% 随机: \(delayThreshold)")
    }

    private func embedBanner() {
        view.addSubview(overlayView)
        overlayView.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            overlayView.topAnchor.constraint(equalTo: view.topAnchor),
            overlayView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            overlayView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            overlayView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])
    }

    // MARK: - 界面

    private func prepareInterface() {
        view.backgroundColor = .white
        chromeBox.translatesAutoresizingMaskIntoConstraints = false
        chromeBox.backgroundColor = UIColor.black.withAlphaComponent(0.6)
        chromeBox.layer.cornerRadius = 10
        view.addSubview(chromeBox)
        captionLabel.textAlignment = .center
        captionLabel.textColor = .white
        captionLabel.font = UIFont.systemFont(ofSize: 14)
        captionLabel.text = String(format: NSLocalizedString("deck.wait.format", value: "Skip Ad %ldS", comment: ""), countdown)
        let interactionEnabled = !penetrateEnabled
        captionLabel.isUserInteractionEnabled = interactionEnabled
        chromeBox.isUserInteractionEnabled = interactionEnabled
        let tap = UITapGestureRecognizer(target: self, action: #selector(handleSkipTap))
        captionLabel.addGestureRecognizer(tap)
        chromeBox.addSubview(captionLabel)
        captionLabel.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            captionLabel.topAnchor.constraint(equalTo: chromeBox.topAnchor, constant: 4),
            captionLabel.leadingAnchor.constraint(equalTo: chromeBox.leadingAnchor, constant: 10),
            captionLabel.bottomAnchor.constraint(equalTo: chromeBox.bottomAnchor, constant: -4),
            captionLabel.trailingAnchor.constraint(equalTo: chromeBox.trailingAnchor, constant: -10),
            captionLabel.heightAnchor.constraint(equalToConstant: 30)
        ])
        arrangeContainer()
    }

    private func arrangeContainer() {
        let config = AdSettingsCache.shared.currentSkipPlacement()
        var containerConstraints: [NSLayoutConstraint] = []
        switch config.position {
        case 0:
            containerConstraints = [
                chromeBox.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: CGFloat(config.offsetY)),
                chromeBox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: CGFloat(config.offsetX))
            ]
        case 1:
            containerConstraints = [
                chromeBox.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: CGFloat(config.offsetY)),
                chromeBox.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -CGFloat(config.offsetX))
            ]
        case 2:
            containerConstraints = [
                chromeBox.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: CGFloat(config.offsetY)),
                chromeBox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: CGFloat(config.offsetX))
            ]
        case 3:
            containerConstraints = [
                chromeBox.centerYAnchor.constraint(equalTo: view.centerYAnchor, constant: CGFloat(config.offsetY)),
                chromeBox.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -CGFloat(config.offsetX))
            ]
        case 4:
            containerConstraints = [
                chromeBox.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -CGFloat(config.offsetY)),
                chromeBox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: CGFloat(config.offsetX))
            ]
        case 5:
            containerConstraints = [
                chromeBox.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -CGFloat(config.offsetY)),
                chromeBox.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -CGFloat(config.offsetX))
            ]
        default:
            containerConstraints = [
                chromeBox.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor, constant: CGFloat(config.offsetY)),
                chromeBox.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: CGFloat(config.offsetX))
            ]
        }
        NSLayoutConstraint.activate(containerConstraints)
    }

    // MARK: - 倒计时

    private func startTicker() {
        countdownTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] timer in
            self?.handleStep(timer)
        }
    }

    private func handleStep(_ timer: Timer) {
        if countdown > 0 {
            countdown -= 1
            updateLabelText()
            if countdown == 0 {
                timer.invalidate()
            }
        }
    }

    private func activateButton() {
        let shouldEnable = !delayEnabled || !penetrateEnabled
        if shouldEnable {
            captionLabel.isUserInteractionEnabled = true
            chromeBox.isUserInteractionEnabled = true
        }
    }

    private func updateLabelText() {
        if countdown <= 0 {
            activateButton()
            captionLabel.text = NSLocalizedString("deck.skip.label", value: "Skip Ad", comment: "")
        } else {
            captionLabel.text = String(format: NSLocalizedString("deck.wait.format", value: "Skip Ad %ldS", comment: ""), countdown)
        }
    }

    // MARK: - 通知

    private func registerObservers() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(appWillEnterForeground),
            name: UIApplication.willEnterForegroundNotification,
            object: nil
        )
    }

    @objc private func appWillEnterForeground() {
        guard clicked else { return }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { [weak self] in
            self?.close()
        }
    }

    // MARK: - 交互

    @objc private func handleSkipTap() {
        let canSkip = countdown <= 0
        if canSkip {
            close()
        }
    }

    private func close() {
        dismiss(animated: true) { [weak self] in
            self?.onDismiss?()
            NVLog.log("Ads", "Banner 关闭")
        }
    }
}
