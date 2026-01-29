//
//  ConfigVault.swift
//  NexusVPN
//
//  负责域名配置的管理：
//  - 从 UserDefaults 读取加密配置字符串
//  - 首次从本地 mind.fd 读取加密配置并写入 UserDefaults
//  - 通过 Git 刷新加密配置
//  - 按需解密得到 JSON，用于提取 host / 上报域名等字段
//

import Foundation
import CryptoKit

/// 域名配置中心（单例）
final class ConfigVault {
    
    static let shared = ConfigVault()
    
    /// UserDefaults 中保存加密配置字符串的 key
    private let cipherStorageKey = "Wire.ConfigCipher"
    
    /// AES 密钥字符串（与旧项目保持一致）
    private let rawAESKey = "f92mUj0K1uBnMlXGFQKrYP07Emgc4yFmWYS8WRgy4IY="
    
    private init() {}
    
    // MARK: - 对外接口
    
    /// 获取当前生效的配置 JSON（每次都会从加密串临时解密）
    func loadActiveConfig() -> [String: Any]? {
        // 1. 尝试从 UserDefaults 读取加密串
        if let storedCipher = UserDefaults.standard.string(forKey: cipherStorageKey),
           !storedCipher.isEmpty {
            NVLog.log("Wire", "[Wire] 尝试使用 UserDefaults 中的域名配置")
            if let json = decryptAndParse(cipherText: storedCipher) {
                // 只打印 host，避免日志过长
                if let api = json["api"] as? [String: Any],
                   let hosts = api["host"] as? [String] {
                    NVLog.log("Wire", "[Wire] 当前 host（来自 UD）：\(hosts)")
                }
                return json
            } else {
                NVLog.log("Wire", "[Wire] UserDefaults 中的域名配置解密或解析失败，回退到本地文件")
            }
        }
        
        // 2. UserDefaults 不可用时，回退到本地 mind.fd
        guard let localCipher = loadLocalCipher() else {
            NVLog.log("Wire", "[Wire] 本地 mind.fd 读取失败，无法加载域名配置")
            return nil
        }
        
        // 将本地加密串保存到 UserDefaults（始终只存加密内容）
        UserDefaults.standard.set(localCipher, forKey: cipherStorageKey)
        NVLog.log("Wire", "[Wire] 已将本地 mind.fd 加密配置写入 UserDefaults")
        
        // 再次尝试解密本地加密串
        guard let json = decryptAndParse(cipherText: localCipher) else {
            NVLog.log("Wire", "[Wire] 本地 mind.fd 加密配置解密失败")
            return nil
        }
        // 只打印 host，避免日志过长
        if let api = json["api"] as? [String: Any],
           let hosts = api["host"] as? [String] {
            NVLog.log("Wire", "[Wire] 当前 host（来自本地 mind.fd）：\(hosts)")
        }
        return json
    }
    
    /// 通过 Git 更新域名配置（成功会用新的加密串覆盖 UserDefaults 中的配置）
    func refreshConfigFromGit() async -> Bool {
        guard let current = loadActiveConfig(),
              let apiDict = current["api"] as? [String: Any],
              let gitSources = apiDict["git"] as? [String],
              !gitSources.isEmpty else {
            NVLog.log("Wire", "[Wire] Git 更新失败：当前配置中缺少 git 源")
            return false
        }
        
        NVLog.log("Wire", "[Wire] 开始通过 Git 更新域名配置，源数量=\(gitSources.count)")
        return await tryRefreshFromGit(sources: gitSources, index: 0)
    }
    
    /// 当前配置中的 host 列表
    func activeHosts() -> [String]? {
        guard let config = loadActiveConfig(),
              let apiDict = config["api"] as? [String: Any],
              let hosts = apiDict["host"] as? [String],
              !hosts.isEmpty else {
            return nil
        }
        return hosts
    }
    
    /// 按类别获取上报地址
    enum ReportEndpointKind {
        case connect
        case general
    }
    
    func reportEndpoint(for kind: ReportEndpointKind) -> String? {
        guard let config = loadActiveConfig(),
              let apiDict = config["api"] as? [String: Any] else {
            return nil
        }
        
        switch kind {
        case .connect:
            return apiDict["connreport"] as? String
        case .general:
            return apiDict["greport"] as? String
        }
    }
    
    // MARK: - Git 更新内部实现
    
    private func tryRefreshFromGit(sources: [String], index: Int) async -> Bool {
        guard index < sources.count else {
            NVLog.log("Wire", "[Wire] Git 更新失败：所有 git 源都尝试过")
            return false
        }
        
        let urlString = sources[index]
        NVLog.log("Wire", "[Wire] 尝试从 Git 拉取配置 [\(index + 1)/\(sources.count)]: \(urlString)")
        
        let success = await fetchAndSaveCipher(from: urlString)
        if success {
            return true
        } else {
            return await tryRefreshFromGit(sources: sources, index: index + 1)
        }
    }
    
    /// 从 Git 拉取加密串并校验解密成功后写入 UserDefaults
    private func fetchAndSaveCipher(from urlString: String) async -> Bool {
        guard let url = URL(string: urlString) else {
            NVLog.log("Wire", "[Wire] Git URL 格式错误：\(urlString)")
            return false
        }
        
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        
        var finished = false
        // 简单的 5 秒倒计时日志
        DispatchQueue.global().async {
            for i in (1...5).reversed() {
                if finished { break }
                NVLog.log("Wire", "[Wire] Git 请求倒计时：\(i) 秒")
                Thread.sleep(forTimeInterval: 1.0)
            }
        }
        
        return await withCheckedContinuation { continuation in
            let task = URLSession.shared.dataTask(with: request) { [weak self] data, response, error in
                finished = true
                
                if let error = error {
                    NVLog.log("Wire", "[Wire] Git 请求失败：\(error.localizedDescription)")
                    continuation.resume(returning: false)
                    return
                }
                
                if let http = response as? HTTPURLResponse {
                    guard (200...299).contains(http.statusCode) else {
                        NVLog.log("Wire", "[Wire] Git 请求状态码异常：\(http.statusCode)")
                        continuation.resume(returning: false)
                        return
                    }
                } else {
                    NVLog.log("Wire", "[Wire] Git 响应类型异常（非 HTTPURLResponse）")
                    continuation.resume(returning: false)
                    return
                }
                
                guard let data = data,
                      let cipherText = String(data: data, encoding: .utf8),
                      !cipherText.isEmpty else {
                    NVLog.log("Wire", "[Wire] Git 响应数据为空或无法转换为字符串")
                    continuation.resume(returning: false)
                    return
                }
                
                // 打印完整加密串用于调试（原始响应内容）
                NVLog.log("Wire", "[Wire] Git 原始响应内容：\(cipherText)")
                
                // 校验能否成功解密
                guard let self,
                      self.decryptAndParse(cipherText: cipherText) != nil else {
                    NVLog.log("Wire", "[Wire] Git 返回的加密配置解密失败")
                    continuation.resume(returning: false)
                    return
                }
                
                // 写入 UserDefaults（只存加密内容）
                UserDefaults.standard.set(cipherText, forKey: self.cipherStorageKey)
                NVLog.log("Wire", "[Wire] Git 加密配置已写入 UserDefaults")
                
                // 为方便调试，这里再打印一次最新配置的解密结果（完整 JSON）
                if let latestCipher = UserDefaults.standard.string(forKey: self.cipherStorageKey),
                   let latestJSON = self.decryptAndParse(cipherText: latestCipher),
                   let pretty = self.debugJSONString(from: latestJSON) {
                    NVLog.log("Wire", "[Wire] Git 刷新后解密内容：\(pretty)")
                }
                
                continuation.resume(returning: true)
            }
            task.resume()
        }
    }
    
    // MARK: - 本地文件读取
    
    /// 从 Bundle 中读取 mind.fd 的加密串（只读取首行）
    private func loadLocalCipher() -> String? {
        // 优先尝试带子目录的路径（作为 folder reference 引入时）
        if let url = Bundle.main.url(forResource: "mind", withExtension: "fd", subdirectory: "network"),
           let content = try? String(contentsOf: url, encoding: .utf8),
           !content.isEmpty {
            let line = content.split(whereSeparator: \.isNewline).first.map(String.init) ?? content
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            NVLog.log("Wire", "[Wire] 从本地 mind.fd 读取到加密配置")
            return trimmed
        }
        // 如果上面失败，再尝试不带子目录（作为普通资源引入时）
        if let url = Bundle.main.url(forResource: "mind", withExtension: "fd"),
           let content = try? String(contentsOf: url, encoding: .utf8),
           !content.isEmpty {
            let line = content.split(whereSeparator: \.isNewline).first.map(String.init) ?? content
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            NVLog.log("Wire", "[Wire] 从根目录 mind.fd 读取到加密配置")
            return trimmed
        }
        
        NVLog.log("Wire", "[Wire] 未能在 Bundle 中找到 mind.fd")
        return nil
    }
    
    // MARK: - 解密 & 解析
    
    /// 尝试将加密串解密并解析为 JSON 字典
    private func decryptAndParse(cipherText: String) -> [String: Any]? {
        guard let jsonString = decryptConfigString(cipherText) else {
            return nil
        }
        guard let data = jsonString.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            NVLog.log("Wire", "[Wire] 配置 JSON 解析失败") 
            return nil
        }
        return dict
    }
    
    /// 解密加密配置字符串，得到 JSON 文本
    /// - Parameter encoded: 形如 "base64Cipher,hexIV,extra" 的字符串
    private func decryptConfigString(_ encoded: String) -> String? {
        return ShieldDecoder.decodeConfig(encoded, keyString: rawAESKey)
    }
    
    /// 将字典转为单行 JSON 字符串，便于日志查看
    private func debugJSONString(from dict: [String: Any]) -> String? {
        guard JSONSerialization.isValidJSONObject(dict),
              let data = try? JSONSerialization.data(withJSONObject: dict, options: [.sortedKeys]),
              let text = String(data: data, encoding: .utf8) else {
            return nil
        }
        return text
    }
}
