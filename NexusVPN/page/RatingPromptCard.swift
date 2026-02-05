//
//  RatingPromptCard.swift
//  NexusVPN
//
//  评价引导卡片：连接页/结果页下方，点击星星或卡片跳转 App Store 评价。
//

import SwiftUI

private let appStoreReviewURL = URL(string: "https://apps.apple.com/app/id6757793060?action=write-review")!

struct RatingPromptCard: View {
    @EnvironmentObject var language: AppLanguageManager
    @Environment(\.openURL) private var openURL

    /// 当前展示几颗星点亮（默认 4，点击后改为对应颗数并保持）
    @State private var filledCount: Int = 4
    /// 星星呼吸动效缩放
    @State private var starBreathScale: CGFloat = 1.0

    private let starColor = Color(red: 1.0, green: 0.82, blue: 0.25)
    private let starColorDim = Color.white.opacity(0.28)

    var body: some View {
        VStack(spacing: 20) {
            HStack(spacing: 10) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 22))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [starColor, starColor.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                Text(language.text("rating.card.title"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.leading)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture { openReview() }

            HStack(spacing: 8) {
                ForEach(1...5, id: \.self) { index in
                    Button {
                        starTapped(index)
                    } label: {
                        starView(filled: filledCountForStar(index))
                    }
                    .buttonStyle(.plain)
                }
            }
            .scaleEffect(starBreathScale)
            .frame(maxWidth: .infinity)

            Text(language.text("rating.card.subtitle"))
                .font(.system(size: 13))
                .foregroundColor(.white.opacity(0.68))
                .multilineTextAlignment(.center)
                .contentShape(Rectangle())
                .onTapGesture { openReview() }
        }
        .padding(.vertical, 18)
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color.white.opacity(0.12),
                            Color.white.opacity(0.05)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.22),
                                    starColor.opacity(0.25)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1
                        )
                )
                .shadow(color: Color.black.opacity(0.25), radius: 12, x: 0, y: 6)
        )
        .contentShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .onTapGesture { openReview() }
        .onAppear {
            startBreathAnimation()
        }
    }

    /// 当前这颗星是否应为“点亮”状态
    private func filledCountForStar(_ index: Int) -> Bool {
        index <= filledCount
    }

    private func starView(filled: Bool) -> some View {
        Image(systemName: filled ? "star.fill" : "star")
            .font(.system(size: 28, weight: .medium))
            .foregroundColor(filled ? starColor : starColorDim)
    }

    private func starTapped(_ index: Int) {
        withAnimation(.easeOut(duration: 0.2)) {
            filledCount = index
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            openReview()
        }
    }

    private func openReview() {
        openURL(appStoreReviewURL)
    }

    private func startBreathAnimation() {
        withAnimation(
            .easeInOut(duration: 1.2)
            .repeatForever(autoreverses: true)
        ) {
            starBreathScale = 1.06
        }
    }
}
