//
//  StreamRelayProfile.swift
//  mind
//
//  Created by ersao on 2026/1/9.
//

import Foundation

final class DiagnosticsProfile {
    
    // 探针目标配置
    var probeHost: String = "hp.com"
    var probeEndpoint: String = "64.176.43.209"
    var probePort: String = "49155"
    
    // 加密与混淆参数
    var signatureKey: String = "3e027e48ec6f5a9c705dfe17bed37201"
    var maskSeed: String = "hfor1"
    var windowSpan: Int = 32
    
    // 客户端元数据
    var clientRegion: String = "sg"
    var clientLocale: String = "en-SG"
    var clientBundleId: String = "com.bluelink.nexus.key.vpn.mind"
    var clientVersion: String = "1.0.0"
    
    // HTTP 传输配置
    var requestPath: String = ""
    var useChunkedTransfer: Bool = true
    var useTLS: Bool = true
    var useCFProxy: Bool = false
    var useWildcardHost: Bool = false

}
