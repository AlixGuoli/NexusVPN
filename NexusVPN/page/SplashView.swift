//
//  SplashView.swift
//  NexusVPN
//
//  启动页：3秒后跳转主页
//

import SwiftUI

struct SplashView: View {
    let onFinish: () -> Void
    @EnvironmentObject var viewModel: HomeSessionViewModel
    
    @State private var opacity: Double = 0.0
    @State private var progress: Int = 0
    @State private var timer: Timer?
    
    var body: some View {
        ZStack {
            // 与主页/连接页统一的深色渐变背景
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
                // Logo
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
                
                // App 名称
                Text("Nexus VPN")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
                
                // 进度条
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
                                width: CGFloat(progress) / 100.0 * 200.0,
                                height: 4
                            )
                    }
                    .frame(width: 200, alignment: .leading)
                    
                    Text("\(progress)%")
                        .font(.system(size: 13))
                        .foregroundColor(Color.white.opacity(0.7))
                }
                .padding(.top, 20)
            }
            .opacity(opacity)
        }
        .onAppear {
            // 淡入动画
            withAnimation(.easeIn(duration: 0.5)) {
                opacity = 1.0
            }
            
            // 检查网络类型，触发网络权限弹窗
            viewModel.checkNetworkType()
            
            // 进度从 0 递增到 100（3秒内完成）
            timer = Timer.scheduledTimer(withTimeInterval: 0.03, repeats: true) { t in
                if progress >= 100 {
                    t.invalidate()
                    timer = nil
                    return
                }
                progress += 1
            }
            
            // 3秒后跳转主页
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeOut(duration: 0.3)) {
                    opacity = 0.0
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    onFinish()
                }
            }
        }
        .onDisappear {
            timer?.invalidate()
            timer = nil
        }
    }
}

#Preview {
    SplashView(onFinish: {})
        .environmentObject(HomeSessionViewModel())
}
