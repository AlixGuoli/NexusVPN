//
//  ContentView.swift
//  NexusVPN
//
//  Created by ersao on 2026/1/8.
//

import SwiftUI

enum NavigationDestination: Hashable {
    case connecting
    case result(ConnectionResult)
}

struct ContentView: View {
    @EnvironmentObject var viewModel: HomeSessionViewModel
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            ZStack {
                // 深色渐变背景
                LinearGradient(
                    colors: [
                        Color(red: 0.05, green: 0.15, blue: 0.25),
                        Color(red: 0.02, green: 0.05, blue: 0.1)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()
                
                ScrollView {
                    VStack(spacing: 0) {
                        // 顶部区域
                        HStack {
                            // Logo
                            Image("logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                            
                            Spacer()
                            
                            // 标题
                            Text("Nexus VPN")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            // 设置按钮（占位）
                            Button(action: {}) {
                                Image(systemName: "gearshape.fill")
                                    .font(.system(size: 20))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        .padding(.bottom, 30)
                        
                        // 核心连接区
                        VStack(spacing: 24) {
                            // 大三角连接按钮
                            TriangleConnectionButton(
                                stage: viewModel.stage,
                                onTap: {
                                    viewModel.onPrimaryButtonTapped()
                                }
                            )
                            .frame(width: 200, height: 200)
                            
                            // 状态文字
                            Text(statusText)
                                .font(.system(size: 20, weight: .medium))
                                .foregroundColor(statusColor)
                            
                            // 当前节点信息
                            HStack(spacing: 8) {
                                Image(systemName: "location.fill")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.6))
                                Text("Auto • Best Location")
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            // 两个小按钮
                            HStack(spacing: 16) {
                                Button(action: {}) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "network")
                                            .font(.system(size: 12))
                                        Text("Change Node")
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.white.opacity(0.15))
                                    .cornerRadius(20)
                                }
                                
                                Button(action: {}) {
                                    HStack(spacing: 6) {
                                        Image(systemName: "bolt.fill")
                                            .font(.system(size: 12))
                                        Text("Smart Mode")
                                            .font(.system(size: 13, weight: .medium))
                                    }
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 10)
                                    .background(Color.white.opacity(0.15))
                                    .cornerRadius(20)
                                }
                            }
                            .padding(.top, 8)
                        }
                        .padding(.vertical, 40)
                        
                        // 信息条
                        HStack(spacing: 30) {
                            InfoItem(
                                icon: "arrow.up.circle.fill",
                                value: "0.0",
                                unit: "KB/s",
                                label: "Upload"
                            )
                            
                            InfoItem(
                                icon: "arrow.down.circle.fill",
                                value: "0.0",
                                unit: "KB/s",
                                label: "Download"
                            )
                        }
                        .padding(.top, 30)
                        .padding(.bottom, 20)
                    }
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .connecting:
                    ConnectingView()
                case .result(let result):
                    ResultView(result: result) {
                        viewModel.clearResult()
                        navigationPath.removeLast()
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { viewModel.showDisconnectAlert },
                set: { _ in }
            )) {
                DisconnectConfirmView(
                    onConfirm: {
                        viewModel.confirmDisconnect()
                    },
                    onCancel: {
                        viewModel.cancelDisconnect()
                    }
                )
                .presentationDetents([.height(200)])
            }
            .onChange(of: viewModel.showConnectingView) { show in
                if show {
                    navigationPath.append(NavigationDestination.connecting)
                } else {
                    if navigationPath.count > 0 {
                        navigationPath.removeLast()
                    }
                }
            }
            .onChange(of: viewModel.result) { result in
                if let result = result {
                    if viewModel.showConnectingView {
                        navigationPath.removeLast()
                    }
                    navigationPath.append(NavigationDestination.result(result))
                }
            }
        }
    }
    
    // MARK: - 计算属性
    
    private var statusText: String {
        switch viewModel.stage {
        case .idle:
            return "Not Connected"
        case .connecting:
            return "Connecting..."
        case .online:
            return "Connected"
        case .failed:
            return "Connection Failed"
        }
    }
    
    private var statusColor: Color {
        switch viewModel.stage {
        case .idle:
            return .gray
        case .connecting:
            return .orange
        case .online:
            return .green
        case .failed:
            return .red
        }
    }
}

// MARK: - 大三角主按钮

struct TriangleConnectionButton: View {
    let stage: ConnectionStage
    let onTap: () -> Void
    
    @State private var scale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.45
    @State private var trianglePulse: CGFloat = 1.0
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // 三角形边缘光晕（沿着三条边）
                TriangleGlyph()
                    .stroke(
                        outerGlowColor.opacity(glowOpacity * 0.6),
                        style: StrokeStyle(
                            lineWidth: 8,
                            lineCap: .round,
                            lineJoin: .round
                        )
                    )
                    .frame(width: 320, height: 280)
                    .blur(radius: 12)
                
                // 大三角 + 电流 + 文案
                ZStack {
                    // 大三角主体（空心描边）
                    TriangleGlyph()
                        .stroke(
                            triangleStrokeGradient,
                            style: StrokeStyle(
                                lineWidth: 5,
                                lineCap: .round,
                                lineJoin: .round
                            )
                        )
                        .frame(width: 300, height: 260)
                        .shadow(color: outerGlowColor.opacity(0.5), radius: 12, x: 0, y: 8)

                    // 已连接时：三角边缘单点流光，沿三条边循环滑动（使用 TimelineView 驱动，不依赖 @State）
                    if #available(iOS 15.0, *), stage == .online {
                        TimelineView(.animation) { context in
                            let t = context.date.timeIntervalSinceReferenceDate
                            // 3 秒绕一圈，归一化到 0~1
                            let phase = (t.truncatingRemainder(dividingBy: 3.0)) / 3.0
                            let segmentLength: Double = 0.06
                            let end = phase + segmentLength

                            ZStack {
                                if end <= 1.0 {
                                    // 单段：普通情况
                                    TriangleGlyph()
                                        .trim(from: phase, to: end)
                                        .stroke(
                                            electricGradient,
                                            style: StrokeStyle(
                                                lineWidth: 6,
                                                lineCap: .round,
                                                lineJoin: .round
                                            )
                                        )
                                } else {
                                    // 跨越 1.0，需要拆成两段，避免看起来\"闪跳\"
                                    let overflow = end - 1.0
                                    // 尾段：phase ~ 1.0
                                    TriangleGlyph()
                                        .trim(from: phase, to: 1.0)
                                        .stroke(
                                            electricGradient,
                                            style: StrokeStyle(
                                                lineWidth: 6,
                                                lineCap: .round,
                                                lineJoin: .round
                                            )
                                        )
                                    // 头段：0 ~ overflow
                                    TriangleGlyph()
                                        .trim(from: 0.0, to: overflow)
                                        .stroke(
                                            electricGradient,
                                            style: StrokeStyle(
                                                lineWidth: 6,
                                                lineCap: .round,
                                                lineJoin: .round
                                            )
                                        )
                                }
                            }
                            .frame(width: 306, height: 266)
                            .shadow(color: Color.cyan.opacity(0.9), radius: 10, x: 0, y: 0)
                        }
                    }
                    
                    // 中间文案，位于三角内部略偏下
                    Text(centerText)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .offset(y: 35)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(stage == .connecting)
        .onAppear {
            startAnimations()
        }
        .onChange(of: stage) { _ in
            startAnimations()
        }
    }
    
    // MARK: - 渐变与颜色
    
    private var outerGlowColor: Color {
        switch stage {
        case .idle, .failed:
            return Color(red: 0.18, green: 0.78, blue: 1.0)
        case .connecting:
            return Color.orange
        case .online:
            return Color.green
        }
    }
    
    /// 大三角描边渐变，贴近 App Logo 风格（空心）
    private var triangleStrokeGradient: LinearGradient {
        let top = Color(red: 0.40, green: 0.90, blue: 1.00)
        let bottom = Color(red: 0.12, green: 0.45, blue: 0.95)
        let factor: Double
        switch stage {
        case .idle, .failed:
            factor = 0.75
        case .connecting:
            factor = 0.95
        case .online:
            factor = 1.0
        }
        return LinearGradient(
            colors: [top.opacity(factor), bottom.opacity(factor)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// 已连接时沿边缘滑动的流光渐变（更亮、更偏青）
    private var electricGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white,
                Color(red: 0.65, green: 1.0, blue: 1.0),
                Color(red: 0.3, green: 0.9, blue: 1.0),
                Color.white
            ],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
    
    private var centerText: String {
        switch stage {
        case .idle, .failed:
            return "Tap to Connect"
        case .connecting:
            return "Connecting..."
        case .online:
            return "Connected"
        }
    }
    
    // MARK: - 动画
    
    private func startAnimations() {
        scale = 1.0
        glowOpacity = 0.45
        trianglePulse = 1.0
        
        switch stage {
        case .idle, .failed:
            // 无呼吸效果，保持固定
            glowOpacity = 0.5
        case .connecting:
            // 连接中：仅加强光晕，不加流光动画
            glowOpacity = 0.8
        case .online:
            // 已连接：绿色更亮（流光由 TimelineView 单独驱动）
            glowOpacity = 0.9
        }
    }
}

// MARK: - 三角环单段

struct TriangleRingSegment: View {
    let segmentIndex: Int // 0: 左上, 1: 右, 2: 下
    let brightness: Double
    let stage: ConnectionStage
    let currentPhase: CGFloat
    
    var body: some View {
        TriangleRingSegmentShape(segmentIndex: segmentIndex)
            .trim(from: 0, to: 1.0)
            .stroke(
                segmentGradient,
                style: StrokeStyle(
                    lineWidth: 12,
                    lineCap: .round,
                    lineJoin: .round,
                    dash: stage == .connecting ? [20, 10] : [],
                    dashPhase: stage == .connecting ? currentPhase : 0
                )
            )
            .frame(width: 180, height: 180)
    }
    
    private var segmentGradient: LinearGradient {
        let baseColor: Color
        switch segmentIndex {
        case 0: // 左上 - 浅青色
            baseColor = Color(red: 0.4, green: 0.9, blue: 1.0)
        case 1: // 右 - 深蓝色
            baseColor = Color(red: 0.1, green: 0.4, blue: 0.9)
        case 2: // 下 - 蓝青色
            baseColor = Color(red: 0.2, green: 0.7, blue: 0.95)
        default:
            baseColor = .cyan
        }
        
        // 根据状态调整颜色
        let adjustedColor: Color
        switch stage {
        case .idle, .failed:
            adjustedColor = baseColor.opacity(0.6 * brightness)
        case .connecting:
            adjustedColor = baseColor.opacity(0.9 * brightness)
        case .online:
            adjustedColor = baseColor.opacity(0.85 * brightness)
        }
        
        return LinearGradient(
            colors: [
                adjustedColor,
                adjustedColor.opacity(0.7)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - 三角环单段形状

struct TriangleRingSegmentShape: Shape {
    let segmentIndex: Int
    
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let size = min(rect.width, rect.height) * 0.75
        
        // 计算三角形的三个顶点
        let top = CGPoint(x: center.x, y: center.y - size / 2)
        let bottomLeft = CGPoint(x: center.x - size * 0.866, y: center.y + size / 2)
        let bottomRight = CGPoint(x: center.x + size * 0.866, y: center.y + size / 2)
        
        // 每段占 1/3 周长，留小间隙
        let segmentLength = 1.0 / 3.0
        let gap = 0.02 // 间隙比例
        
        switch segmentIndex {
        case 0: // 左上段：从顶部到左下
            let start = 0.0 + gap
            let end = segmentLength - gap
            path = createTrimmedTrianglePath(
                top: top,
                bottomLeft: bottomLeft,
                bottomRight: bottomRight,
                from: start,
                to: end
            )
            
        case 1: // 右段：从左下到右下
            let start = segmentLength + gap
            let end = segmentLength * 2 - gap
            path = createTrimmedTrianglePath(
                top: top,
                bottomLeft: bottomLeft,
                bottomRight: bottomRight,
                from: start,
                to: end
            )
            
        case 2: // 下段：从右下到顶部
            let start = segmentLength * 2 + gap
            let end = 1.0 - gap
            path = createTrimmedTrianglePath(
                top: top,
                bottomLeft: bottomLeft,
                bottomRight: bottomRight,
                from: start,
                to: end
            )
            
        default:
            break
        }
        
        return path
    }
    
    private func createTrimmedTrianglePath(
        top: CGPoint,
        bottomLeft: CGPoint,
        bottomRight: CGPoint,
        from: Double,
        to: Double
    ) -> Path {
        var path = Path()
        
        // 计算三角形周长
        let side1 = sqrt(pow(top.x - bottomLeft.x, 2) + pow(top.y - bottomLeft.y, 2))
        let side2 = sqrt(pow(bottomLeft.x - bottomRight.x, 2) + pow(bottomLeft.y - bottomRight.y, 2))
        let side3 = sqrt(pow(bottomRight.x - top.x, 2) + pow(bottomRight.y - top.y, 2))
        let perimeter = side1 + side2 + side3
        
        // 计算起点和终点在周长上的位置
        let startDistance = perimeter * from
        let endDistance = perimeter * to
        
        // 根据距离找到对应的点和方向
        var currentDistance: CGFloat = 0
        var startPoint: CGPoint?
        var endPoint: CGPoint?
        var direction: CGPoint?
        
        // 遍历三条边
        let edges: [(start: CGPoint, end: CGPoint)] = [
            (top, bottomLeft),
            (bottomLeft, bottomRight),
            (bottomRight, top)
        ]
        
        for edge in edges {
            let edgeLength = sqrt(pow(edge.end.x - edge.start.x, 2) + pow(edge.end.y - edge.start.y, 2))
            
            if startPoint == nil && currentDistance + edgeLength >= startDistance {
                let t = (startDistance - currentDistance) / edgeLength
                startPoint = CGPoint(
                    x: edge.start.x + (edge.end.x - edge.start.x) * t,
                    y: edge.start.y + (edge.end.y - edge.start.y) * t
                )
                direction = CGPoint(x: edge.end.x - edge.start.x, y: edge.end.y - edge.start.y)
            }
            
            if endPoint == nil && currentDistance + edgeLength >= endDistance {
                let t = (endDistance - currentDistance) / edgeLength
                endPoint = CGPoint(
                    x: edge.start.x + (edge.end.x - edge.start.x) * t,
                    y: edge.start.y + (edge.end.y - edge.start.y) * t
                )
                break
            }
            
            currentDistance += edgeLength
        }
        
        if let start = startPoint, let end = endPoint {
            path.move(to: start)
            path.addLine(to: end)
        }
        
        return path
    }
}

// MARK: - 三角形形状（用于光晕）

struct TriangleShape: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let size = min(rect.width, rect.height) * 0.8
        
        path.move(to: CGPoint(x: center.x, y: center.y - size / 2))
        path.addLine(to: CGPoint(x: center.x - size * 0.866, y: center.y + size / 2))
        path.addLine(to: CGPoint(x: center.x + size * 0.866, y: center.y + size / 2))
        path.closeSubpath()
        
        return path
    }
}

// MARK: - 信息项组件

struct InfoItem: View {
    let icon: String
    let value: String
    let unit: String
    let label: String
    
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.cyan.opacity(0.8))
            
            HStack(alignment: .firstTextBaseline, spacing: 2) {
                Text(value)
                    .font(.system(size: 16, weight: .semibold))
                Text(unit)
                    .font(.system(size: 12))
            }
            .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.white.opacity(0.6))
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(HomeSessionViewModel())
}

// MARK: - 三角形 Glyph（内部小三角）

struct TriangleGlyph: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        
        path.move(to: CGPoint(x: width / 2, y: 0))
        path.addLine(to: CGPoint(x: width * 0.1, y: height * 0.8))
        path.addLine(to: CGPoint(x: width * 0.9, y: height * 0.8))
        path.closeSubpath()
        
        return path
    }
}

