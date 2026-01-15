//
//  Relay.swift
//  NexusVPN
//
//  节点数据模型
//

import Foundation

/// VPN 节点数据模型
struct Relay: Identifiable, Hashable {
    /// 节点唯一标识符（必需）
    let id: Int
    
    /// 节点显示名称（UI 装饰）
    let name: String
    
    /// 国家/地区代码（UI 装饰，如 "us", "jp", "auto"）
    let countryCode: String
    
    /// 假延迟（毫秒，UI 装饰）
    var latency: Int
    
    /// 节点状态（UI 装饰：0=优秀, 1=良好, 2=一般）
    var status: Int
    
    init(
        id: Int,
        name: String,
        countryCode: String,
        latency: Int = 0,
        status: Int = 0
    ) {
        self.id = id
        self.name = name
        self.countryCode = countryCode
        self.latency = latency
        self.status = status
    }
}
