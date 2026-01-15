//
//  ToolboxView.swift
//  NexusVPN
//
//  工具箱主页面
//

import SwiftUI

struct ToolboxView: View {
    @EnvironmentObject var language: AppLanguageManager
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        ZStack {
            // 背景与主页一致
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
                // 顶部栏
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                    
                    Spacer()
                    
                    Text(language.text("toolbox.title"))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    // 占位，保持标题居中
                    Color.clear
                        .frame(width: 44, height: 44)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                ScrollView {
                    VStack(spacing: 16) {
                        // 描述文字
                        Text(language.text("toolbox.desc"))
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 20)
                            .padding(.top, 8)
                        
                        // 工具卡片列表
                        VStack(spacing: 12) {
                            // Ping测试
                            NavigationLink {
                                PingTestView()
                            } label: {
                                ToolboxRow(
                                    icon: "waveform.path.ecg",
                                    title: language.text("toolbox.ping.title"),
                                    subtitle: language.text("toolbox.ping.subtitle")
                                )
                            }
                            
                            // 端口检测
                            NavigationLink {
                                PortCheckView()
                            } label: {
                                ToolboxRow(
                                    icon: "network",
                                    title: language.text("toolbox.port.title"),
                                    subtitle: language.text("toolbox.port.subtitle")
                                )
                            }
                            
                            // Base64工具
                            NavigationLink {
                                Base64ToolView()
                            } label: {
                                ToolboxRow(
                                    icon: "textformat.abc",
                                    title: language.text("toolbox.base64.title"),
                                    subtitle: language.text("toolbox.base64.subtitle")
                                )
                            }
                            
                            // 密码生成器
                            NavigationLink {
                                PasswordGeneratorView()
                            } label: {
                                ToolboxRow(
                                    icon: "key.fill",
                                    title: language.text("toolbox.password.title"),
                                    subtitle: language.text("toolbox.password.subtitle")
                                )
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 40)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }
}

// MARK: - 工具箱行组件

struct ToolboxRow: View {
    let icon: String
    let title: String
    let subtitle: String
    
    var body: some View {
        HStack(spacing: 16) {
            // 图标
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
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
                    .frame(width: 48, height: 48)
                
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.cyan.opacity(0.9))
            }
            
            // 文字信息
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundColor(.white.opacity(0.7))
                    .lineLimit(2)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            
            // 右箭头
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white.opacity(0.4))
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.white.opacity(0.08))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}
