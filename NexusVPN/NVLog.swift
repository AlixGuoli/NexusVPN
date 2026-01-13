//
//  NVLog.swift
//  NexusVPN
//
//  统一日志输出工具，便于在控制台筛选。
//

import Foundation

enum NVLog {
    
    /// 统一前缀，方便在 Xcode 控制台中过滤
    private static let prefix = "[NVVPN]"
    
    /// 简单日志输出，仅在 DEBUG 构建下生效
    static func log(_ tag: String, _ message: String) {
        #if DEBUG
        print("\(prefix) [\(tag)] \(message)")
        #endif
    }
}

