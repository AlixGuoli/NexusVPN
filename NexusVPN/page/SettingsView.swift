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
                    VStack(spacing: 16) {
                        // 语言设置入口卡片
                        VStack(alignment: .leading, spacing: 12) {
                            Text(language.text("settings.language.sectionTitle"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white.opacity(0.7))
                            
                            NavigationLink {
                                LanguageSettingsView()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(language.text("settings.language.sectionTitle"))
                                            .font(.system(size: 15, weight: .medium))
                                            .foregroundColor(.white)
                                        
                                        Text(language.current.displayName)
                                            .font(.system(size: 13))
                                            .foregroundColor(.white.opacity(0.6))
                                    }
                                    
                                    Spacer()
                                    
                                    Image(systemName: "chevron.right")
                                        .foregroundColor(.white.opacity(0.5))
                                }
                                .padding(14)
                                .background(Color.white.opacity(0.06))
                                .cornerRadius(16)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 10)
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

#Preview {
    SettingsView()
        .environmentObject(AppLanguageManager(previewLanguage: .english))
}

