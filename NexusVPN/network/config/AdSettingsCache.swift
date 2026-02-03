//
//  AdSettingsCache.swift
//  NexusVPN
//
//  广告配置缓存：负责保存和读取广告配置接口返回的数据
//  写入时解析并扁平化存储，读取时不再解析 JSON
//

import Foundation

/// 广告位分组枚举
enum AdSlotGroup {
    case yandexInterstitial   // 对应 Yandex_Int_List
    case yandexBanner         // 对应 Yandex_Banner_List
    case admobInterstitial    // 对应 Admob_Int_List
}

/// 广告配置缓存（单例）
final class AdSettingsCache {
    
    static let shared = AdSettingsCache()
    
    /// UserDefaults keys（扁平化存储）
    private let yandexIntKey = "Wire.Ad.YandexIntSlots"
    private let yandexBannerKey = "Wire.Ad.YandexBannerSlots"
    private let admobIntKey = "Wire.Ad.AdmobIntSlots"
    private let overlayRateKey = "Wire.Ad.OverlayRate"
    private let tapDelayKey = "Wire.Ad.TapDelay"
    private let refreshTimeKey = "Wire.Ad.RefreshTime"
    private let skipLocationKey = "Wire.Ad.Skip.Location"
    private let skipXKey = "Wire.Ad.Skip.X"
    private let skipYKey = "Wire.Ad.Skip.Y"
    
    // MARK: - 测试服：取消下一行注释即用测试 key（不读 UD），否则走 UD/正式默认
    private static let useTestAdSlots = true

    private init() {}
    
    // MARK: - 保存配置
    
    /// 保存广告配置 JSON（写入时解析并扁平化存储）
    func keepCache(_ payload: String) {
        guard let data = payload.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let adConfig = dict["adConfig"] as? [String: Any],
              let adMixed = adConfig["adMixed"] as? [[String: Any]] else {
            NVLog.log("Wire", "广告配置 JSON 解析失败")
            return
        }
        
        // 遍历 adMixed 数组，提取需要的字段
        for item in adMixed {
            guard let name = item["name"] as? String else { continue }
            
            switch name {
            case "Yandex_Int_List":
                if let key = item["key"] as? String {
                    UserDefaults.standard.set(key, forKey: yandexIntKey)
                    NVLog.log("Wire", "Yandex 插屏 key: \(key)")
                }
                
            case "Yandex_Banner_List":
                if let key = item["key"] as? String {
                    UserDefaults.standard.set(key, forKey: yandexBannerKey)
                    NVLog.log("Wire", "Yandex Banner key: \(key)")
                }
                // 提取穿透率和点击延迟
                if let penetrate = item["penetrate"] as? Int {
                    UserDefaults.standard.set(penetrate, forKey: overlayRateKey)
                    NVLog.log("Wire", "穿透率: \(penetrate)")
                }
                if let delay = item["clickDelayPenet"] as? Int {
                    UserDefaults.standard.set(delay, forKey: tapDelayKey)
                    NVLog.log("Wire", "点击延迟: \(delay)")
                }
                
            case "Admob_Int_List":
                if let key = item["key"] as? String {
                    UserDefaults.standard.set(key, forKey: admobIntKey)
                    NVLog.log("Wire", "AdMob 插屏 key: \(key)")
                }
                
            default:
                break
            }
        }
        
        // 保存刷新时间
        let refreshTime = Date()
        UserDefaults.standard.set(refreshTime, forKey: refreshTimeKey)
        UserDefaults.standard.synchronize()
        
        NVLog.log("Wire", "广告配置已扁平化保存，刷新时间：\(refreshTime)")
    }

    // MARK: - 跳过按钮布局（与广告配置绑定的 pageConfig）

    /// 跳过按钮位置描述
    struct AdSkipPlacement {
        let position: Int   // location
        let offsetX: Int    // x
        let offsetY: Int    // y

        static let fallback = AdSkipPlacement(position: 0, offsetX: 20, offsetY: 100)
    }

    /// 保存跳过按钮布局 JSON（getpageconfig /education/page/campus）
    func keepSkipLayout(_ payload: String) {
        guard let data = payload.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let pageConfig = dict["pageconfig"] as? [String: Any] else {
            NVLog.log("Wire", "跳过按钮布局 JSON 解析失败")
            return
        }

        let location = pageConfig["location"] as? Int ?? AdSkipPlacement.fallback.position
        let x = pageConfig["x"] as? Int ?? AdSkipPlacement.fallback.offsetX
        let y = pageConfig["y"] as? Int ?? AdSkipPlacement.fallback.offsetY

        UserDefaults.standard.set(location, forKey: skipLocationKey)
        UserDefaults.standard.set(x, forKey: skipXKey)
        UserDefaults.standard.set(y, forKey: skipYKey)
        UserDefaults.standard.synchronize()

        NVLog.log("Wire", "跳过按钮布局已保存：location=\(location), x=\(x), y=\(y)")
    }
    
    // MARK: - 读取字段（不再解析 JSON，直接读取扁平化结果）
    
    /// 获取指定分组的广告位 ID 列表（UD 存接口原始 key 单一 string，用的时候按 ";" 转成数组；开 useTestAdSlots 注释即用测试 key）
    func slotIDs(for group: AdSlotGroup) -> [String] {
        if Self.useTestAdSlots {
            switch group {
            case .yandexInterstitial: return ["demo-interstitial-yandex"]
            case .yandexBanner: return ["demo-banner-yandex"]
            case .admobInterstitial: return ["ca-app-pub-3940256099942544/4411468910"]
            }
        }
        let storageKey: String
        let defaultRaw: String
        switch group {
        case .yandexInterstitial:
            storageKey = yandexIntKey
            defaultRaw = "demo-interstitial-yandex"
        case .yandexBanner:
            storageKey = yandexBannerKey
            defaultRaw = "demo-banner-yandex"
        case .admobInterstitial:
            storageKey = admobIntKey
            defaultRaw = "ca-app-pub-3940256099942544/4411468910"
        }
        let raw = UserDefaults.standard.string(forKey: storageKey) ?? defaultRaw
        let slots = raw.components(separatedBy: ";").filter { !$0.isEmpty }
        return slots.isEmpty ? defaultRaw.components(separatedBy: ";").filter { !$0.isEmpty } : slots
    }
    
    /// 获取穿透率（默认 100）
    func overlayRate() -> Int {
        if UserDefaults.standard.object(forKey: overlayRateKey) != nil {
            return UserDefaults.standard.integer(forKey: overlayRateKey)
        }
        return 100
    }
    
    /// 获取点击延迟权重（默认 15）
    func tapDelayWeight() -> Int {
        if UserDefaults.standard.object(forKey: tapDelayKey) != nil {
            return UserDefaults.standard.integer(forKey: tapDelayKey)
        }
        return 15
    }
    
    /// 获取最后刷新时间（广告配置）
    func lastRefreshTime() -> Date? {
        return UserDefaults.standard.object(forKey: refreshTimeKey) as? Date
    }

    /// 当前跳过按钮位置（如果未配置则返回默认值）
    func currentSkipPlacement() -> AdSkipPlacement {
        let hasLocation = UserDefaults.standard.object(forKey: skipLocationKey) != nil
        let position = hasLocation ? UserDefaults.standard.integer(forKey: skipLocationKey) : AdSkipPlacement.fallback.position

        let hasX = UserDefaults.standard.object(forKey: skipXKey) != nil
        let x = hasX ? UserDefaults.standard.integer(forKey: skipXKey) : AdSkipPlacement.fallback.offsetX

        let hasY = UserDefaults.standard.object(forKey: skipYKey) != nil
        let y = hasY ? UserDefaults.standard.integer(forKey: skipYKey) : AdSkipPlacement.fallback.offsetY

        return AdSkipPlacement(position: position, offsetX: x, offsetY: y)
    }
}
