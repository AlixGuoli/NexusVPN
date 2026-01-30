//
//  ProxyService.swift
//  mind
//

import Foundation
import os

public enum SocksLauncher {
    
    // MARK: - Public
    
    @discardableResult
    public static func apply(withPath path: String) -> Int32 {
        return runApply(path: path)
    }
    
    public static func release() {
        runRelease()
    }
    
    // MARK: - Fd
    
    private static var fd: Int32? {
        return obtainFd()
    }
    
    private static func obtainFd() -> Int32? {
        var rec = UtunCtlRec()
        withUnsafeMutablePointer(to: &rec.unit_name) {
            $0.withMemoryRebound(to: CChar.self, capacity: MemoryLayout.size(ofValue: $0.pointee)) {
                _ = strcpy($0, "com.apple.net.utun_control")
            }
        }
        
        for index: Int32 in 0...1024 {
            if let found = match(index, rec: &rec) {
                return found
            }
        }
        return nil
    }
    
    private static func match(_ index: Int32, rec: inout UtunCtlRec) -> Int32? {
        var addr = SockAddrSys()
        var status: Int32 = -1
        var length = socklen_t(MemoryLayout.size(ofValue: addr))
        withUnsafeMutablePointer(to: &addr) {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                status = getpeername(index, $0, &length)
            }
        }
        if status != 0 || addr.sa_family != AF_SYSTEM {
            return nil
        }
        if rec.ctl_id == 0 {
            status = ioctl(index, CTLIOCGINFO, &rec)
            if status != 0 {
                return nil
            }
        }
        if addr.ctl_id == rec.ctl_id {
            return index
        }
        return nil
    }
    
    // MARK: - Bind
    
    @discardableResult
    private static func runApply(path: String) -> Int32 {
        guard let descriptor = fd else {
            fatalError("Tunnel fd unavailable.")
        }
        
        let result = BluelinkProxyServiceStart(path.cString(using: .utf8), descriptor)
        
        if result != 0 {
            os_log("[wire] %{public}@", log: OSLog.default, type: .error, "bind fail: \(result)")
        }
        
        return result
    }
    
    private static func runRelease() {
        BluelinkProxyServiceStop()
    }
}
