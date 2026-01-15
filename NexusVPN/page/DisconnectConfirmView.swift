//
//  DisconnectConfirmView.swift
//  NexusVPN
//
//  断开确认弹窗
//

import SwiftUI

struct DisconnectConfirmView: View {
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @EnvironmentObject var language: AppLanguageManager
    
    var body: some View {
        VStack(spacing: 24) {
            // 标题和图标（横向排列）
            HStack(spacing: 10) {
                Image(systemName: "link.badge.minus")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.cyan.opacity(0.8))
                
                Text(language.text("disconnect.title"))
                    .font(.system(size: 19, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.top, 28)
            .padding(.horizontal, 28)
            
            // 文案
            Text(language.text("disconnect.message"))
                .font(.system(size: 15))
                .foregroundColor(.white.opacity(0.75))
                .multilineTextAlignment(.leading)
                .lineSpacing(5)
                .padding(.horizontal, 28)
            
            // 按钮：横向排列，等宽
            HStack(spacing: 14) {
                // 取消按钮
                Button {
                    onCancel()
                } label: {
                    Text(language.text("common.cancel"))
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.85))
                        .frame(height: 50)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color.white.opacity(0.12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                )
                        )
                }
                
                // 断开按钮
                Button {
                    onConfirm()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "power")
                            .font(.system(size: 14, weight: .medium))
                        Text(language.text("disconnect.confirm"))
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(height: 50)
                    .frame(maxWidth: .infinity)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color.cyan.opacity(0.6),
                                        Color.blue.opacity(0.5)
                                    ],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.cyan.opacity(0.4), lineWidth: 1)
                            )
                    )
                }
            }
            .padding(.horizontal, 28)
            .padding(.bottom, 28)
        }
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 0.12, green: 0.18, blue: 0.28).opacity(0.98),
                            Color(red: 0.08, green: 0.12, blue: 0.22).opacity(0.98)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.15),
                                    Color.white.opacity(0.05)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.4), radius: 30, x: 0, y: 15)
        )
    }
}

#Preview {
    DisconnectConfirmView(
        onConfirm: {},
        onCancel: {}
    )
}
