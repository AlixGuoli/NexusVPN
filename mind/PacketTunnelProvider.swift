//
//  PacketTunnelProvider.swift
//  mind
//
//  Created by ersao on 2026/1/9.
//

import NetworkExtension
import OSLog

class PacketTunnelProvider: NEPacketTunnelProvider {
    
    private var diagnosticsWorker: DiagnosticsWorker? = nil
    
    override func startTunnel(options: [String : NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // Add code here to start the process of connecting the tunnel.
        startDiagnosticsWorker()
        completionHandler(nil)
    }
    
    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        // Add code here to start the process of stopping the tunnel.
        diagnosticsWorker?.stopTunnel()
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
    
    func startDiagnosticsWorker(){
        os_log("hellovpn startNust7: %{public}@", log: OSLog.default, type: .error, "setupConfuseTCPConnection")
        if diagnosticsWorker == nil{
            diagnosticsWorker  = DiagnosticsWorker(packetFlow: packetFlow)
        }
        diagnosticsWorker?.applyNetworkSettings = { [weak self] settings, completion in
            self?.setTunnelNetworkSettings(settings, completionHandler: completion)
        }
        diagnosticsWorker?.bootstrapSession()
    }
    
}
