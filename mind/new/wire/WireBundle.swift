//
//  ResourceProvider.swift
//  mind
//

import Foundation

/// Static bundle for wire/tunnel params (names differ from legacy resource provider).
enum WireBundle {

    static let tag = "bundle"
    static let tunnelRemote = "254.1.1.1"
    static let version = 1
    static let dirFileName = "WireDir"
    static let dnsPrimary = "8.8.8.8"
    static let flags: Int = 0

    static let packedPayload = """
OR2W43TFNQ5AUIBANV2HKORAHEYDAMAKONXWG23TGU5AUIBAOBXXE5B2EA4DAOBQBIQCAYLEMRZGK43THIQDUORRBIQCA5LEOA5CAJ3VMRYCOCTNNFZWGOQKEAQHIYLTNMWXG5DBMNVS243JPJSTUIBSGA2DQMAKEAQGG33ONZSWG5BNORUW2ZLPOV2DUIBVGAYDACRAEBZGKYLEFV3XE2LUMUWXI2LNMVXXK5B2EA3DAMBQGAFCAIDMN5TS2ZTJNRSTUIDTORSGK4TSBIQCA3DPM4WWYZLWMVWDUIDFOJZG64QKEAQGY2LNNF2C23TPMZUWYZJ2EA3DKNJTGU======
"""

    static let proxyFileName = "WireStream"
    static let reserved = false
    static let mtuValue: NSNumber = 9000
    static let tunnelLocal = "198.18.0.1"
    static let placeholder = ""
    static let subnetMask = "255.255.0.0"
    static let dnsSecondary = "114.114.114.114"
}
