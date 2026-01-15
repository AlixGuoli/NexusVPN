//
//  RelayListView.swift
//  NexusVPN
//
//  节点列表视图
//

import SwiftUI

struct RelayListView: View {
    @EnvironmentObject var relayStore: RelayStore
    @EnvironmentObject var language: AppLanguageManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // 背景：与主页一致的深色渐变
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.15, blue: 0.25),
                    Color(red: 0.02, green: 0.05, blue: 0.1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部标题栏
                HStack {
                    // 左侧返回按钮
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    // 居中标题
                    Text(language.text("relay.list.title"))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // 右侧占位（保持标题居中）
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.clear)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                // 节点列表
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(relayStore.relays) { relay in
                            RelayRowView(relay: relay)
                                .onTapGesture {
                                    relayStore.selectRelay(relay)
                                    dismiss()
                                }
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                }
            }
        }
        .navigationBarHidden(true)
        .onAppear {
            // 每次进入节点列表时，随机更新延迟和负载
            relayStore.refreshRelayStats()
        }
    }
}

// MARK: - 节点行视图

private struct RelayRowView: View {
    let relay: Relay
    @EnvironmentObject var relayStore: RelayStore
    @EnvironmentObject var language: AppLanguageManager
    
    var isSelected: Bool {
        relayStore.selectedRelayId == relay.id
    }
    
    var body: some View {
        HStack(spacing: 16) {
            // 图标区域
            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.cyan.opacity(0.3),
                                Color.blue.opacity(0.2)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 50, height: 50)
                
                if relay.id == -1 {
                    // Auto 节点显示特殊图标
                    Image(systemName: "sparkles")
                        .font(.system(size: 24, weight: .medium))
                        .foregroundColor(.cyan.opacity(0.9))
                } else {
                    // 其他节点显示国家代码（简化版，后续可以加国旗图标）
                    Text(relay.countryCode.uppercased())
                        .font(.system(size: 14, weight: .bold))
                        .foregroundColor(.cyan.opacity(0.9))
                }
            }
            
            // 节点信息
            VStack(alignment: .leading, spacing: 4) {
                Text(relay.id == -1 ? language.text("relay.auto.name") : relay.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                if relay.id == -1 {
                    // Auto 节点显示说明文字
                    Text(language.text("relay.auto.desc"))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                        .multilineTextAlignment(.leading)
                } else {
                    // 其他节点显示延迟和状态
                    HStack(spacing: 12) {
                        // 延迟
                        HStack(spacing: 4) {
                            Image(systemName: "speedometer")
                                .font(.system(size: 11))
                            Text("\(relay.latency) ms")
                                .font(.system(size: 13))
                        }
                        .foregroundColor(.white.opacity(0.7))
                        
                        // 节点状态
                        HStack(spacing: 4) {
                            Image(systemName: statusIcon)
                                .font(.system(size: 11))
                            Text(statusText)
                                .font(.system(size: 13))
                        }
                        .foregroundColor(statusColor)
                    }
                }
            }
            
            Spacer()
            
            // 选中标记
            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 24))
                    .foregroundColor(.cyan.opacity(0.9))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    isSelected
                    ? Color.white.opacity(0.15)
                    : Color.white.opacity(0.08)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            isSelected
                            ? Color.cyan.opacity(0.6)
                            : Color.white.opacity(0.1),
                            lineWidth: isSelected ? 1.5 : 0.5
                        )
                )
        )
    }
    
    private var statusText: String {
        switch relay.status {
        case 0:
            return language.text("relay.status.excellent")
        case 1:
            return language.text("relay.status.good")
        default:
            return language.text("relay.status.normal")
        }
    }
    
    private var statusIcon: String {
        switch relay.status {
        case 0:
            return "star.fill"
        case 1:
            return "checkmark.circle.fill"
        default:
            return "circle.fill"
        }
    }
    
    private var statusColor: Color {
        switch relay.status {
        case 0:
            return .cyan.opacity(0.9)
        case 1:
            return .green.opacity(0.8)
        default:
            return .white.opacity(0.6)
        }
    }
}

#Preview {
    RelayListView()
        .environmentObject(RelayStore.shared)
        .environmentObject(AppLanguageManager.shared)
}
