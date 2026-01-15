//
//  LanguageSettingsView.swift
//  NexusVPN
//
//  语言设置页：完整页面，支持多语言 / 跟随系统。
//

import SwiftUI

struct LanguageSettingsView: View {
    @EnvironmentObject var language: AppLanguageManager
    @Environment(\.dismiss) private var dismiss
    @State private var isSwitching: Bool = false
    
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
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                            .padding(8)
                            .background(Color.white.opacity(0.12))
                            .clipShape(Circle())
                    }
                    
                    Spacer()
                    
                    Text(language.text("settings.language.sectionTitle"))
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Color.clear
                        .frame(width: 32, height: 32)
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                
                // 内容区域
                ScrollView {
                    VStack(spacing: 12) {
                        // 这里按语言一条一条分块展示
                        languageRow(for: .system)
                        languageRow(for: .english)           // 英语
                        languageRow(for: .russian)           // 俄语（主要市场）
                        languageRow(for: .german)
                        languageRow(for: .french)
                        languageRow(for: .spanish)
                        languageRow(for: .japanese)
                        languageRow(for: .korean)
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 10)
                    .padding(.bottom, 24)
                }
            }

            // 语言切换时的遮罩 + 自定义 Loading
            if isSwitching {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()
                
                VStack(spacing: 12) {
                    LanguageLoadingSpinner()
                    Text(language.text("settings.language.sectionTitle"))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
    
    // MARK: - 子视图
    
    private func languageRow(for item: AppLanguage) -> some View {
        let isSelected = (item == language.current)
        
        return Button {
            guard !isSwitching else { return }
            // 选中当前语言就不重复触发
            if item == language.current { return }
            isSwitching = true
            // 模拟系统切换语言时的短暂“应用中”效果
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                language.setLanguage(item)
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) {
                    isSwitching = false
                }
            }
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(item == .system ? language.text("language.system") : item.displayName)
                        .font(.system(size: 16, weight: isSelected ? .semibold : .regular))
                        .foregroundColor(.white.opacity(isSelected ? 1.0 : 0.85))
                    
                    // 预留副标题位，后面如果要加"推荐"等标签可以用
                    if item == .system {
                        Text(language.text("settings.language.followSystem"))
                            .font(.system(size: 11))
                            .foregroundColor(.white.opacity(0.6))
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color(red: 0.3, green: 0.9, blue: 1.0))
                        .font(.system(size: 18))
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.white.opacity(isSelected ? 0.14 : 0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(
                        Color.white.opacity(isSelected ? 0.35 : 0.12),
                        lineWidth: isSelected ? 1.2 : 0.8
                    )
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }
}

/// 语言切换时的小型自定义 Loading
private struct LanguageLoadingSpinner: View {
    @State private var rotation: Double = 0
    
    var body: some View {
        Circle()
            .trim(from: 0.0, to: 0.75)
            .stroke(
                AngularGradient(
                    gradient: Gradient(colors: [
                        Color.white,
                        Color(red: 0.5, green: 1.0, blue: 1.0),
                        Color(red: 0.2, green: 0.7, blue: 1.0),
                        Color.white
                    ]),
                    center: .center
                ),
                style: StrokeStyle(lineWidth: 3, lineCap: .round)
            )
            .frame(width: 26, height: 26)
            .rotationEffect(.degrees(rotation))
            .onAppear {
                rotation = 0
                withAnimation(.linear(duration: 0.9).repeatForever(autoreverses: false)) {
                    rotation = 360
                }
            }
    }
}


