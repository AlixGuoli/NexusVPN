//
//  ConnectReportContext.swift
//  NexusVPN
//
//  连接上报上下文：
//  - 保存当前连接使用的 IP 地址（用于上报）
//  - 根据配置来源决定是否添加 "f" 前缀（cached 配置加 "f"，online 配置不加）
//

import Foundation

/// 连接上报上下文（单例）
final class ConnectReportContext {
    
    static let shared = ConnectReportContext()
    
    /// 当前连接使用的 IP 地址（用于上报）
    /// - 如果配置来源是 .online，则为原始 IP
    /// - 如果配置来源是 .cached，则为 "f" + IP
    private(set) var currentEndpoint: String?
    
    private init() {}
    
    /// 更新当前端点（根据配置来源决定是否加前缀）
    /// - Parameters:
    ///   - ip: 服务器 IP 地址
    ///   - source: 配置来源
    func updateEndpoint(ip: String, source: ServiceSource) {
        let finalIP = source == .online ? ip : "f\(ip)"
        currentEndpoint = finalIP
        
        if ip != finalIP {
            NVLog.log("Wire", "[Wire] 上报端点已更新：\(ip) -> \(finalIP)（来源：缓存）")
        } else {
            NVLog.log("Wire", "[Wire] 上报端点已更新：\(ip)（来源：接口）")
        }
    }
    
    /// 清除当前端点
    func clear() {
        currentEndpoint = nil
    }
}
