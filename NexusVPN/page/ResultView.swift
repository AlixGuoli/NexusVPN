//
//  ResultView.swift
//  NexusVPN
//
//  结果页面
//

import SwiftUI

struct ResultView: View {
    let result: ConnectionResult
    @EnvironmentObject var language: AppLanguageManager
    @EnvironmentObject var viewModel: HomeSessionViewModel
    @Environment(\.openURL) private var openURL
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // 与首页统一的深色渐变背景
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.15, blue: 0.25),
                    Color(red: 0.02, green: 0.05, blue: 0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 22) {
                // 顶部留一点呼吸空间
                Spacer(minLength: 12)
                
                // 结果主卡片（整体稍微靠上）
                VStack(spacing: 18) {
                    Image(systemName: iconName)
                        .font(.system(size: 56, weight: .semibold))
                        .foregroundColor(iconColor)
                    
                    Text(resultText)
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                    
                    if let detail = resultDetailText {
                        Text(detail)
                            .font(.system(size: 14))
                            .foregroundColor(.white.opacity(0.7))
                            .multilineTextAlignment(.center)
                    }
                }
                .padding(.vertical, 26)
                .padding(.horizontal, 22)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.10),
                                    Color.white.opacity(0.04)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 24, style: .continuous)
                                .stroke(Color.white.opacity(0.16), lineWidth: 1)
                        )
                        .shadow(color: Color.black.opacity(0.35), radius: 24, x: 0, y: 18)
                )
                
                // 分享 & 加入我们 卡片
                VStack(spacing: 12) {
                    shareAppCard
                    joinUsCard
                }
                
                Spacer(minLength: 20)
                
                Button {
                    dismiss()
                } label: {
                    Text(language.text("common.ok"))
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(.black)
                        .frame(maxWidth: .infinity)
                        .frame(height: 50)
                        .background(iconColor)
                        .cornerRadius(16)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.bottom, 26)
        }
        .navigationBarBackButtonHidden(true)
        .onDisappear {
            viewModel.clearResult()
        }
    }
    
    private var iconName: String {
        switch result {
        case .connectSuccess, .disconnectSuccess:
            return "checkmark.circle.fill"
        case .connectFailure:
            return "xmark.circle.fill"
        }
    }
    
    private var iconColor: Color {
        switch result {
        case .connectSuccess:
            return .green
        case .connectFailure:
            return .red
        case .disconnectSuccess:
            return .blue
        }
    }
    
    private var resultText: String {
        switch result {
        case .connectSuccess:
            return language.text("result.connectSuccess")
        case .connectFailure:
            return language.text("result.connectFailure")
        case .disconnectSuccess:
            return language.text("result.disconnectSuccess")
        }
    }
    
    /// 结果页补充说明，根据不同结果给一点文案
    private var resultDetailText: String? {
        switch result {
        case .connectSuccess:
            return language.text("home.status.connected")
        case .connectFailure:
            return language.text("home.status.failed")
        case .disconnectSuccess:
            return language.text("home.status.notConnected")
        }
    }
    
    // MARK: - 卡片视图
    
    private var shareAppCard: some View {
        Group {
            if #available(iOS 16.0, *) {
                ShareLink(
                    item: URL(string: "https://apps.apple.com/app/id6757793060")!,
                    message: Text(language.text("result.share.subtitle"))
                ) {
                    shareCardContent
                }
                .buttonStyle(.plain)
            } else {
                Button {
                    if let url = URL(string: "https://apps.apple.com/app/id6757793060") {
                        openURL(url)
                    }
                } label: {
                    shareCardContent
                }
                .buttonStyle(.plain)
            }
        }
    }
    
    private var shareCardContent: some View {
        HStack(spacing: 14) {
            Image(systemName: "square.and.arrow.up")
                .font(.system(size: 18, weight: .medium))
                .foregroundColor(.cyan)
                .frame(width: 32, height: 32)
                .background(Color.white.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
            
            VStack(alignment: .leading, spacing: 4) {
                Text(language.text("result.share.title"))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                Text(language.text("result.share.subtitle"))
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.65))
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.5))
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                )
        )
    }
    
    private var joinUsCard: some View {
        Button {
            if let url = URL(string: "https://t.me/+sqwyDllHDt0wYTY1") {
                openURL(url)
            }
        } label: {
            HStack(spacing: 14) {
                Image(systemName: "paperplane.fill")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.blue)
                    .frame(width: 32, height: 32)
                    .background(Color.white.opacity(0.10))
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(language.text("result.join.title"))
                        .font(.system(size: 15, weight: .medium))
                        .foregroundColor(.white)
                    Text(language.text("result.join.subtitle"))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.65))
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white.opacity(0.5))
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color.white.opacity(0.06))
                    .overlay(
                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                            .stroke(Color.white.opacity(0.14), lineWidth: 1)
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    NavigationStack {
        ResultView(result: .connectSuccess)
            .environmentObject(HomeSessionViewModel())
    }
}
