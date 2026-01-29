//
//  ServiceSnapshotCenter.swift
//  NexusVPN
//
//  服务配置密文管理中心：
//  - 管理当前使用的加密配置字符串（接口成功优先，失败回退到 UD）
//  - 标记配置来源（用于上报区分：远程配置 vs 本地缓存）
//

import Foundation

/// 服务配置来源标记
enum ServiceSource {
    case online    // 来自接口请求（等价旧项目的 isRemote = true）
    case cached    // 来自 UserDefaults 缓存（等价旧项目的 isRemote = false）
}

/// 服务配置密文管理中心（单例）
final class ServiceSnapshotCenter {
    
    static let shared = ServiceSnapshotCenter()
    
    /// UserDefaults key 用于保存加密配置字符串
    private let cipherStorageKey = "Wire.ServiceCipher"
    
    /// 当前使用的加密配置（内存中）
    private(set) var currentCipher: String?
    
    /// 当前配置的来源标记
    private(set) var source: ServiceSource = .cached
    
    private init() {}
    
    // MARK: - 更新配置
    
    /// 从接口更新配置（接口成功时调用）
    func updateFromRemote(cipher: String) {
        currentCipher = cipher
        source = .online
        
        // 异步保存到 UserDefaults（作为下次 fallback 用）
        UserDefaults.standard.set(cipher, forKey: cipherStorageKey)
        UserDefaults.standard.synchronize()
        
        NVLog.log("Wire", "[Wire] 服务配置已更新（来源：接口），已保存到 UD")
    }
    
    /// 从 UserDefaults 回退（接口失败时调用）
    /// - Returns: 如果 UD 中有配置则返回，否则返回 nil
    func fallbackFromStorage() -> String? {
        guard let storedCipher = UserDefaults.standard.string(forKey: cipherStorageKey),
              !storedCipher.isEmpty else {
            NVLog.log("Wire", "[Wire] UserDefaults 中没有服务配置，无法回退")
            return nil
        }
        
        currentCipher = storedCipher
        source = .cached
        
        NVLog.log("Wire", "[Wire] 服务配置已回退到 UserDefaults（来源：缓存）")
        return storedCipher
    }
    
    /// 清除当前配置（用于重置状态）
    func clear() {
        currentCipher = nil
        source = .cached
    }
}
