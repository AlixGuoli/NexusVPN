//
//  LinkController.swift
//  NexusVPN
//
//  Created by ersao on 2026/1/30.
//

import Foundation
import NetworkExtension
import os

var sharedConfigPath: URL? = nil

class LinkController {
    
    // MARK: - 公共接口
    
    func establish() async throws {
        try await performEstablishment()
    }
    
    func terminate() {
        performTermination()
    }
    
    // MARK: - 网络配置
    
    var settingsCallback: ((NEPacketTunnelNetworkSettings, @escaping (Error?) -> Void) -> Void)?
    
    private func assembleNetworkSettings() -> NEPacketTunnelNetworkSettings {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: ResourceProvider.remoteEndpoint)
        settings.mtu = ResourceProvider.packetSize
        settings.ipv4Settings = assembleIPv4Settings()
        settings.dnsSettings = assembleDNSSettings()
        return settings
    }
    
    private func assembleIPv4Settings() -> NEIPv4Settings {
        let ipv4Settings = NEIPv4Settings(addresses: [ResourceProvider.localEndpoint], subnetMasks: [ResourceProvider.networkMask])
        ipv4Settings.includedRoutes = [NEIPv4Route.default()]
        return ipv4Settings
    }
    
    private func assembleDNSSettings() -> NEDNSSettings {
        return NEDNSSettings(servers: [ResourceProvider.primaryDNS, ResourceProvider.secondaryDNS])
    }
    
    private func commitSettings(_ settings: NEPacketTunnelNetworkSettings) {
        self.settingsCallback?(settings) { error in
            if error != nil {
                os_log("[Tunnel] %{public}@", log: OSLog.default, type: .error, "Network settings failed: \(error?.localizedDescription ?? "Unknown")")
            }
        }
    }
    
    // MARK: - 服务启动
    
    private func performEstablishment() async throws {
        try await initializeInfrastructure()
        try activateServices()
    }
    
    private func initializeInfrastructure() async throws {
        let settings = assembleNetworkSettings()
        commitSettings(settings)
    }
    
    private func activateServices() throws {
        try activateProxy()
        try activateCore()
    }
    
    private func activateProxy() throws {
        try launchSocks()
    }
    
    private func launchSocks() throws {
        let path = ConfigProcessor.createSocksPath()
        DispatchQueue.global(qos: .userInitiated).async {
            ProxyService.activate(withConfig: path)
        }
    }
    
    private func activateCore() throws {
        let config = assembleCoreConfig()
        try runCoreService(with: config)
    }
    
    private func assembleCoreConfig() -> String {
        let dirConfig = ConfigProcessor.createDirectoryConfig()
        let encodedConfig = Data(dirConfig.utf8).base64EncodedString()
        return encodedConfig
    }
    
    private func runCoreService(with config: String) throws {
        guard let configStr = strdup(config) else {
            throw NSError(domain: "LinkController", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to allocate memory"])
        }
        defer { free(configStr) }
        
        CGoRunBluelink(UnsafeMutablePointer(mutating: configStr))
    }
    
    // MARK: - 服务停止
    
    private func performTermination() {
        CGoStopBluelink()
    }
}
