//
//  AppSettingsCache.swift
//  NexusVPN
//
//  应用设置缓存：负责保存和读取 AppSettings 接口返回的数据
//

import Foundation

/// 应用设置缓存（单例）
final class AppSettingsCache {
    
    static let shared = AppSettingsCache()
    
    /// UserDefaults key 用于保存原始 JSON 字符串
    private let configKey = "Wire.AppSettingsJSON"
    
    /// UserDefaults key 用于保存配置更新时间
    private let updateTimeKey = "Wire.AppSettingsUpdateTime"
    
    /// UserDefaults key 用于保存本地 Git 版本号
    private let localGitVersionKey = "Wire.AppSettingsLocalGitVersion"
    
    private init() {}
    
    // MARK: - 保存配置
    
    /// 保存 AppSettings JSON 字符串到缓存
    func keepCache(_ jsonString: String) {
        // 保存原始 JSON
        UserDefaults.standard.set(jsonString, forKey: configKey)
        
        // 保存更新时间
        let updateTime = Date()
        UserDefaults.standard.set(updateTime, forKey: updateTimeKey)
        
        UserDefaults.standard.synchronize()
        
        NVLog.log("Wire", "AppSettings 已保存到缓存，更新时间：\(updateTime)")
        
        // 打印关键字段（用于调试）
        if let adsOff = isAdsDisabled() {
            NVLog.log("Wire", "adsOff: \(adsOff)")
        }
        if let adsType = currentAdsType() {
            NVLog.log("Wire", "adsType: \(adsType)")
        }
        if let servers = probeServers() {
            NVLog.log("Wire", "detectionServers: \(servers)")
        }
        if let version = remoteGitVersion() {
            NVLog.log("Wire", "git_version: \(version)")
        }
    }
    
    // MARK: - 读取字段
    
    /// 是否关闭广告
    func isAdsDisabled() -> Bool? {
        // MARK: - 测试服
        //return false
        return extractField(path: ["commonConf", "adsOff"]) as? Bool
    }
    
    /// 当前广告类型
    func currentAdsType() -> String? {
        // MARK: - 测试服
        //return "e;a"
        return extractField(path: ["commonConf", "adsType"]) as? String
    }
    
    /// 接口返回的 Git 版本号
    func remoteGitVersion() -> Int? {
        return extractField(path: ["commonConf", "git_version"]) as? Int
    }
    
    /// 探测服务器列表
    func probeServers() -> [String]? {
        guard let detectionConfig = extractField(path: ["commonConf", "detectionConfig"]) as? [String: Any],
              let servers = detectionConfig["detectionServers"] as? [String] else {
            return nil
        }
        return servers
    }
    
    /// 配置最后更新时间
    func lastUpdateTime() -> Date? {
        return UserDefaults.standard.object(forKey: updateTimeKey) as? Date
    }
    
    // MARK: - Git 版本管理
    
    /// 获取本地保存的 Git 版本号
    func localGitVersion() -> Int {
        // 如果 key 不存在，返回默认值 1（避免第一次进入时触发不必要的 Git 更新）
        if UserDefaults.standard.object(forKey: localGitVersionKey) == nil {
            return 1
        }
        return UserDefaults.standard.integer(forKey: localGitVersionKey)
    }
    
    /// 保存本地 Git 版本号
    func saveLocalGitVersion(_ version: Int) {
        UserDefaults.standard.set(version, forKey: localGitVersionKey)
        UserDefaults.standard.synchronize()
        NVLog.log("Wire", "本地 Git 版本号已保存：\(version)")
    }
    
    // MARK: - 私有方法
    
    /// 从保存的配置中提取字段
    private func extractField(path: [String]) -> Any? {
        guard let jsonString = UserDefaults.standard.string(forKey: configKey),
              let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        
        var current: Any? = dict
        for key in path {
            if let dict = current as? [String: Any] {
                current = dict[key]
            } else {
                return nil
            }
        }
        return current
    }
}
