//
//  WireClient.swift
//  NexusVPN
//
//  通用 HTTP 客户端：负责基于当前域名配置发起请求，
//  包含 host 轮询、5 秒超时校验，以及 Git 回退一次。
//

import Foundation

/// 业务路由枚举（AppSettings / Ads / 分类 / 服务 / 页面 等接口）
enum RoutePath {
    case appSettings
    case adSettings
    case courseCatalog    // 对应 /education/category/course
    case serviceProfile   // 对应 /education/service/enroll
    case pageLayout       // 对应 /education/page/campus
    
    var path: String {
        switch self {
        case .appSettings:
            return "/education/config/curriculum"
        case .adSettings:
            return "/education/ads/scholarship"
        case .courseCatalog:
            return "/education/category/course"
        case .serviceProfile:
            return "/education/service/enroll"
        case .pageLayout:
            return "/education/page/campus"
        }
    }
}

/// 负责实际发起 HTTP 请求
final class WireClient {
    
    static let shared = WireClient()
    
    private let vault = ConfigVault.shared
    
    private init() {}
    
    /// 发送 GET 请求
    /// - Parameters:
    ///   - route: 业务路由（内部包含 path）
    ///   - extra: 额外查询参数（会与基础参数合并）
    /// - Returns: 响应文本（原样字符串），失败返回 nil
    func send(_ route: RoutePath, extra: [String: String] = [:]) async -> String? {
        // 1. 从当前配置获取 host 列表
        guard let hosts = vault.activeHosts(), !hosts.isEmpty else {
            NVLog.log("Wire", "[Wire] 无可用 host，无法发起请求")
            return nil
        }
        
        // 2. 构建完整查询参数
        var query = RequestContext.baseQuery()
        extra.forEach { key, value in
            query[key] = value
        }
        
        // 3. 第一轮 host 轮询
        if let text = await tryHosts(hosts, route: route, query: query) {
            return text
        }
        
        // 4. 所有 host 失败，尝试通过 Git 刷新配置
        NVLog.log("Wire", "[Wire] 所有 host 首次请求失败，尝试通过 Git 刷新配置")
        let refreshed = await vault.refreshConfigFromGit()
        guard refreshed, let newHosts = vault.activeHosts(), !newHosts.isEmpty else {
            NVLog.log("Wire", "[Wire] Git 刷新失败或无新 host，终止请求")
            return nil
        }
        
        NVLog.log("Wire", "[Wire] Git 刷新成功，使用新 host 列表重试")
        return await tryHosts(newHosts, route: route, query: query)
    }
    
    // MARK: - 内部实现
    
    /// 依次尝试多个 host
    private func tryHosts(_ hosts: [String], route: RoutePath, query: [String: String], index: Int = 0) async -> String? {
        guard index < hosts.count else {
            NVLog.log("Wire", "[Wire] 所有 host 都请求失败")
            return nil
        }
        
        let host = hosts[index]
        let baseURL = host.hasSuffix("/") ? String(host.dropLast()) : host
        let apiPath = route.path.hasPrefix("/") ? route.path : "/\(route.path)"
        let basePath = baseURL + apiPath
        
        let fullURLString = assembleURL(base: basePath, params: query)
        
        guard let url = URL(string: fullURLString) else {
            NVLog.log("Wire", "[Wire] 无法构建 URL：\(basePath)")
            return await tryHosts(hosts, route: route, query: query, index: index + 1)
        }
        
        if let result = await performRequest(url: url, hostIndex: index + 1, totalHosts: hosts.count) {
            return result
        } else {
            return await tryHosts(hosts, route: route, query: query, index: index + 1)
        }
    }
    
    /// 针对单个 URL 发起请求（5 秒超时）
    private func performRequest(url: URL, hostIndex: Int, totalHosts: Int) async -> String? {
        var request = URLRequest(url: url)
        request.timeoutInterval = 5.0
        
        var finished = false
        // 简单倒计时日志
        DispatchQueue.global().async {
            for i in (1...5).reversed() {
                if finished { break }
                NVLog.log("Wire", "[Wire] 接口请求倒计时：\(i) 秒")
                Thread.sleep(forTimeInterval: 1.0)
            }
        }
        
        NVLog.log("Wire", "[Wire] 开始请求接口 [\(hostIndex)/\(totalHosts)]: \(url.absoluteString)")
        
        return await withCheckedContinuation { continuation in
            let task = URLSession.shared.dataTask(with: request) { data, response, error in
                finished = true
                
                if let error = error {
                    NVLog.log("Wire", "[Wire] 请求失败：\(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                
                guard let http = response as? HTTPURLResponse else {
                    NVLog.log("Wire", "[Wire] 响应类型异常（非 HTTPURLResponse）")
                    continuation.resume(returning: nil)
                    return
                }
                
                let statusCode = http.statusCode
                NVLog.log("Wire", "[Wire] HTTP 状态码：\(statusCode)")
                
                guard (200...299).contains(statusCode) else {
                    NVLog.log("Wire", "[Wire] 状态码不在 2xx 范围内，本次请求视为失败")
                    continuation.resume(returning: nil)
                    return
                }
                
                guard let data = data,
                      let text = String(data: data, encoding: .utf8) else {
                    NVLog.log("Wire", "[Wire] 响应数据为空或无法转换为字符串")
                    continuation.resume(returning: nil)
                    return
                }
                
                NVLog.log("Wire", "[Wire] 请求成功，响应内容：\(text)")
                continuation.resume(returning: text)
            }
            task.resume()
        }
    }
    
    /// 组装完整 URL（包含查询参数）
    private func assembleURL(base: String, params: [String: String]) -> String {
        guard !params.isEmpty else {
            return base
        }
        
        var components = URLComponents(string: base)
        components?.queryItems = params.map { key, value in
            URLQueryItem(name: key, value: value)
        }
        return components?.url?.absoluteString ?? base
    }
}
