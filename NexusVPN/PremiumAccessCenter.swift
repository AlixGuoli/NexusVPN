//
//  PremiumAccessCenter.swift
//  NexusVPN
//
//  内购中心（精简版）：负责订阅产品加载、购买、恢复、订阅状态管理。
//  逻辑参考原项目 GVPurchaseManager，但只保留当前 Nexus 需要的部分。
//

import Foundation
import StoreKit
import Combine

/// 当前 App 支持的订阅通行证档位
enum SubscriptionPack: String, CaseIterable {
    case weeklyPack  = "com.bluelink.nexus.key.vpn.weekly"
    case monthlyPack = "com.bluelink.nexus.key.vpn.monthly"
    case yearlyPack  = "com.bluelink.nexus.key.vpn.annual"
}

@MainActor
final class SubscriptionAccessStore: ObservableObject {
    
    static let sharedStore = SubscriptionAccessStore()
    
    // 本地缓存键（订阅状态本地快照）
    private let subscriptionFlagKey = "SubscriptionAccessStore_Sub_Flag"
    private let subscriptionExpirationKey = "SubscriptionAccessStore_Sub_Expiration"
    private let subscriptionProductIdKey = "SubscriptionAccessStore_Sub_ProductId"
    
    /// 支持的订阅产品 ID 列表
    private let packProductIds: Set<String> = Set(SubscriptionPack.allCases.map(\.rawValue))
    
    /// 已加载的订阅商品
    @Published private(set) var loadedPacks: [Product] = []
    
    /// 是否正在加载商品列表
    @Published private(set) var isLoadingPacks: Bool = false
    /// 是否正在拉起购买流程
    @Published private(set) var isRunningCheckout: Bool = false
    /// 是否正在从 Store 恢复
    @Published private(set) var isSyncingFromStore: Bool = false
    
    /// 当前是否有有效订阅
    @Published private(set) var hasSubscription: Bool = false
    
    /// 当前订阅结束时间
    @Published private(set) var subscriptionEndDate: Date? = nil
    
    /// 当前订阅对应的 Product ID
    @Published private(set) var currentPackProductId: String? = nil
    
    /// 对外：是否有有效订阅
    var hasActiveSubscription: Bool { hasSubscription }
    
    /// 是否有任意订阅相关操作在进行中
    var isBusyWithSubscription: Bool {
        isLoadingPacks || isRunningCheckout || isSyncingFromStore
    }
    
    private init() {
        // 启动时尝试用缓存还原一次订阅状态
        restoreSubscriptionFromCache()
        NVLog.log("Subscription", "SubscriptionAccessStore init, cached hasSubscription = \(hasSubscription)")
        
        // 启动时检查订阅状态，并监听交易更新
        Task {
            await refreshSubscriptionStatus()
            await observeSubscriptionTransactions()
        }
    }
    
    // MARK: - 产品加载
    
    /// 加载订阅商品列表
    func loadPacks() async {
        guard !isLoadingPacks else { return }
        
        isLoadingPacks = true
        defer { isLoadingPacks = false }
        
        do {
            let loadedProducts = try await Product.products(for: packProductIds)
            loadedPacks = loadedProducts
            NVLog.log("Subscription", "✅ 加载订阅商品成功，数量：\(loadedProducts.count)")
            loadedProducts.forEach { p in
                NVLog.log("Subscription", "  商品：\(p.id)，价格：\(p.displayPrice)")
            }
        } catch {
            NVLog.log("Subscription", "❌ 加载订阅商品失败：\(error.localizedDescription)")
        }
    }
    
    /// 根据档位获取对应的 Product
    func packProduct(for pack: SubscriptionPack) -> Product? {
        loadedPacks.first { $0.id == pack.rawValue }
    }
    
    // MARK: - 购买（对外按 plan）
    
    func startCheckout(for pack: SubscriptionPack) async -> Bool {
        if let product = packProduct(for: pack) {
            return await performCheckout(with: product)
        } else {
            NVLog.log("Subscription", "找不到订阅商品 \(pack.rawValue)，先加载列表")
            await loadPacks()
            guard let product = packProduct(for: pack) else {
                NVLog.log("Subscription", "重新加载后仍未找到订阅商品 \(pack.rawValue)")
                return false
            }
            return await performCheckout(with: product)
        }
    }
    
    // MARK: - 购买（底层按 Product）
    
    private func performCheckout(with product: Product) async -> Bool {
        isRunningCheckout = true
        defer { isRunningCheckout = false }
        
        do {
            let result = try await product.purchase()
            
            switch result {
            case .success(let verification):
                let transaction = try verifyStoreTransaction(verification)
                
                NVLog.log("Subscription", "交易详情：productID=\(transaction.productID)，transactionID=\(transaction.id)")
                
                await transaction.finish()
                await rebuildSubscriptionSnapshot()
                
                NVLog.log("Subscription", "✅ 订阅购买成功：\(product.id)")
                return true
                
            case .userCancelled:
                NVLog.log("Subscription", "用户取消购买")
                return false
                
            case .pending:
                NVLog.log("Subscription", "购买待处理")
                return false
                
            @unknown default:
                NVLog.log("Subscription", "未知购买结果")
                return false
            }
        } catch {
            NVLog.log("Subscription", "❌ 购买失败：\(error.localizedDescription)")
            return false
        }
    }
    
    // MARK: - 恢复购买
    
    func restoreSubscription() async {
        NVLog.log("Subscription", "开始恢复订阅")
        isSyncingFromStore = true
        defer { isSyncingFromStore = false }
        
        await rebuildSubscriptionSnapshot()
        NVLog.log("Subscription", "恢复订阅完成，当前 hasSubscription=\(hasSubscription)")
    }
    
    // MARK: - 订阅状态检查
    
    func refreshSubscriptionStatus() async {
        await rebuildSubscriptionSnapshot()
    }
    
    private func rebuildSubscriptionSnapshot() async {
        let now = Date()
        
        NVLog.log("Subscription", "开始刷新订阅状态快照...")
        let (latestExpiration, latestProductId) = await latestEntitlement()

        if let expiration = latestExpiration, expiration > now {
            hasSubscription = true
            subscriptionEndDate = expiration
            currentPackProductId = latestProductId
            NVLog.log("Subscription", "订阅有效：productID=\(latestProductId ?? "nil")，结束时间=\(expiration)")
            
            writeSubscriptionCache(expiration: expiration, productId: latestProductId)
        } else {
            hasSubscription = false
            subscriptionEndDate = nil
            currentPackProductId = nil
            NVLog.log("Subscription", "未找到有效订阅或已全部过期")

            clearSubscriptionCache()
        }
    }
    
    // MARK: - 交易更新监听
    
    private func observeSubscriptionTransactions() async {
        for await result in Transaction.updates {
            do {
                let transaction = try verifyStoreTransaction(result)
                
                await rebuildSubscriptionSnapshot()
                await transaction.finish()
            } catch {
                NVLog.log("Subscription", "❌ 处理交易更新失败：\(error.localizedDescription)")
            }
        }
    }
    
    // MARK: - 本地缓存还原
    
    private func restoreSubscriptionFromCache() {
        let defaults = UserDefaults.standard
        
        let cachedFlag = defaults.object(forKey: subscriptionFlagKey) as? Bool ?? false
        let cachedExpirationInterval = defaults.object(forKey: subscriptionExpirationKey) as? TimeInterval
        let cachedProductId = defaults.string(forKey: subscriptionProductIdKey)
        
        if cachedFlag, let interval = cachedExpirationInterval {
            let expiration = Date(timeIntervalSince1970: interval)
            if expiration > Date() {
                self.hasSubscription = true
                self.subscriptionEndDate = expiration
                self.currentPackProductId = cachedProductId
                NVLog.log("Subscription", "🔁 使用缓存还原订阅状态，结束时间：\(expiration)")
                writeSubscriptionCache(expiration: expiration, productId: cachedProductId)
                return
            }
        }
        
        self.hasSubscription = false
        self.subscriptionEndDate = nil
        self.currentPackProductId = nil
        clearSubscriptionCache()
    }
    
    // MARK: - 交易验证
    
    private func verifyStoreTransaction<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw SubscriptionError.failedVerification
        case .verified(let safe):
            return safe
        }
    }
    
    enum SubscriptionError: Error {
        case failedVerification
    }
}

// MARK: - 私有辅助

private extension SubscriptionAccessStore {
    /// 遍历当前 entitlement，返回最新一次订阅的过期时间和 productId
    func latestEntitlement() async -> (expiration: Date?, productId: String?) {
        var latestExpiration: Date? = nil
        var latestProductId: String? = nil

        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try verifyStoreTransaction(result)

                guard packProductIds.contains(transaction.productID) else {
                    continue
                }

                let expiration = transaction.expirationDate ?? .distantFuture

                if latestExpiration == nil || expiration > latestExpiration! {
                    latestExpiration = expiration
                    latestProductId = transaction.productID
                }
            } catch {
                NVLog.log("Subscription", "验证 entitlement 失败：\(error.localizedDescription)")
            }
        }

        return (latestExpiration, latestProductId)
    }

    /// 写入订阅缓存快照
    func writeSubscriptionCache(expiration: Date, productId: String?) {
        let defaults = UserDefaults.standard
        defaults.set(true, forKey: subscriptionFlagKey)
        defaults.set(expiration.timeIntervalSince1970, forKey: subscriptionExpirationKey)
        defaults.set(productId, forKey: subscriptionProductIdKey)
    }

    /// 清空订阅缓存快照
    func clearSubscriptionCache() {
        let defaults = UserDefaults.standard
        defaults.set(false, forKey: subscriptionFlagKey)
        defaults.removeObject(forKey: subscriptionExpirationKey)
        defaults.removeObject(forKey: subscriptionProductIdKey)
    }
}

