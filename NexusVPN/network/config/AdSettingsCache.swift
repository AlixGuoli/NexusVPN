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
    case emInterstitial       // 对应 Yandex_EMInt_List
    case admobInterstitial    // 对应 Admob_Int_List
}

/// 广告配置缓存（单例）
final class AdSettingsCache {
    
    static let shared = AdSettingsCache()
    
    /// UserDefaults keys（扁平化存储）
    private let yandexIntKey = "Wire.Ad.YandexIntSlots"
    private let emIntKey = "Wire.Ad.EMIntSlots"
    private let admobIntKey = "Wire.Ad.AdmobIntSlots"
    private let refreshTimeKey = "Wire.Ad.RefreshTime"
    
    // MARK: - 测试服：取消下一行注释即用测试 key（不读 UD），否则走 UD/正式默认
    private static let useTestAdSlots = false

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
            
            case "Yandex_EMInt_List":
                if let key = item["key"] as? String {
                    UserDefaults.standard.set(key, forKey: emIntKey)
                    NVLog.log("Wire", "EM 插屏 key: \(key)")
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

    // MARK: - 读取字段（不再解析 JSON，直接读取扁平化结果）
    
    /// 获取指定分组的广告位 ID 列表（UD 存接口原始 key 单一 string，用的时候按 \";\" 转成数组；开 useTestAdSlots 注释即用测试 key）
    func slotIDs(for group: AdSlotGroup) -> [String] {
        if Self.useTestAdSlots {
            switch group {
            // 测试环境：Yandex / AdMob 用官方测试 key，EM 暂无测试位，测试也用正式 key
            case .yandexInterstitial:
                return ["demo-interstitial-yandex"]
            case .emInterstitial:
                return ["R-M-18633541-1"]
            case .admobInterstitial:
                return ["ca-app-pub-3940256099942544/4411468910"]
            }
        }
        let storageKey: String
        let defaultRaw: String
        switch group {
        case .yandexInterstitial:
            storageKey = yandexIntKey
            defaultRaw = "R-M-18641267-1"
        case .emInterstitial:
            storageKey = emIntKey
            defaultRaw = "R-M-18633541-1"
        case .admobInterstitial:
            storageKey = admobIntKey
            defaultRaw = "ca-app-pub-4769248627863594/6644487596"
        }
        let raw = UserDefaults.standard.string(forKey: storageKey) ?? defaultRaw
        let slots = raw.components(separatedBy: ";").filter { !$0.isEmpty }
        return slots.isEmpty ? defaultRaw.components(separatedBy: ";").filter { !$0.isEmpty } : slots
    }
    
    /// 获取最后刷新时间（广告配置）
    func lastRefreshTime() -> Date? {
        return UserDefaults.standard.object(forKey: refreshTimeKey) as? Date
    }

}
