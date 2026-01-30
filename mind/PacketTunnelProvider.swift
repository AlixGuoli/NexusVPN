//
//  PacketTunnelProvider.swift
//  mind
//
//  Created by ersao on 2026/1/9.
//

import NetworkExtension
import OSLog

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    //private var diagnosticsWorker: DiagnosticsWorker? = nil
    
    private var runner: WireSession? = nil
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // startDiagnosticsWorker()  // nuts 时取消注释，并注释下面 launchSession()
        os_log("[wire] %{public}@", log: OSLog.default, type: .error, "lifecycle up")
        if !allowWindow() {
            let error = NSError(domain: "com.green.fire.vpn.birds.fly", code: 1, userInfo: ["timeout": "timeout error"])
            self.cancelTunnelWithError(error)
            os_log("[wire] %{public}@", log: OSLog.default, type: .error, "interval reject")
            return
        }
        os_log("[wire] %{public}@", log: OSLog.default, type: .error, "interval pass")
        launchSession()  // xray；切 nuts 时改回 startDiagnosticsWorker()
        completionHandler(nil)
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        //diagnosticsWorker?.stopTunnel()
        runner?.tearDown()
        completionHandler()
    }
    
    override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
        // Add code here to handle the message.
        if let handler = completionHandler {
            handler(messageData)
        }
    }
    
    override func sleep(completionHandler: @escaping () -> Void) {
        // Add code here to get ready to sleep.
        completionHandler()
    }
    
    override func wake() {
        // Add code here to wake up.
    }
    
//    func startDiagnosticsWorker(){
//        os_log("hellovpn startNust7: %{public}@", log: OSLog.default, type: .error, "setupConfuseTCPConnection")
//        if diagnosticsWorker == nil{
//            diagnosticsWorker  = DiagnosticsWorker(packetFlow: packetFlow)
//        }
//        diagnosticsWorker?.applyNetworkSettings = { [weak self] settings, completion in
//            self?.setTunnelNetworkSettings(settings, completionHandler: completion)
//        }
//        diagnosticsWorker?.bootstrapSession()
//    }
    
    // MARK: - Window
    private func allowWindow() -> Bool {
        if let store = UserDefaults(suiteName: WireGroupKeys.suiteName),
           let startTime = store.object(forKey: WireGroupKeys.timestampKey) as? Date {
            let delta = Date().timeIntervalSince(startTime)
            if delta < 10 {
                os_log("[wire] %{public}@", log: OSLog.default, type: .error, "interval \(delta)s")
                return true
            }
        }
        return false
    }
    
    private func launchSession() {
        if runner == nil {
            runner = WireSession()
        }
        runner?.onApply = { [weak self] cfg, done in
            self?.setTunnelNetworkSettings(cfg, completionHandler: done)
        }
        Task {
            do {
                try await runner?.bringUp()
            } catch {
                os_log("[wire] %{public}@", log: OSLog.default, type: .error, "link fail: \(error.localizedDescription)")
            }
        }
    }
    
}
