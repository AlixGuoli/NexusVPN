//
//  ProxyService.swift
//  NexusVPN
//
//  Created by ersao on 2026/1/30.
//

import Foundation
import os

public enum ProxyService {
    
    // MARK: - 公共接口
    
    @discardableResult
    public static func activate(withConfig filePath: String) -> Int32 {
        return executeActivation(withConfig: filePath)
    }
    
    public static func deactivate() {
        executeDeactivation()
    }
    
    // MARK: - 文件描述符查找
    
    private static var tunnelDescriptor: Int32? {
        return findDescriptor()
    }
    
    private static func findDescriptor() -> Int32? {
        var controlBlock = DataBlock()
        withUnsafeMutablePointer(to: &controlBlock.buffer) {
            $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: $0.pointee)) {
                _ = strcpy($0, "com.apple.net.utun_control")
            }
        }
        
        for index: Int32 in 0...1024 {
            if let found = validateDescriptor(index, controlBlock: &controlBlock) {
                return found
            }
        }
        return nil
    }
    
    private static func validateDescriptor(_ index: Int32, controlBlock: inout DataBlock) -> Int32? {
        var handle = HandleBlock()
        var status: Int32 = -1
        var length = socklen_t(MemoryLayout.size(ofValue: handle))
        withUnsafeMutablePointer(to: &handle) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                status = getpeername(index, $0, &length)
            }
        }
        if status != 0 || handle.type != AF_SYSTEM {
            return nil
        }
        if controlBlock.value == 0 {
            status = ioctl(index, CTLIOCGINFO, &controlBlock)
            if status != 0 {
                return nil
            }
        }
        if handle.id == controlBlock.value {
            return index
        }
        return nil
    }
    
    // MARK: - 服务控制
    
    @discardableResult
    private static func executeActivation(withConfig filePath: String) -> Int32 {
        guard let descriptor = self.tunnelDescriptor else {
            fatalError("Get tunnel file descriptor failed.")
        }
        
        let result = BluelinkProxyServiceStart(filePath.cString(using: .utf8), descriptor)
        
        if result != 0 {
            os_log("[Tunnel] %{public}@", log: OSLog.default, type: .error, "Proxy service activation failed: \(result)")
        }
        
        return result
    }
    
    private static func executeDeactivation() {
        BluelinkProxyServiceStop()
    }
}
