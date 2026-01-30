//
//  LinkController.swift
//  mind
//

import Foundation
import NetworkExtension
import os

class WireSession {

    // MARK: - Public API

    func bringUp() async throws {
        try await prepare()
        try runAll()
    }

    func tearDown() {
        CGoStopBluelink()
    }

    // MARK: - Network config

    var onApply: ((NEPacketTunnelNetworkSettings, @escaping (Error?) -> Void) -> Void)?

    private func produceCfg() -> NEPacketTunnelNetworkSettings {
        let cfg = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: WireBundle.tunnelRemote)
        cfg.mtu = WireBundle.mtuValue
        cfg.ipv4Settings = v4Block()
        cfg.dnsSettings = dnsBlock()
        return cfg
    }

    private func v4Block() -> NEIPv4Settings {
        let v4 = NEIPv4Settings(addresses: [WireBundle.tunnelLocal], subnetMasks: [WireBundle.subnetMask])
        v4.includedRoutes = [NEIPv4Route.default()]
        return v4
    }

    private func dnsBlock() -> NEDNSSettings {
        NEDNSSettings(servers: [WireBundle.dnsPrimary, WireBundle.dnsSecondary])
    }

    private func apply(_ cfg: NEPacketTunnelNetworkSettings) {
        onApply?(cfg) { error in
            if error != nil {
                os_log("[wire] %{public}@", log: OSLog.default, type: .error, "net cfg fail: \(error?.localizedDescription ?? "?")")
            }
        }
    }

    // MARK: - Lifecycle

    private func prepare() async throws {
        let cfg = produceCfg()
        apply(cfg)
    }

    private func runAll() throws {
        try runRelay()
        try runMain()
    }

    private func runRelay() throws {
        let path = PayloadBundler.proxyPath()
        DispatchQueue.global(qos: .userInitiated).async {
            SocksLauncher.apply(withPath: path)
        }
    }

    private func runMain() throws {
        let dirPayload = PayloadBundler.dirPayload()
        let encoded = Data(dirPayload.utf8).base64EncodedString()
        guard let buf = strdup(encoded) else {
            throw NSError(domain: "WireSession", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to allocate memory"])
        }
        defer { free(buf) }
        CGoRunBluelink(UnsafeMutablePointer(mutating: buf))
    }
}
