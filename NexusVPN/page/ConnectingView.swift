//
//  ConnectingView.swift
//  NexusVPN
//
//  连接中页面：三角装甲充能动画
//

import SwiftUI

struct ConnectingView: View {
    @Environment(\.dismiss) private var dismiss
    
    /// 三角装甲点亮进度（0~1，不断循环）
    @State private var chargeProgress: CGFloat = 0.0
    /// 背后光晕的缩放
    @State private var auraScale: CGFloat = 1.0
    /// 背后光晕透明度
    @State private var auraOpacity: Double = 0.6
    
    var body: some View {
        ZStack {
            // 深色渐变背景，和主页统一
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.15, blue: 0.25),
                    Color(red: 0.02, green: 0.05, blue: 0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 32) {
                Spacer()
                
                ZStack {
                    // 背后柔和大三角光晕，轻微呼吸（整体收细一点）
                    TriangleGlyph()
                        .stroke(
                            Color(red: 0.25, green: 0.85, blue: 1.0)
                                .opacity(auraOpacity),
                            style: StrokeStyle(
                                lineWidth: 6,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                        .frame(width: 250, height: 220)
                        .scaleEffect(auraScale)
                        .blur(radius: 10)
                    
                    // 主三角轮廓（固定描边）
                    TriangleGlyph()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.40, green: 0.90, blue: 1.00),
                                    Color(red: 0.12, green: 0.45, blue: 0.95)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            style: StrokeStyle(
                                lineWidth: 5,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                        .frame(width: 230, height: 205)
                        .shadow(color: Color(red: 0.2, green: 0.9, blue: 1.0).opacity(0.7), radius: 12, x: 0, y: 8)
                    
                    // 内层小三角，轻微呼吸，增加层次感（A 方案）
                    TriangleGlyph()
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color(red: 0.4, green: 0.9, blue: 1.0).opacity(0.2),
                                    Color.white.opacity(0.5)
                                ],
                                startPoint: .top,
                                endPoint: .bottom
                            ),
                            style: StrokeStyle(
                                lineWidth: 3,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                        .frame(width: 170, height: 150)
                        .scaleEffect(1.02 + 0.03 * sin(chargeProgress * .pi * 2))
                    
                    // 装甲充能：沿三角边从 0→1 点亮，再循环（线宽略小一点，避免“顶出”感觉）
                    TriangleGlyph()
                        .trim(from: 0.0, to: chargeProgress)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white,
                                    Color(red: 0.7, green: 1.0, blue: 1.0),
                                    Color(red: 0.4, green: 0.9, blue: 1.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            ),
                            style: StrokeStyle(
                                lineWidth: 5,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                        .frame(width: 228, height: 203)
                        .shadow(color: Color.cyan.opacity(0.9), radius: 10, x: 0, y: 0)
                }
                
                // 文案区域 + 简单加载动画（不依赖时间进度）
                VStack(spacing: 18) {
                    Text("正在建立安全连接…")
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                    
                    // 三个小点循环闪烁，不暗示进度（使用 TimelineView 驱动，避免与其它动画冲突）
                    if #available(iOS 15.0, *) {
                        TimelineView(.animation) { context in
                            let t = context.date.timeIntervalSinceReferenceDate
                            // 每 1.2 秒一个完整循环
                            let basePhase = (t.truncatingRemainder(dividingBy: 1.2)) / 1.2
                            
                            HStack(spacing: 8) {
                                ForEach(0..<3) { index in
                                    // 为每个点加一点相位偏移，形成波浪
                                    let phase = (basePhase + Double(index) * 0.33).truncatingRemainder(dividingBy: 1.0)
                                    let value = 0.3 + 0.7 * sin(phase * .pi * 2)
                                    let opacity = max(0.2, min(1.0, value))
                                    
                                    Circle()
                                        .fill(Color.white.opacity(0.9))
                                        .frame(width: 8, height: 8)
                                        .opacity(opacity)
                                }
                            }
                        }
                    } else {
                        // 兼容兜底：静态三个点
                        HStack(spacing: 8) {
                            ForEach(0..<3) { _ in
                                Circle()
                                    .fill(Color.white.opacity(0.6))
                                    .frame(width: 8, height: 8)
                            }
                        }
                    }
                }
                .padding(.top, 10)
                
                Spacer()
                
                Spacer()
            }
            // 整体略微上移，给底部预留卡片空间
            .offset(y: -40)
        }
        .onAppear {
            startAnimations()
        }
    }
    
    // MARK: - 动画
    
    private func startAnimations() {
        // 装甲充能：0→1，循环
        chargeProgress = 0.0
        withAnimation(.linear(duration: 1.6).repeatForever(autoreverses: false)) {
            chargeProgress = 1.0
        }
        
        // 光晕轻微呼吸（振幅和透明度都稍微克制一点）
        auraScale = 1.0
        auraOpacity = 0.45
        withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
            auraScale = 1.04
            auraOpacity = 0.8
        }
    }

}

#Preview {
    NavigationStack {
        ConnectingView()
    }
}

