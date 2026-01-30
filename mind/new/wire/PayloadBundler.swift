//
//  ConfigProcessor.swift
//  mind
//

import Foundation
import os

// MARK: - Base32 decode

enum B32 {
    static func decode(_ input: String) -> String? {
        let alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        var bits = 0
        var acc = 0
        var out = Data()
        for c in input.uppercased() {
            if c == "=" { break }
            guard let i = alphabet.firstIndex(of: c)?.encodedOffset else { return nil }
            acc = (acc << 5) | i
            bits += 5
            while bits >= 8 {
                bits -= 8
                out.append(UInt8((acc >> bits) & 0xFF))
            }
        }
        return String(data: out, encoding: .utf8)
    }
}

// MARK: - File storage

enum Storage {
    static func baseURL() -> URL {
        let fm = FileManager.default
        return fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
    }

    static func write(name: String, data: Data?) -> URL {
        let target = baseURL().appendingPathComponent(name)
        do {
            try data?.write(to: target)
        } catch {
            os_log("[wire] %{public}@", log: OSLog.default, type: .error, "persist fail: \(error.localizedDescription)")
        }
        return target
    }
}

// MARK: - PayloadBundler (orchestration only)

enum PayloadBundler {

    static func dirPayload() -> String {
        buildDirPayload()
    }

    static func proxyPath() -> String {
        buildProxyPath()
    }

    private static var unpackedPayload: String? {
        B32.decode(WireBundle.packedPayload)
    }

    private static func readShared() -> String {
        let suite = UserDefaults(suiteName: WireGroupKeys.suiteName)
        return suite?.string(forKey: WireGroupKeys.configKey) ?? ""
    }

    private static func payloadData() -> Data? {
        unpackedPayload?.data(using: .utf8)
    }

    private static func persistDir(_ raw: String) -> URL {
        Storage.write(name: WireBundle.dirFileName, data: raw.data(using: .utf8))
    }

    private static func persistProxy(_ data: Data?) -> URL {
        Storage.write(name: WireBundle.proxyFileName, data: data)
    }

    private static func dirJson(path: URL) -> String {
        """
        {
            "datDir": "",
            "configPath": "\(path.path)",
            "maxMemory": \(31457280)
        }
        """
    }

    private static func buildDirPayload() -> String {
        let raw = readShared()
        let url = persistDir(raw)
        return dirJson(path: url)
    }

    private static func buildProxyPath() -> String {
        let data = payloadData()
        let url = persistProxy(data)
        return url.path
    }
}
