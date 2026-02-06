//
//  SplashView.swift
//  NexusVPN
//
//  启动引导页：20 秒超时，有网络时拉配置并加载广告，无网络不拉任何东西。
//

import SwiftUI
import Network
import Combine

/// 启动页进度（Timer 需更新引用类型才能驱动 UI）
private final class SplashProgress: ObservableObject {
    @Published var value: Int = 0
}

struct SplashView: View {
    let onFinish: () -> Void
    let onFinishWithAd: (() -> Void)?
    @EnvironmentObject var viewModel: HomeSessionViewModel
    @EnvironmentObject var language: AppLanguageManager

    @State private var opacity: Double = 0.0
    @StateObject private var splashProgress = SplashProgress()
    @State private var flowDone = false
    @State private var slotReady = false
    @State private var progressTimer: Timer?
    @State private var pathMonitor: NWPathMonitor?
    @State private var pathQueue: DispatchQueue?

    private let maxWaitTime: TimeInterval = 20.0

    init(onFinish: @escaping () -> Void, onFinishWithAd: (() -> Void)? = nil) {
        self.onFinish = onFinish
        self.onFinishWithAd = onFinishWithAd
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.15, blue: 0.25),
                    Color(red: 0.02, green: 0.05, blue: 0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(
                        color: Color(red: 0.25, green: 0.85, blue: 1.0).opacity(0.55),
                        radius: 20,
                        x: 0,
                        y: 10
                    )

                Text(language.text("app.title"))
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)

                VStack(spacing: 8) {
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.20))
                            .frame(height: 4)
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.40, green: 0.90, blue: 1.00),
                                        Color(red: 0.12, green: 0.45, blue: 0.95)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(
                                width: CGFloat(splashProgress.value) / 100.0 * 200.0,
                                height: 4
                            )
                    }
                    .frame(width: 200, alignment: .leading)

                    Text("\(splashProgress.value)%")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.7))
                }
                .padding(.top, 20)
            }
            .opacity(opacity)
        }
        .onAppear {
            withAnimation(.easeIn(duration: 0.5)) {
                opacity = 1.0
            }
            viewModel.checkNetworkType()
            kickoffSplash()
        }
        .onChange(of: flowDone) { done in
            if done {
                endSplash()
            }
        }
        .onDisappear {
            progressTimer?.invalidate()
            progressTimer = nil
            pathMonitor?.cancel()
            pathMonitor = nil
            pathQueue = nil
        }
    }

    // MARK: - 初始化流程

    private func kickoffSplash() {
        splashProgress.value = 0

        progressTimer?.invalidate()
        let stepInterval = maxWaitTime / 100.0
        let progressRef = splashProgress
        progressTimer = Timer.scheduledTimer(withTimeInterval: stepInterval, repeats: true) { t in
            if progressRef.value >= 100 {
                t.invalidate()
            } else {
                DispatchQueue.main.async {
                    progressRef.value += 1
                }
            }
        }
        if let t = progressTimer {
            RunLoop.current.add(t, forMode: .common)
        }

        probeConnectivity()

        DispatchQueue.main.asyncAfter(deadline: .now() + maxWaitTime) {
            if !flowDone {
                NVLog.log("Splash", "⏱️ 20秒超时，进入主页")
                flowDone = true
            }
        }
    }

    private func probeConnectivity() {
        let monitor = NWPathMonitor()
        let queue = DispatchQueue(label: "com.nexusvpn.splash.path")
        pathMonitor = monitor
        pathQueue = queue

        monitor.pathUpdateHandler = { [self] path in
            guard path.status == .satisfied else { return }
            NVLog.log("Splash", "🌐 网络可用，开始初始化")
            monitor.cancel()
            DispatchQueue.main.async {
                pathMonitor = nil
                pathQueue = nil
            }
            Task {
                await pullRemoteConfig()
                await MainActor.run {
                    if !flowDone {
                        flowDone = true
                    }
                }
            }
        }
        monitor.start(queue: queue)
    }

    private func pullRemoteConfig() async {
        NVLog.log("Splash", "开始请求基础配置")
        await EducationRoutes.callAppSettings()
        NVLog.log("Splash", "基础配置请求完成")

        Task {
            await EducationRoutes.callAdSettings()
        }

        let resourceReady = await fetchAdSlots()
        await MainActor.run {
            if !flowDone {
                slotReady = resourceReady
                flowDone = true
            }
        }
    }

    private func fetchAdSlots() async -> Bool {
        await withCheckedContinuation { cont in
            DispatchQueue.main.async {
                var resumed = false
                AdMixer.shared.primeInt(onAdReady: {
                    if !resumed {
                        resumed = true
                        NVLog.log("Ads", "Int 执行完成")
                        cont.resume(returning: true)
                    }
                }, onAdFailed: {
                    if !resumed {
                        resumed = true
                        NVLog.log("Ads", "Int 加载失败")
                        cont.resume(returning: false)
                    }
                })
            }
        }
    }

    // MARK: - 完成启动页

    private func endSplash() {
        if splashProgress.value < 100 {
            withAnimation(.easeOut(duration: 0.3)) {
                splashProgress.value = 100
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            if slotReady, let fn = onFinishWithAd {
                fn()
            } else {
                onFinish()
            }
        }
    }
}

#Preview {
    SplashView(onFinish: {})
        .environmentObject(HomeSessionViewModel())
        .environmentObject(AppLanguageManager.shared)
}
