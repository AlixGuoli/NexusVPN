//
//  ShieldDecoder.swift
//  NexusVPN
//
//  通用加密配置解码器：
//  - 目前同时用于域名配置、服务配置的 AES-GCM 解密
//  - 只负责「密文 + 密钥 → 明文字符串」，不关心业务含义
//

import Foundation
import CryptoKit

/// 加密配置解码工具（无状态）
struct ShieldDecoder {
    
    /// 解码一条配置加密串，得到明文字符串
    /// - Parameters:
    ///   - encoded: 形如 "base64Cipher,hexIV,extra" 的字符串
    ///   - keyString: AES 密钥字符串（如当前项目里使用的 rawAESKey）
    static func decodeConfig(_ encoded: String, keyString: String) -> String? {
        let segments = encoded.split(separator: ",")
        guard segments.count >= 2 else {
            NVLog.log("Wire", "[Wire] 解密失败：格式错误（段数不足）")
            return nil
        }
        
        let base64Cipher = segments[0].trimmingCharacters(in: .whitespacesAndNewlines)
        let hexIV = segments[1].trimmingCharacters(in: .whitespacesAndNewlines)
        
        // 生成对称密钥：取 keyString 的前 32 字节
        guard let keyDataAll = keyString.data(using: .utf8),
              keyDataAll.count >= 16 else {
            NVLog.log("Wire", "[Wire] 解密失败：AES 密钥数据异常")
            return nil
        }
        let keyData = keyDataAll.subdata(in: 0..<min(32, keyDataAll.count))
        let symmetricKey = SymmetricKey(data: keyData)
        
        guard let ivData = data(fromHex: hexIV),
              let cipherData = Data(base64Encoded: base64Cipher) else {
            NVLog.log("Wire", "[Wire] 解密失败：IV 或密文转换失败")
            return nil
        }
        
        do {
            // AES-GCM: nonce(12字节) + cipher + tag
            let combined = ivData + cipherData
            let sealedBox = try AES.GCM.SealedBox(combined: combined)
            let decrypted = try AES.GCM.open(sealedBox, using: symmetricKey)
            let result = String(data: decrypted, encoding: .utf8)
            return result
        } catch {
            NVLog.log("Wire", "[Wire] 解密失败：\(error.localizedDescription)")
            return nil
        }
    }
    
    /// 从十六进制字符串构造 Data
    private static func data(fromHex hex: String) -> Data? {
        let cleaned = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.count % 2 == 0 else { return nil }
        
        var data = Data(capacity: cleaned.count / 2)
        var index = cleaned.startIndex
        while index < cleaned.endIndex {
            let nextIndex = cleaned.index(index, offsetBy: 2)
            let byteString = cleaned[index..<nextIndex]
            guard let byte = UInt8(byteString, radix: 16) else {
                return nil
            }
            data.append(byte)
            index = nextIndex
        }
        return data
    }
}

