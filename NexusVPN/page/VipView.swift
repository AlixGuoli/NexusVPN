//
//  VipView.swift
//  NexusVPN
//
//  会员内购页面 UI（仅界面，无内购逻辑，用于截图/展示）。
//

import SwiftUI
import StoreKit

struct VipView: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var premiumCenter: SubscriptionAccessStore
    @EnvironmentObject private var language: AppLanguageManager

    /// 是否已是会员（左图 / 右图两种状态切换用）
    @State private var isVip: Bool = false

    /// 是否已勾选协议
    @State private var isAgreementOn: Bool = true

    /// 简单的套餐类型枚举（展示文案由 planTitle/planBadge 多语言提供）
    enum Plan: String, CaseIterable, Identifiable {
        case week
        case month
        case year
        var id: String { rawValue }
    }

    @State private var selectedPlan: Plan = .month

    /// 当前选中的订阅档位映射到 StoreKit 产品 ID
    private var selectedPremiumPlan: SubscriptionPack {
        switch selectedPlan {
        case .week:  return .weeklyPack
        case .month: return .monthlyPack
        case .year:  return .yearlyPack
        }
    }

    /// 获取当前 Plan 对应的 StoreKit Product（如果已加载）
    private func productForPlan(_ plan: Plan) -> Product? {
        switch plan {
        case .week:
            return premiumCenter.packProduct(for: .weeklyPack)
        case .month:
            return premiumCenter.packProduct(for: .monthlyPack)
        case .year:
            return premiumCenter.packProduct(for: .yearlyPack)
        }
    }

    /// 多语言套餐标题
    private func planTitle(_ plan: Plan) -> String {
        switch plan {
        case .week: return language.text("vip.plan.week")
        case .month: return language.text("vip.plan.month")
        case .year: return language.text("vip.plan.year")
        }
    }

    /// 多语言角标文案
    private func planBadge(_ plan: Plan) -> String? {
        switch plan {
        case .week: return nil
        case .month: return language.text("vip.badge.popular")
        case .year: return language.text("vip.badge.best")
        }
    }

    /// 计算每天的价格字符串（例如 "$0.27/day"），保持与总价相同的货币格式
    private func dailyPriceText(for plan: Plan, product: Product?) -> String? {
        guard let product = product else { return nil }

        let days: Int
        switch plan {
        case .week:  days = 7
        case .month: days = 30
        case .year:  days = 365
        }

        let displayPrice = product.displayPrice

        // 从 displayPrice 中提取货币符号和数字，保持与总价一致的格式
        guard
            let currencySymbol = extractCurrencySymbol(from: displayPrice),
            let numberPart = extractNumberPart(from: displayPrice),
            let total = Double(numberPart)
        else {
            // 退化到使用系统 locale
            let totalDecimal = NSDecimalNumber(decimal: product.price).doubleValue
            let perDay = totalDecimal / Double(days)
            let formatter = NumberFormatter()
            formatter.numberStyle = .currency
            formatter.locale = Locale.current
            if let s = formatter.string(from: NSNumber(value: perDay)) {
                return String(format: language.text("vip.perDay.format"), s)
            }
            return nil
        }

        let perDay = total / Double(days)
        guard let formatted = formatPrice(perDay, currencySymbol: currencySymbol, original: displayPrice) else {
            return nil
        }
        return String(format: language.text("vip.perDay.format"), formatted)
    }

    /// 从价格字符串中提取货币符号（例如 "$", "¥", "€"）
    private func extractCurrencySymbol(from price: String) -> String? {
        let cleaned = price.replacingOccurrences(of: "[0-9.,\\s]", with: "", options: .regularExpression)
        return cleaned.isEmpty ? nil : cleaned
    }

    /// 从价格字符串中提取数字部分（保留小数点/逗号）
    private func extractNumberPart(from price: String) -> String? {
        let number = price.replacingOccurrences(of: "[^0-9.,]", with: "", options: .regularExpression)
        return number.isEmpty ? nil : number
    }

    /// 按原格式格式化每日价格（保持小数点/千分位风格）
    private func formatPrice(_ value: Double, currencySymbol: String, original: String) -> String? {
        let symbolAtPrefix = original.hasPrefix(currencySymbol)

        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 2
        formatter.maximumFractionDigits = 2

        // 判断原字符串是用逗号还是点作为小数分隔符
        if original.contains(",") && !original.contains(".") {
            formatter.decimalSeparator = ","
            formatter.groupingSeparator = "."
        } else {
            formatter.decimalSeparator = "."
            formatter.groupingSeparator = ","
        }

        guard let numberString = formatter.string(from: NSNumber(value: value)) else {
            return nil
        }

        return symbolAtPrefix ? "\(currencySymbol)\(numberString)" : "\(numberString) \(currencySymbol)"
    }

    /// 顶部显示用的过期时间字符串（沙盒环境下带到分钟/秒，便于观察）
    private func formattedExpiry(_ date: Date) -> String {
        let formatter = DateFormatter()
        // 沙盒调试：到秒，方便看剩余时间；正式上线可改回只显示日期
        formatter.dateFormat = "yyyy.MM.dd HH:mm:ss"
        return formatter.string(from: date)
    }

    var body: some View {
        ZStack {
            // 背景与其他页面统一
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.15, blue: 0.25),
                    Color(red: 0.02, green: 0.05, blue: 0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            // 顶部装饰贴图（非全屏）
            VStack(spacing: 0) {
                Image("bgTop")
                    .resizable()
                    .scaledToFill()
                    .frame(height: 180)
                    .clipped()
                Spacer()
            }
            .ignoresSafeArea(edges: .top)

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)

                ScrollView(showsIndicators: false) {
                    VStack(spacing: 24) {
                        headerCard
                            .padding(.horizontal, 20)

                        plansSection

                        // 会员权益列表
                        benefitsSection

                        // 条款说明（含 Terms / Privacy）
                        disclaimerSection
                    }
                    .padding(.bottom, 24)
                }

                // 主操作按钮始终在页面底部，和其他页面一致
                startButton
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)

                // 勾选同意行放在按钮下方
                agreementRow
                    .padding(.horizontal, 20)
                    .padding(.bottom, 16)
            }

            // 内购过程中的全局遮罩，禁止误触
            if premiumCenter.isBusyWithSubscription {
                Color.black.opacity(0.35)
                    .ignoresSafeArea()

                VStack(spacing: 12) {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text(language.text("vip.busy"))
                        .font(.system(size: 14))
                        .foregroundColor(.white.opacity(0.9))
                }
            }
        }
        // 使用自定义顶部栏，隐藏系统导航栏和默认返回按钮
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
        .task {
            // 进入页面时确保已经加载产品并刷新订阅状态
            await premiumCenter.loadPacks()
            await premiumCenter.refreshSubscriptionStatus()
            isVip = premiumCenter.hasActiveSubscription
        }
        .onChange(of: premiumCenter.hasActiveSubscription) { newValue in
            // 内部 UI 上用 isVip 标记当前是否已订阅，用于控制图标等
            isVip = newValue
        }
    }

    // MARK: - 子视图

    /// 顶部导航栏
    private var topBar: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "chevron.left")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(.white)
            }

            Spacer()

            Text(language.text("vip.title"))
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(.white)

            Spacer()

            // 右侧占位，保持标题居中
            Button(action: {}) {
                Image(systemName: "xmark")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.clear)
            }
            .disabled(true)
        }
    }

    /// 顶部会员信息卡片
    private var headerCard: some View {
        let expiry = premiumCenter.subscriptionEndDate
        
        return HStack(spacing: 14) {
            Image(isVip ? "typeVipYes" : "typeVipNo")
                .resizable()
                .scaledToFit()
                .frame(width: 40, height: 40)

            VStack(alignment: .leading, spacing: 4) {
                Text(isVip ? language.text("vip.subtitle.member") : language.text("vip.subtitle.subscribe"))
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                
                if let expiry = expiry {
                    Text(String(format: language.text("vip.expiration.format"), formattedExpiry(expiry)))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                }
            }

            Spacer()
        }
        .padding(16)
        .background(Color.white.opacity(0.05))
        .cornerRadius(18)
    }

    /// 会员套餐区域
    private var plansSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(language.text("vip.plans.section"))
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                Spacer()
                Button {
                    Task {
                        await premiumCenter.restoreSubscription()
                    }
                } label: {
                    Text(language.text("vip.restore"))
                        .font(.system(size: 13))
                        .foregroundColor(linkBlue)
                }
            }
            .padding(.horizontal, 20)

            HStack(spacing: 12) {
                ForEach(Plan.allCases) { plan in
                    planCard(for: plan)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    private let linkBlue = Color(red: 0.40, green: 0.80, blue: 1.0)

    /// 协议勾选行：Agreement 《Auto Renewal Terms》, 《Membership Terms》（两处链接均跳 m.html）
    private var agreementRow: some View {
        HStack(alignment: .center, spacing: 6) {
            Button {
                isAgreementOn.toggle()
            } label: {
                Image(systemName: isAgreementOn ? "checkmark.circle.fill" : "circle")
                    .font(.system(size: 16))
                    .foregroundColor(isAgreementOn ? linkBlue : Color.white.opacity(0.5))
            }
            .buttonStyle(.plain)

            HStack(spacing: 0) {
                Text(language.text("vip.agreement"))
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                Link(destination: AppLinks.membershipTerms) {
                    Text(language.text("vip.terms.autoRenewal"))
                        .font(.system(size: 11))
                        .underline()
                        .foregroundColor(linkBlue)
                }
                Text(language.text("vip.terms.comma"))
                    .font(.system(size: 11))
                    .foregroundColor(.white)
                Link(destination: AppLinks.membershipTerms) {
                    Text(language.text("vip.terms.membership"))
                        .font(.system(size: 11))
                        .underline()
                        .foregroundColor(linkBlue)
                }
            }
        }
    }

    private func planCard(for plan: Plan) -> some View {
        let isSelected = plan == selectedPlan
        let product = productForPlan(plan)
        
        return ZStack(alignment: .topLeading) {
            // 背景卡片
            RoundedRectangle(cornerRadius: 18)
                .fill(
                    LinearGradient(
                        colors: isSelected
                        ? [
                            Color(red: 0.24, green: 0.55, blue: 1.0),
                            Color(red: 0.13, green: 0.34, blue: 0.86)
                          ]
                        : Array(repeating: Color.white.opacity(0.06), count: 2),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
                .frame(height: 120)
            
            // 左上角折角标签（橙色，固定高度 + 自适应宽度）
            if let badge = planBadge(plan) {
                Text(badge)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 6)
                    .frame(height: 16, alignment: .center) // 固定高度，宽度随文字变化
                    .background(
                        RoundedCorner(corners: [.topLeft, .bottomRight], radius: 8)
                            .fill(Color.orange)
                    )
                    .offset(x: -2, y: -3) // 稍微再往上抬一点点
            }
            
            // 文本内容
            VStack(spacing: 6) {
                Spacer().frame(height: 22)
                
                Text(planTitle(plan))
                    .font(.system(size: 15, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                
                if let product = product {
                    Text(product.displayPrice)
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    if let perDay = dailyPriceText(for: plan, product: product) {
                        Text(perDay)
                            .font(.system(size: 12))
                            .foregroundColor(.white.opacity(0.7))
                    }
                } else {
                    Text(language.text("vip.price.placeholder"))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white.opacity(0.5))
                }
                
                Spacer()
            }
            .frame(maxWidth: .infinity)
        }
        .onTapGesture {
            selectedPlan = plan
        }
    }

    /// 会员权益区域
    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(language.text("vip.benefits.title"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .padding(.horizontal, 20)

            VStack(spacing: 16) {
                benefitRow(
                    iconName: "iconSpeed",
                    title: language.text("vip.benefit.speed.title"),
                    subtitle: language.text("vip.benefit.speed.subtitle")
                )
                benefitRow(
                    iconName: "iconAd",
                    title: language.text("vip.benefit.adfree.title"),
                    subtitle: language.text("vip.benefit.adfree.subtitle")
                )
                benefitRow(
                    iconName: "iconServer",
                    title: language.text("vip.benefit.countries.title"),
                    subtitle: language.text("vip.benefit.countries.subtitle")
                )
            }
            .padding(.horizontal, 20)
        }
    }

    private func benefitRow(iconName: String, title: String, subtitle: String) -> some View {
        HStack(spacing: 12) {
            Image(iconName)
                .resizable()
                .scaledToFit()
                .frame(width: 32, height: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.white)
                Text(subtitle)
                    .font(.system(size: 12))
                    .foregroundColor(.white.opacity(0.7))
            }

            Spacer()
        }
        .padding(10)
    }

    /// 底部说明文案 + 条款链接（不含勾选行）
    private var disclaimerSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Terms & Conditions 主体说明
            Text(language.text("vip.disclaimer"))
                .font(.system(size: 12))
                .foregroundColor(.white.opacity(0.7))

            // 引导文案 + Terms of use / Privacy Policy 链接（可点击）
            VStack(alignment: .leading, spacing: 2) {
                Text(language.text("vip.disclaimer.more"))
                    .font(.system(size: 11))
                    .foregroundColor(.white.opacity(0.7))
                HStack(spacing: 0) {
                    Link(destination: AppLinks.privacyPolicy) {
                        Text(language.text("vip.terms.of.use"))
                            .font(.system(size: 11))
                            .underline()
                            .foregroundColor(linkBlue)
                    }
                    Text(language.text("vip.and"))
                        .font(.system(size: 11))
                        .foregroundColor(.white.opacity(0.7))
                    Link(destination: AppLinks.userAgreement) {
                        Text(language.text("vip.privacy.policy"))
                            .font(.system(size: 11))
                            .underline()
                            .foregroundColor(linkBlue)
                    }
                }
            }
        }
        .padding(.horizontal, 20)
    }

    /// 底部主按钮
    private var startButton: some View {
        Button {
            Task {
                _ = await premiumCenter.startCheckout(for: selectedPremiumPlan)
            }
        } label: {
            Text(language.text("vip.button.agreePay"))
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .background(
                    LinearGradient(
                        colors: [
                            Color(red: 0.16, green: 0.51, blue: 1.0),
                            Color(red: 0.21, green: 0.63, blue: 1.0)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(10)
        }
        .opacity(isAgreementOn && !premiumCenter.isBusyWithSubscription ? 1.0 : 0.4)
        .disabled(!isAgreementOn || premiumCenter.isBusyWithSubscription)
    }
}

#Preview {
    VipView()
        .environmentObject(SubscriptionAccessStore.sharedStore)
        .environmentObject(AppLanguageManager.shared)
}

