//
//  SettingsView.swift
//  NexusVPN
//
//  应用设置页：提供入口到语言设置等页面，风格与主页统一。
//

import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var language: AppLanguageManager
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    
    var body: some View {
        ZStack {
            // 背景与主页一致
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.15, blue: 0.25),
                    Color(red: 0.02, green: 0.05, blue: 0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // 顶部栏
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
                    Text(language.text("settings.title"))
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
                
                // 内容区域
                ScrollView {
                    VStack(spacing: 20) {
                        // 通用设置：语言
                        VStack(alignment: .leading, spacing: 12) {
                            Text(language.text("settings.section.general"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                            
                            NavigationLink {
                                LanguageSettingsView()
                            } label: {
                                SettingsRow(
                                    icon: "globe",
                                    title: language.text("settings.language.sectionTitle"),
                                    subtitle: language.current.displayName
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                        
                        // 关于与支持
                        VStack(alignment: .leading, spacing: 12) {
                            Text(language.text("settings.section.about"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                            
                            // 关于应用（子页面）
                            NavigationLink {
                                AboutView()
                            } label: {
                                SettingsRow(
                                    icon: "info.circle",
                                    title: language.text("settings.about.title"),
                                    subtitle: language.text("settings.about.subtitle")
                                )
                            }
                            .buttonStyle(.plain)
                            
                            // 隐私政策
                            Button {
                                openURL(AppLinks.privacyPolicy)
                            } label: {
                                SettingsRow(
                                    icon: "lock.shield",
                                    title: language.text("settings.privacy.title"),
                                    subtitle: language.text("settings.privacy.subtitle")
                                )
                            }
                            .buttonStyle(.plain)
                            
                            // 用户协议
                            Button {
                                openURL(AppLinks.userAgreement)
                            } label: {
                                SettingsRow(
                                    icon: "doc.text",
                                    title: language.text("settings.terms.title"),
                                    subtitle: language.text("settings.terms.subtitle")
                                )
                            }
                            .buttonStyle(.plain)
                            
                            // Telegram
                            Button {
                                openURL(AppLinks.telegram)
                            } label: {
                                SettingsRow(
                                    icon: "paperplane.fill",
                                    title: language.text("settings.telegram.title"),
                                    subtitle: language.text("settings.telegram.subtitle")
                                )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 4)
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

// 全局链接常量（避免 URL 放在多语言里）
enum AppLinks {
    static let officialWebsite = URL(string: "https://fkeysupervpn.xyz/")!
    static let privacyPolicy = URL(string: "https://fkeysupervpn.xyz/p.html")!
    static let userAgreement = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let telegram = URL(string: "https://t.me/+sqwyDllHDt0wYTY1")!
}

// 通用设置行样式
struct SettingsRow: View {
    let icon: String
    let title: String
    let subtitle: String?
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.white.opacity(0.12))
                    .frame(width: 32, height: 32)
                
                Image(systemName: icon)
                    .font(.system(size: 16, weight: .medium))
                    .foregroundColor(.white)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white)
                
                if let subtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.system(size: 12))
                        .foregroundColor(.white.opacity(0.6))
                }
            }
            
            Spacer()
            
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(.white.opacity(0.45))
        }
        .padding(14)
        .background(Color.white.opacity(0.06))
        .cornerRadius(16)
    }
}

