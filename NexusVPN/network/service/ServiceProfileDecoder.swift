//
//  ServiceProfileDecoder.swift
//  NexusVPN
//
//  服务配置解码器：
//  - 解密加密配置字符串
//  - 解析成 ServiceProfile 结构体（包含 IP、outbounds、routing 等）
//

import Foundation

/// 服务配置结构体（解密后的配置内容）
struct ServiceProfile {
    /// 服务 IP 地址（从 outbounds[].settings.vnext[].address 提取）
    let serverIP: String
    
    /// 完整的配置 JSON 字典（用于后续路由处理）
    let configDict: [String: Any]
    
    /// 解密后的原始 JSON 字符串（用于最终序列化）
    let rawJSON: String
}

/// 服务配置解码器（无状态）
struct ServiceProfileDecoder {
    
    /// AES 密钥字符串（与服务配置解密保持一致）
    private static let rawAESKey = "f92mUj0K1uBnMlXGFQKrYP07Emgc4yFmWYS8WRgy4IY="
    
    /// 解码服务配置：解密 + 解析
    /// - Parameter cipher: 加密配置字符串
    /// - Returns: ServiceProfile，失败返回 nil
    static func decode(_ cipher: String) -> ServiceProfile? {
        // MARK: - 测试服 手动模拟解密/解析失败
//        NVLog.log("Wire", "[Wire] ⚠️ 手动模拟服务配置解密失败")
//        return nil
        
        // 1. 解密
        guard let decryptedJSON = ShieldDecoder.decodeConfig(cipher, keyString: rawAESKey) else {
            NVLog.log("Wire", "[Wire] 服务配置解密失败")
            return nil
        }
        
        // 2. 解析 JSON
        guard let data = decryptedJSON.data(using: .utf8),
              let configDict = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] else {
            NVLog.log("Wire", "[Wire] 服务配置 JSON 解析失败")
            return nil
        }
        
        // 3. 提取 IP 地址
        guard let serverIP = extractServerIP(from: configDict) else {
            NVLog.log("Wire", "[Wire] 服务配置中未找到 IP 地址")
            return nil
        }
        
        NVLog.log("Wire", "[Wire] 服务配置解码成功，IP: \(serverIP)")
        return ServiceProfile(serverIP: serverIP, configDict: configDict, rawJSON: decryptedJSON)
    }
    
    /// 从配置字典中提取服务器 IP 地址
    /// - Parameter config: 配置字典
    /// - Returns: IP 地址字符串，未找到返回 nil
    private static func extractServerIP(from config: [String: Any]) -> String? {
        guard let outbounds = config["outbounds"] as? [[String: Any]] else {
            return nil
        }
        
        for bound in outbounds {
            guard let settings = bound["settings"] as? [String: Any],
                  let vnext = settings["vnext"] as? [[String: Any]] else {
                continue
            }
            
            for node in vnext {
                if let address = node["address"] as? String {
                    return address
                }
            }
        }
        
        return nil
    }
}
