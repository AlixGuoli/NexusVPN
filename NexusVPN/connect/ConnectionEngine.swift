//
//  ConnectionEngine.swift
//  NexusVPN
//
//  负责与系统 VPN 配置和隧道进行交互的轻量封装。
//

import Foundation
import NetworkExtension

/// 对 `NETunnelProviderManager` 做的一层包装，供上层 ViewModel 使用。
final class ConnectionEngine {
    
    static let shared = ConnectionEngine()
    
    /// 当前使用的配置管理器
    private(set) var manager: NETunnelProviderManager?
    
    private init() {}
    
    // MARK: - 配置加载与创建
    
    /// 加载已有的 VPN 配置；如不存在则创建一份新的。
    /// - Parameter completion: 如果过程中发生错误则返回，否则为 `nil`。
    func prepareConfiguration(completion: @escaping (Error?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            if let error = error {
                NVLog.log("Engine", "loadAllFromPreferences 失败: \(error.localizedDescription)")
                completion(error)
                return
            }
            
            guard let self = self else {
                completion(nil)
                return
            }
            
            if let existing = managers?.first {
                self.manager = existing
                // 复用已有配置，这里不用重复打点
                completion(nil)
                return
            }
            
            // 没有任何配置时，创建一份新的基础配置
            let newManager = NETunnelProviderManager()
            let proto = NETunnelProviderProtocol()
            proto.serverAddress = "Nexus VPN"
            newManager.protocolConfiguration = proto
            newManager.localizedDescription = "Nexus VPN"
            
            newManager.saveToPreferences { error in
                if let error = error {
                    NVLog.log("Engine", "saveToPreferences(新配置) 失败: \(error.localizedDescription)")
                    completion(error)
                    return
                }
                
                newManager.loadFromPreferences { loadError in
                    if loadError == nil {
                        self.manager = newManager
                    } else if let loadError = loadError {
                        NVLog.log("Engine", "loadFromPreferences(新配置) 失败: \(loadError.localizedDescription)")
                    }
                    completion(loadError)
                }
            }
        }
    }
    
    /// 仅尝试恢复已存在的配置，不会在系统中创建新的配置。
    /// - Parameter completion: `hasConfig` 表示是否找到已有配置。
    func restoreExistingConfiguration(completion: @escaping (_ hasConfig: Bool, _ error: Error?) -> Void) {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, error in
            if let error = error {
                NVLog.log("Engine", "restoreExistingConfiguration 失败: \(error.localizedDescription)")
                completion(false, error)
                return
            }
            
            guard let first = managers?.first else {
                completion(false, nil)
                return
            }
            
            self?.manager = first
            completion(true, nil)
        }
    }
    
    /// 保存并启用当前配置。
    func enableCurrentConfiguration(completion: @escaping (Error?) -> Void) {
        guard let manager else {
            completion(nil)
            return
        }
        
        manager.isEnabled = true
        manager.saveToPreferences { error in
            if let error = error {
                NVLog.log("Engine", "saveToPreferences(启用) 失败: \(error.localizedDescription)")
                completion(error)
                return
            }
            
            manager.loadFromPreferences { loadError in
                if let loadError = loadError {
                    NVLog.log("Engine", "loadFromPreferences(启用) 失败: \(loadError.localizedDescription)")
                }
                completion(loadError)
            }
        }
    }
    
    // MARK: - 连接控制
    
    /// 当前连接状态
    var vpnStatus: NEVPNStatus {
        manager?.connection.status ?? .invalid
    }
    
    /// 尝试启动 VPN 隧道。
    func startTunnel(completion: @escaping (Error?) -> Void) {
        guard let manager else {
            completion(nil)
            return
        }
        
        let status = manager.connection.status
        guard status == .disconnected || status == .invalid else {
            completion(nil)
            return
        }
        
        do {
            try manager.connection.startVPNTunnel()
            completion(nil)
        } catch {
            NVLog.log("Engine", "startVPNTunnel 抛出错误: \(error.localizedDescription)")
            completion(error)
        }
    }
    
    /// 停止 VPN 隧道。
    func stopTunnel() {
        guard let manager else {
            return
        }
        let status = manager.connection.status
        guard status == .connected else {
            return
        }
        manager.connection.stopVPNTunnel()
    }
}

