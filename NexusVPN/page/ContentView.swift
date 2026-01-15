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
    case settings
    case language
    case relayList
    case pingTest
    case portCheck
    case qrcodeGenerator
    case passwordGenerator
}

struct ContentView: View {
    @EnvironmentObject var viewModel: HomeSessionViewModel
    @EnvironmentObject var language: AppLanguageManager
    @StateObject private var relayStore = RelayStore.shared
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
                            // Logo（图片本身是正方形，这里加一点圆角让风格更统一）
                            Image("logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 32, height: 32)
                                .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                            
                            Spacer()
                            
                            // 标题
                            Text(language.text("app.title"))
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Spacer()
                
                            // 设置按钮
                Button(action: {
                                navigationPath.append(NavigationDestination.settings)
                            }) {
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
                                },
                                connectionStartTime: viewModel.connectionStartTime
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
                                if let selectedRelay = relayStore.selectedRelay {
                                    Text(selectedRelay.id == -1 ? language.text("relay.auto.name") : selectedRelay.name)
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.7))
                                } else {
                                    Text(language.text("relay.auto.name"))
                                        .font(.system(size: 14))
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                            
                            // 切换节点按钮
                            Button(action: {
                                navigationPath.append(NavigationDestination.relayList)
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "network")
                                        .font(.system(size: 12))
                                    Text(language.text("home.action.changeNode"))
                                        .font(.system(size: 13, weight: .medium))
                                }
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(Color.white.opacity(0.15))
                                .cornerRadius(20)
                            }
                            .padding(.top, 8)
                        }
                        .padding(.top, 40)
                        
                        // 信息卡片（可扩展：连接时长、数据流量等）
                        HStack(spacing: 12) {
                            // 上传卡片
                            SpeedCard(
                                icon: "arrow.up.circle.fill",
                                value: formatSpeed(viewModel.uploadSpeed),
                                unit: viewModel.uploadSpeed >= 1000 ? "MB/s" : "KB/s",
                                label: language.text("home.info.upload")
                            )
                            
                            // 下载卡片
                            SpeedCard(
                                icon: "arrow.down.circle.fill",
                                value: formatSpeed(viewModel.downloadSpeed),
                                unit: viewModel.downloadSpeed >= 1000 ? "MB/s" : "KB/s",
                                label: language.text("home.info.download")
                            )
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 26) // 适当拉开与下方标题的距离
                        
                        // 工具区：网络工具（列表行），其他工具（左右卡片）
                        VStack(alignment: .leading, spacing: 18) {
                            // 网络工具标题
                            Text(language.text("toolbox.section.network"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 24)
                            
                            // 网络相关工具：列表行样式，更贴近“设置项”感觉
                            VStack(spacing: 10) {
                                NetworkToolRow(
                                    icon: "waveform.path.ecg",
                                    title: language.text("toolbox.ping.title"),
                                    action: { navigationPath.append(NavigationDestination.pingTest) }
                                )
                                NetworkToolRow(
                                    icon: "network",
                                    title: language.text("toolbox.port.title"),
                                    action: { navigationPath.append(NavigationDestination.portCheck) }
                                )
                            }
                            .padding(.horizontal, 20)
                            
                            // 实用工具标题
                            Text(language.text("toolbox.section.utility"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.top, 4)
                                .padding(.horizontal, 24)
                            
                            // 其他工具：左右两张卡片，保持原来的“方块卡片”风格
                            HStack(spacing: 12) {
                                ToolGridItem(
                                    icon: "key.fill",
                                    title: language.text("toolbox.password.title"),
                                    action: {
                                        navigationPath.append(NavigationDestination.passwordGenerator)
                                    }
                                )
                                
                                ToolGridItem(
                                    icon: "qrcode",
                                    title: language.text("toolbox.qrcode.title"),
                                    action: {
                                        navigationPath.append(NavigationDestination.qrcodeGenerator)
                                    }
                                )
                            }
                            .padding(.horizontal, 20)
                            .padding(.bottom, 24)
                        }
                    }
                }
                
                // 断开确认弹窗（覆盖在主页上）
                if viewModel.showDisconnectAlert {
                    Color.black.opacity(0.5)
                        .ignoresSafeArea()
                        .onTapGesture {
                            viewModel.cancelDisconnect()
                        }
                    
                    DisconnectConfirmView(
                        onConfirm: {
                            viewModel.confirmDisconnect()
                        },
                        onCancel: {
                            viewModel.cancelDisconnect()
                        }
                    )
                    .padding(.horizontal, 24)
                }
            }
            .navigationBarHidden(true)
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .connecting:
                    ConnectingView()
                case .result(let result):
                    ResultView(result: result)
                        .environmentObject(viewModel)
                case .settings:
                    SettingsView()
                case .language:
                    LanguageSettingsView()
                case .relayList:
                    RelayListView()
                        .environmentObject(relayStore)
                case .pingTest:
                    PingTestView()
                case .portCheck:
                    PortCheckView()
                case .qrcodeGenerator:
                    QRCodeGeneratorView()
                case .passwordGenerator:
                    PasswordGeneratorView()
                }
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
    
    // 格式化速度显示（自动切换单位）
    private func formatSpeed(_ speed: Double) -> String {
        if speed >= 1000 {
            return String(format: "%.2f", speed / 1000)
        } else {
            return String(format: "%.1f", speed)
        }
    }
    
    private var statusText: String {
        switch viewModel.stage {
        case .idle:
            return language.text("home.status.notConnected")
        case .connecting:
            return language.text("home.status.connecting")
        case .online:
            return language.text("home.status.connected")
        case .failed:
            return language.text("home.status.failed")
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
    let connectionStartTime: Date?
    
    @EnvironmentObject var language: AppLanguageManager
    @State private var scale: CGFloat = 1.0
    @State private var glowOpacity: Double = 0.45
    @State private var trianglePulse: CGFloat = 1.0
    
    var body: some View {
        Button(action: onTap) {
            ZStack {
                // 透明背景，确保整个区域可点击
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 200, height: 200)
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
                    
                    // 连接时长（独立定位在三角形中心，不影响文案布局）
                    if stage == .online, let startTime = connectionStartTime {
                        if #available(iOS 15.0, *) {
                            TimelineView(.periodic(from: Date(), by: 1.0)) { context in
                                let duration = context.date.timeIntervalSince(startTime)
                                Text(formatDuration(duration))
                                    .font(.system(size: 18, weight: .semibold, design: .monospaced))
                                    .foregroundColor(Color.cyan.opacity(0.9))
                                    .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                            }
                            .offset(y: 0)
                        } else {
                            let duration = Date().timeIntervalSince(startTime)
                            Text(formatDuration(duration))
                                .font(.system(size: 18, weight: .semibold, design: .monospaced))
                                .foregroundColor(Color.cyan.opacity(0.9))
                                .shadow(color: Color.black.opacity(0.3), radius: 2, x: 0, y: 1)
                                .offset(y: 0)
                        }
                    }
                    
                    // 按钮文案（保持原有位置不变）
                    Text(centerText)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .foregroundColor(.white)
                        .multilineTextAlignment(.center)
                        .offset(y: 42)
                }
            }
            .frame(width: 200, height: 200)
            .contentShape(Rectangle())
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
            return language.text("button.connect.tap")
        case .connecting:
            return language.text("button.connect.connecting")
        case .online:
            return language.text("button.disconnect.tap")
        }
    }
    
    /// 格式化连接时长为 "HH:MM:SS" 或 "MM:SS" 格式
    private func formatDuration(_ duration: TimeInterval) -> String {
        let totalSeconds = Int(duration)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        
        if hours > 0 {
            return String(format: "%02d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%02d:%02d", minutes, seconds)
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

// MARK: - 速度卡片组件

struct SpeedCard: View {
    let icon: String
    let value: String
    let unit: String
    let label: String
    
    var body: some View {
        HStack(spacing: 10) {
            // 图标
            Image(systemName: icon)
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.cyan.opacity(0.9))
                .frame(width: 20)
            
            // 内容区域
            VStack(alignment: .leading, spacing: 2) {
                // 数值和单位
                HStack(alignment: .firstTextBaseline, spacing: 3) {
                    Text(value)
                        .font(.system(size: 15, weight: .semibold, design: .monospaced))
                    Text(unit)
                        .font(.system(size: 11, weight: .medium))
                }
                .foregroundColor(.white)
                
                // 标签
                Text(label)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}

#Preview {
    ContentView()
        .environmentObject(HomeSessionViewModel())
}

// MARK: - 工具网格项组件（首页工具区）

struct ToolGridItem: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 10) {
                // 图标
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.cyan.opacity(0.25),
                                    Color.blue.opacity(0.15)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 56, height: 56)
                    
                    Image(systemName: icon)
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.cyan.opacity(0.9))
                }
                
                // 标题
                Text(title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.white)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .frame(height: 32)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.08))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

// 网络工具列表行（左图标 + 文案 + 右箭头）
struct NetworkToolRow: View {
    let icon: String
    let title: String
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.cyan.opacity(0.28),
                                    Color.blue.opacity(0.18)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 38, height: 38)
                    
                    Image(systemName: icon)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.white)
                }
                
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(.white.opacity(0.4))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.white.opacity(0.10), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
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

