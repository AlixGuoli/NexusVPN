//
//  NVPrivacyIntroView.swift
//  NexusVPN
//
//  首次启动时展示的隐私与数据使用说明页：全屏覆盖首页
//

import SwiftUI

struct NVPrivacyIntroView: View {
    let onAccept: () -> Void
    let onDecline: () -> Void
    
    @EnvironmentObject private var language: AppLanguageManager
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        ZStack {
            // 与首页统一的深色渐变背景，完全覆盖底层内容
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.15, blue: 0.25),
                    Color(red: 0.02, green: 0.05, blue: 0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(alignment: .leading, spacing: 20) {
                Spacer().frame(height: 56)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                        // 标题
                        Text(language.text("privacy_title"))
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                        
                        // 引导说明
                        Text(language.text("privacy_preamble"))
                            .font(.system(size: 15))
                            .foregroundColor(Color.white.opacity(0.82))
                            .fixedSize(horizontal: false, vertical: true)
                        
                        // 小节标题
                        Text(language.text("privacy_section_intro"))
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white)
                            .padding(.top, 4)
                        
                        // 列表要点
                        VStack(alignment: .leading, spacing: 10) {
                            bulletBlock(
                                titleKey: "privacy_point_device_title",
                                bodyKey: "privacy_point_device_body"
                            )
                            
                            bulletBlock(
                                titleKey: "privacy_point_connection_title",
                                bodyKey: "privacy_point_connection_body"
                            )
                            
                            bulletBlock(
                                titleKey: "privacy_point_usage_title",
                                bodyKey: "privacy_point_usage_body"
                            )
                            
                            bulletBlock(
                                titleKey: "privacy_point_ads_title",
                                bodyKey: "privacy_point_ads_body"
                            )
                        }
                        .font(.system(size: 14))
                        .foregroundColor(Color.white.opacity(0.80))
                        .fixedSize(horizontal: false, vertical: true)
                        
                        // 底部提示 + 隐私政策链接
                        VStack(alignment: .leading, spacing: 4) {
                            Text(language.text("privacy_policy_footer"))
                                .font(.system(size: 13))
                                .foregroundColor(Color.white.opacity(0.75))
                            
                            Button {
                                if let url = URL(string: "https://nexusvpn.app/privacy") {
                                    openURL(url)
                                }
                            } label: {
                                Text(language.text("privacy_policy_link"))
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(Color.cyan.opacity(0.95))
                                    .underline()
                            }
                        }
                        .padding(.top, 8)
                    }
                }
                
                Spacer()
                
                // 按钮区域
                VStack(spacing: 12) {
                    // 勾选声明文案
                    Text(language.text("privacy_agree_statement"))
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity)
                        .padding(.bottom, 2)
                    
                    Button {
                        onAccept()
                    } label: {
                        Text(language.text("privacy_action_accept"))
                            .font(.system(size: 17, weight: .semibold))
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                            .background(
                                LinearGradient(
                                    colors: [
                                        Color(red: 0.25, green: 0.85, blue: 1.0),
                                        Color(red: 0.10, green: 0.55, blue: 1.0)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.black)
                            .cornerRadius(16)
                    }
                    
                    Button {
                        onDecline()
                    } label: {
                        Text(language.text("privacy_action_later"))
                            .font(.system(size: 17, weight: .medium))
                            .frame(maxWidth: .infinity)
                            .frame(height: 48)
                            .background(Color.white.opacity(0.10))
                            .foregroundColor(Color.white.opacity(0.92))
                            .cornerRadius(14)
                    }
                }
                .padding(.bottom, 34)
            }
            .padding(.horizontal, 24)
        }
    }
    
    // MARK: - 子视图
    
    private func bulletBlock(titleKey: String, bodyKey: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(language.text(titleKey))
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
            Text(language.text(bodyKey))
        }
    }
}

#Preview {
    NVPrivacyIntroView(
        onAccept: {},
        onDecline: {}
    )
    .environmentObject(AppLanguageManager(previewLanguage: .english))
}

