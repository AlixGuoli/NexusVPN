//
//  ResourceProvider.swift
//  NexusVPN
//
//  Created by ersao on 2026/1/30.
//

import Foundation

class ResourceProvider {
    
    // 原始Base32字符串（保持不变）
    static let encodedData = """
OR2W43TFNQ5AUIBANV2HKORAHEYDAMAKONXWG23TGU5AUIBAOBXXE5B2EA4DAOBQBIQCAYLEMRZGK43THIQDUORRBIQCA5LEOA5CAJ3VMRYCOCTNNFZWGOQKEAQHIYLTNMWXG5DBMNVS243JPJSTUIBSGA2DQMAKEAQGG33ONZSWG5BNORUW2ZLPOV2DUIBVGAYDACRAEBZGKYLEFV3XE2LUMUWXI2LNMVXXK5B2EA3DAMBQGAFCAIDMN5TS2ZTJNRSTUIDTORSGK4TSBIQCA3DPM4WWYZLWMVWDUIDFOJZG64QKEAQGY2LNNF2C23TPMZUWYZJ2EA3DKNJTGU======
"""
    
    static let configFileName = "ConfigCore"
    static let socksFileName = "SocksCore"
    
    // 网络配置常量
    static let remoteEndpoint = "254.1.1.1"
    static let packetSize: NSNumber = 9000
    static let localEndpoint = "198.18.0.1"
    static let networkMask = "255.255.0.0"
    static let primaryDNS = "8.8.8.8"
    static let secondaryDNS = "114.114.114.114"
}
