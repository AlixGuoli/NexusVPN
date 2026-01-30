//
//  WireGroupKeys.swift
//  NexusVPN
//
//  App Group 共享存储常量，主 App 与 Extension 共用。
//  需同时加入主 App 与 Extension target 的 Compile Sources，Extension 才能用同一套 key 读取配置。
//

import Foundation

/// App Group 读写用的 suite 名与 key（主 App 写，Extension 读）
enum WireGroupKeys {
    
    /// UserDefaults(suiteName:) 的 suite 标识
    static let suiteName = "group.com.bluelink.nexus.key.vpn"
    
    /// 写入的配置 JSON 字符串的 key
    static let configKey = "Wire.Target.Config"
    
    /// 写入配置时的时间戳的 key
    static let timestampKey = "Wire.Target.Timestamp"
}
