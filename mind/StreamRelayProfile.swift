//
//  StreamRelayProfile.swift
//  NexusVPN
//
//  Created by ersao on 2026/1/9.
//

import Foundation

final class StreamRelayProfile {
    
    // 远端基本配置
    var remoteHost: String = "hp.com"
    var remoteIP: String = "64.176.43.209"
    var remotePort: String = "49155"
    
    // 编解码主密钥与掩码参数
    var codecMasterKey: String = "3e027e48ec6f5a9c705dfe17bed37201"
    var codecSeedKey: String = "hfor1"
    var codecSpanLimit: Int = 32
    
    // HTTP 请求与传输选项
    var requestPath: String = ""
    var useChunkedTransfer: Bool = true
    var useTLS: Bool = true
    var useCFProxy: Bool = false
    var useWildcardHost: Bool = false
    
    var shadowFlagA: Bool = false
    var shadowFlagB: Int = 0
    var shadowToken: String = ""
    
    // 客户端标识
    var clientRegion: String = "sg"
    var clientLocale: String = "en-SG"
    var clientBundleId: String = "com.green.fire.vpn.birds.fly"
    var clientVersion: String = "1.0.0"
    
}


