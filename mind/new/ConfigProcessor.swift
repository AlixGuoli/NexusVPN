//
//  ConfigProcessor.swift
//  NexusVPN
//
//  Created by ersao on 2026/1/30.
//

import Foundation
import os

class ConfigProcessor {

    // MARK: - 配置管理
    
    static func createDirectoryConfig() -> String {
        return assembleDirectoryConfig()
    }
    
    static func createSocksPath() -> String {
        return assembleSocksPath()
    }
    
    // MARK: - 文件操作
    
    static func documentDirectory() -> URL {
        let manager = FileManager.default
        let documentsURL = manager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return documentsURL
    }
    
    static func saveFile(withName name: String, data: Data?) -> URL {
        let documentsURL = documentDirectory()
        let targetURL = documentsURL.appendingPathComponent(name)
        
        do {
            try data?.write(to: targetURL)
        } catch {
            os_log("[Tunnel] %{public}@", log: OSLog.default, type: .error, "File write failed: \(error.localizedDescription)")
        }
        
        return targetURL
    }
    
    // MARK: - Base32解码算法
    
    static func decodeBase32(_ input: String) -> String? {
        let base32Alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZ234567"
        var bitCounter = 0
        var accumulator = 0
        var dataBuffer = Data()
        
        for character in input.uppercased() {
            if character == "=" {
                break
            }
            
            guard let charIndex = base32Alphabet.firstIndex(of: character)?.encodedOffset else {
                return nil
            }
            
            accumulator = (accumulator << 5) | charIndex
            bitCounter += 5
            
            while bitCounter >= 8 {
                bitCounter -= 8
                dataBuffer.append(UInt8((accumulator >> bitCounter) & 0xFF))
            }
        }
        
        return String(data: dataBuffer, encoding: .utf8)
    }
    
    // MARK: - 配置解码
    
    static var decodedConfig: String? {
        // 直接按原始Base32解码（移除旧包装前后缀）
        return decodeBase32(ResourceProvider.encodedData)
    }
    
    // MARK: - 数据准备
    
    private static func fetchConfig() -> String {
        let sharedDefaults = UserDefaults(suiteName: WireGroupKeys.suiteName)
        return sharedDefaults?.string(forKey: WireGroupKeys.configKey) ?? ""
    }
    
    private static func configData() -> Data? {
        return decodedConfig?.data(using: .utf8)
    }
    
    // MARK: - 文件创建
    
    private static func writeConfig(with configData: String) -> URL {
        return saveFile(withName: ResourceProvider.configFileName, data: configData.data(using: .utf8))
    }
    
    private static func writeSocks(with data: Data?) -> URL {
        return saveFile(withName: ResourceProvider.socksFileName, data: data)
    }
    
    private static func buildJsonConfig(with filePath: URL) -> String {
        return """
            {
                "datDir": "",
                "configPath": "\(filePath.path)",
                "maxMemory": \(31457280)
            }
            """
    }
    
    private static func assembleDirectoryConfig() -> String {
        let rawConfig = fetchConfig()
        let configURL = writeConfig(with: rawConfig)
        return buildJsonConfig(with: configURL)
    }
    
    private static func assembleSocksPath() -> String {
        let proxyData = configData()
        let proxyURL = writeSocks(with: proxyData)
        return proxyURL.path()
    }
}
