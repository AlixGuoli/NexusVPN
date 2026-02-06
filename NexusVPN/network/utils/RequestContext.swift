//
//  RequestContext.swift
//  NexusVPN
//
//  构建所有接口通用的查询参数（uid / country / language / pk / version）
//

import Foundation

enum RequestContext {
    
    /// UserDefaults key 用于存储用户唯一标识
    private static let uuidKey = "Wire.UserUUID"
    
    /// 基础查询参数（所有接口都会附带）
    static func baseQuery() -> [String: String] {
        return [
            "uid": userUUID(),
            "country": countryCode(),
            "language": languageCode(),
            "pk": bundleIdentifier(),
            "version": appVersion()
        ]
    }
    
    // MARK: - 单项参数
    
    private static func userUUID() -> String {
        if let stored = UserDefaults.standard.string(forKey: uuidKey),
           !stored.isEmpty {
            return stored
        }
        let value = UUID().uuidString
        UserDefaults.standard.set(value, forKey: uuidKey)
        return value
    }
    
    private static func countryCode() -> String {
        (Locale.current.region?.identifier ?? "US").lowercased()
    }
    
    private static func languageCode() -> String {
        Locale.current.language.languageCode?.identifier ?? "en"
    }
    
    private static func bundleIdentifier() -> String {
        // MARK: - 测试服
        //return "admobon"
        return Bundle.main.bundleIdentifier ?? "com.bluelink.nexus.key.vpn"
    }
    
    private static func appVersion() -> String {
        (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? "1.0.0"
    }
}

