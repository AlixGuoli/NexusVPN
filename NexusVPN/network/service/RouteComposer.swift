//
//  RouteComposer.swift
//  NexusVPN
//
//  路由配置编排器：
//  - 根据 ServiceProfile 生成最终的路由配置 JSON
//  - 收集直连域名（固定 + 从域名配置动态获取）
//  - 合并 routing.rules，保存到 App Group UserDefaults（供 nuts/xray 读取）
//

import Foundation

/// 路由配置编排器（单例）
final class RouteComposer {
    
    static let shared = RouteComposer()
    
    /// App Group UserDefaults suite name
    private let appGroupSuite = "group.com.bluelink.nexus.key.vpn"
    
    /// App Group UD 中保存配置的 key
    private let configKey = "Wire.Target.Config"
    
    /// App Group UD 中保存配置时间的 key
    private let timestampKey = "Wire.Target.Timestamp"
    
    private init() {}
    
    // MARK: - 应用配置并落地
    
    /// 应用服务配置并保存到 App Group UD
    /// - Parameters:
    ///   - profile: 服务配置结构体
    ///   - source: 配置来源（用于决定 IP 上报标记）
    func apply(profile: ServiceProfile, source: ServiceSource) async {
        NVLog.log("Wire", "[Wire] 开始处理路由配置（来源：\(source == .online ? "接口" : "缓存")）")
        
        // 1. 解析配置字典
        var config = profile.configDict
        
        // 2. 更新 inbound 配置
        config = updateInbound(config)
        
        // 3. 增强路由配置（添加直连规则）
        config = enrichRouting(config)
        
        // 4. 序列化为 JSON 字符串
        guard let finalJSON = serializeConfig(config) else {
            NVLog.log("Wire", "[Wire] 路由配置序列化失败")
            return
        }
        
        // 5. 保存到 App Group UD
        await persistToGroup(finalJSON)
        
        NVLog.log("Wire", "[Wire] ✅ 路由配置已保存到 App Group UD")
    }
    
    // MARK: - 配置处理
    
    /// 更新 inbound 配置（设置本地代理端口）
    private func updateInbound(_ config: [String: Any]) -> [String: Any] {
        var updated = config
        guard var inbounds = updated["inbounds"] as? [[String: Any]],
              !inbounds.isEmpty else {
            NVLog.log("Wire", "[Wire] 未找到 inbounds 配置")
            return updated
        }
        
        var firstInbound = inbounds[0]
        firstInbound["listen"] = "[::1]"
        firstInbound["port"] = "8080"
        inbounds[0] = firstInbound
        updated["inbounds"] = inbounds
        
        NVLog.log("Wire", "[Wire] 已更新 inbound 配置：listen=[::1], port=8080")
        return updated
    }
    
    /// 增强路由配置（收集直连域名并构建 rules）
    private func enrichRouting(_ config: [String: Any]) -> [String: Any] {
        let directDomains = collectDirectDomains()
        let routingRules = buildDirectRules(directDomains)
        return injectRoutingRules(config, rules: routingRules)
    }
    
    /// 收集需要直连的域名列表
    private func collectDirectDomains() -> [String] {
        var domains: [String] = []
        
        // 固定域名
        let fixedDomains = [
            "yastatic", "yandex", "gameanalytics", "mradx.net",
            "target.my.com", "vk.ru", "vk.me", "vk.com", "mail.ru"
        ]
        domains.append(contentsOf: fixedDomains)
        NVLog.log("Wire", "[Wire] 固定直连域名：\(fixedDomains.joined(separator: ", "))")
        
        // 动态域名（从域名配置中获取）
        let dynamicDomains = resolveDynamicDomains()
        domains.append(contentsOf: dynamicDomains)
        
        if !dynamicDomains.isEmpty {
            NVLog.log("Wire", "[Wire] 动态直连域名：\(dynamicDomains.joined(separator: ", "))")
        }
        
        return domains
    }
    
    /// 从域名配置中解析动态直连域名
    private func resolveDynamicDomains() -> [String] {
        var domains: [String] = []
        
        guard let hostConfig = ConfigVault.shared.loadActiveConfig(),
              let apiDict = hostConfig["api"] as? [String: Any] else {
            NVLog.log("Wire", "[Wire] 无法获取域名配置，跳过动态域名")
            return domains
        }
        
        // 获取 connReport 域名
        if let connReport = apiDict["connreport"] as? String,
           let connHost = URL(string: connReport)?.host {
            domains.append(connHost)
            NVLog.log("Wire", "[Wire] 添加 connReport 域名：\(connHost)")
        }
        
        // 获取 genReport 域名
        if let genReport = apiDict["greport"] as? String,
           let genHost = URL(string: genReport)?.host {
            domains.append(genHost)
            NVLog.log("Wire", "[Wire] 添加 genReport 域名：\(genHost)")
        }
        
        // 获取 hostList 域名
        if let hosts = apiDict["host"] as? [String] {
            let hostDomains = hosts.compactMap { URL(string: $0)?.host }
            domains.append(contentsOf: hostDomains)
            NVLog.log("Wire", "[Wire] 添加 hostList 域名：\(hostDomains.joined(separator: ", "))")
        }
        
        return domains
    }
    
    /// 构建直连规则
    private func buildDirectRules(_ domains: [String]) -> [[String: Any]] {
        var rules: [[String: Any]] = []
        
        // 固定规则：raw.githubusercontent.com 单独处理
        rules.append([
            "type": "field",
            "domain": ["raw.githubusercontent.com"],
            "outboundTag": "direct"
        ])
        
        // 动态规则：其他域名
        if !domains.isEmpty {
            rules.append([
                "type": "field",
                "domain": domains,
                "outboundTag": "direct"
            ])
        }
        
        NVLog.log("Wire", "[Wire] 构建了 \(rules.count) 条直连规则")
        return rules
    }
    
    /// 注入路由规则到配置中
    private func injectRoutingRules(_ config: [String: Any], rules: [[String: Any]]) -> [String: Any] {
        var merged = config
        
        if merged["routing"] == nil {
            merged["routing"] = [
                "domainStrategy": "AsIs",
                "rules": rules
            ]
        } else if var routing = merged["routing"] as? [String: Any] {
            routing["rules"] = rules
            merged["routing"] = routing
        }
        
        return merged
    }
    
    /// 序列化配置字典为 JSON 字符串（紧凑单行，便于日志完整展示）
    private func serializeConfig(_ config: [String: Any]) -> String? {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: config, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return nil
        }
        return jsonString
    }
    
    // MARK: - 持久化
    
    /// 保存配置到 App Group UserDefaults
    private func persistToGroup(_ config: String) async {
        guard let groupDefaults = UserDefaults(suiteName: appGroupSuite) else {
            NVLog.log("Wire", "[Wire] ❌ 无法创建 App Group UserDefaults")
            return
        }
        
        let timestamp = Date()
        groupDefaults.set(timestamp, forKey: timestampKey)
        groupDefaults.set(config, forKey: configKey)
        groupDefaults.synchronize()
        
        NVLog.log("Wire", "[Wire] 配置已保存到 App Group UD，时间戳：\(timestamp)")
        // 这里打印的 config 已经是单行 JSON，方便在日志里完整查看
        NVLog.log("Wire", "[Wire] 最终路由配置内容：\(config)")
    }
}
