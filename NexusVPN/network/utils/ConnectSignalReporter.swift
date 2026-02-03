//
//  ConnectSignalReporter.swift
//  NexusVPN
//
//  连接与服务状态上报中心：
//  - 按后台约定构建上报内容（事件 message / 查询参数）
//  - 日志上报：使用域名配置中的 connreport
//  - 状态上报：使用域名配置中的 greport + /report_total
//  - IP 地址由 ConnectReportContext 提供（已处理是否加 "f" 前缀）
//

import Foundation

/// 连接与服务状态上报中心（单例）
final class ConnectSignalReporter {
    
    static let shared = ConnectSignalReporter()
    private init() {}
    
    // MARK: - 常量
    
    /// 设备类型（后台约定）
    private let deviceType = "iPhone"
    
    /// 连接事件类型（事件名按后台约定）
    private enum ConnectEvent: String {
        case start    = "start_connect"
        case failed   = "connect_failed"
        case success  = "connect_success"
        case stop     = "disconnect"
    }

    /// 广告事件类型（事件名按后台约定）
    private enum AdEvent: String {
        /// 开始请求广告
        case request = "start_get_ad"
        /// 广告资源就绪
        case ready   = "get_ad_success"
        /// 展示广告
        case display = "show_ad"
    }
    
    /// 上报端点类型
    private enum EndpointKind {
        case log      // 日志上报（connreport）
        case status   // 状态上报（greport + /report_total）
    }
    
    // MARK: - 对外工具：生成会话 ID
    
    /// 生成 8 位会话 ID（供外部在一次连接生命周期内复用）
    static func generateSessionId() -> String {
        String(UUID().uuidString.prefix(8))
    }
    
    // MARK: - 对外接口：连接事件上报
    
    /// 上报“开始连接”事件
    func reportConnectStart(sessionId: String) {
        guard let message = buildConnectionMessage(event: .start,
                                                   ipAddress: nil,
                                                   sessionId: sessionId) else {
            return
        }
        submitLog(message: message, event: .start)
    }
    
    /// 上报“连接成功”事件
    func reportConnectSuccess(ip: String?, sessionId: String?) {
        guard let message = buildConnectionMessage(event: .success,
                                                   ipAddress: ip,
                                                   sessionId: sessionId) else {
            return
        }
        submitLog(message: message, event: .success)
    }
    
    /// 上报“连接失败”事件
    func reportConnectFailure(ip: String?, sessionId: String?) {
        guard let message = buildConnectionMessage(event: .failed,
                                                   ipAddress: ip,
                                                   sessionId: sessionId) else {
            return
        }
        submitLog(message: message, event: .failed)
    }
    
    /// 上报“断开连接”事件
    func reportDisconnect(ip: String?) {
        // 断开事件 identifier 用当前时间戳 + 空 sid；调用方未传 sessionId
        guard let message = buildConnectionMessage(event: .stop,
                                                   ipAddress: ip,
                                                   sessionId: nil) else {
            return
        }
        submitLog(message: message, event: .stop)
    }

    // MARK: - 对外接口：广告事件上报

    /// 上报“开始请求广告”事件
    /// - Parameters:
    ///   - adKey: 广告位 ID（可选）
    ///   - cue:  触发时机标记（如 connect/foreground/closead）
    func reportAdRequest(adKey: String?, cue: String?) {
        guard let message = buildAdMessage(event: .request,
                                           adKey: adKey,
                                           cue: cue) else {
            return
        }
        submitAdLog(message: message, event: .request)
    }

    /// 上报“广告资源就绪”事件
    func reportAdReady(adKey: String?, cue: String?) {
        guard let message = buildAdMessage(event: .ready,
                                           adKey: adKey,
                                           cue: cue) else {
            return
        }
        submitAdLog(message: message, event: .ready)
    }

    /// 上报“展示广告”事件
    func reportAdDisplay(adKey: String?, cue: String?) {
        guard let message = buildAdMessage(event: .display,
                                           adKey: adKey,
                                           cue: cue) else {
            return
        }
        submitAdLog(message: message, event: .display)
    }
    
    // MARK: - 对外接口：服务状态上报
    
    /// 上报服务状态（接口配置成功/失败或回退）
    /// - Parameter success: true 表示使用接口配置成功，false 表示失败或回退
    func reportServiceStatus(success: Bool) {
        Task.detached { [weak self] in
            await self?.performStatusReport(success: success)
        }
    }
    
    // MARK: - 事件 message 构建（格式按后台约定）
    
    /// 构建连接事件的 message 字符串
    ///
    /// 约定格式：
    /// start_connect:   start_connect,<MMddHHmmss-sid>,0.0.0.0
    /// connect_failed:  connect_failed,<MMddHHmmss-sid>,<ip or 0.0.0.0>
    /// connect_success: connect_success,0,<MMddHHmmss-sid>,<ip or 0.0.0.0>
    /// disconnect:      disconnect,<MMddHHmmss-sid>,<ip or 0.0.0.0>
    private func buildConnectionMessage(
        event: ConnectEvent,
        ipAddress: String?,
        sessionId: String?
    ) -> String? {
        let timestamp = formattedTimestamp()
        let sid = sessionId ?? ""          // 如果外部未提供会话 ID，则仅使用时间戳部分
        let identifier = "\(timestamp)-\(sid)"
        let ip = ipAddress ?? "0.0.0.0"
        
        switch event {
        case .start:
            return "\(ConnectEvent.start.rawValue),\(identifier),0.0.0.0"
        case .failed:
            return "\(ConnectEvent.failed.rawValue),\(identifier),\(ip)"
        case .success:
            return "\(ConnectEvent.success.rawValue),0,\(identifier),\(ip)"
        case .stop:
            return "\(ConnectEvent.stop.rawValue),\(identifier),\(ip)"
        }
    }

    /// 构建广告事件的 message 字符串
    ///
    /// 约定格式（与旧项目保持一致）：
    /// start_get_ad:   start_get_ad,<moment>,<ip>,ad
    /// get_ad_success: get_ad_success,<moment>,<ip>,ad,<adKey>
    /// show_ad:        show_ad,<moment>,<ip>,ad,<adKey or empty>
    private func buildAdMessage(
        event: AdEvent,
        adKey: String?,
        cue: String?
    ) -> String? {
        let moment = cue ?? ""
        let ip = ConnectReportContext.shared.currentEndpoint ?? "0.0.0.0"

        switch event {
        case .request:
            return "\(AdEvent.request.rawValue),\(moment),\(ip),ad"
        case .ready:
            return "\(AdEvent.ready.rawValue),\(moment),\(ip),ad,\(adKey ?? "")"
        case .display:
            return "\(AdEvent.display.rawValue),\(moment),\(ip),ad,\(adKey ?? "empty")"
        }
    }
    
    /// 生成时间戳（格式：MMddHHmmss）
    private func formattedTimestamp() -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMddHHmmss"
        return formatter.string(from: Date())
    }
    
    // MARK: - 日志上报入口
    
    private func submitLog(message: String, event: ConnectEvent) {
        Task.detached { [weak self] in
            await self?.performLogReport(message: message, event: event)
        }
    }

    private func submitAdLog(message: String, event: AdEvent) {
        Task.detached { [weak self] in
            await self?.performAdLogReport(message: message, event: event)
        }
    }
    
    /// 执行连接日志上报（使用 connreport 作为上报地址）
    private func performLogReport(message: String, event: ConnectEvent) async {
        guard let endpoint = ConfigVault.shared.reportEndpoint(for: .connect),
              !endpoint.isEmpty else {
            NVLog.log("report", "[report] 日志上报终止：缺少 connreport 端点")
            return
        }
        
        guard let urlString = buildEndpointURL(kind: .log,
                                               baseURL: endpoint,
                                               message: message,
                                               statusCode: nil) else {
            NVLog.log("report", "[report] 日志上报终止：URL 构建失败")
            return
        }
        
        let token = String(UUID().uuidString.prefix(8))
        NVLog.log("report", "[report] 日志上报开始 [\(token)] 事件=\(event.rawValue) URL=\(urlString)")
        await performNetworkRequest(urlString: urlString,
                                    label: "日志上报",
                                    token: token)
    }

    /// 执行广告日志上报（与连接事件共用 connreport 端点）
    private func performAdLogReport(message: String, event: AdEvent) async {
        guard let endpoint = ConfigVault.shared.reportEndpoint(for: .connect),
              !endpoint.isEmpty else {
            NVLog.log("report", "[report] 广告上报终止：缺少 connreport 端点")
            return
        }

        guard let urlString = buildEndpointURL(kind: .log,
                                               baseURL: endpoint,
                                               message: message,
                                               statusCode: nil) else {
            NVLog.log("report", "[report] 广告上报终止：URL 构建失败")
            return
        }

        let token = String(UUID().uuidString.prefix(8))
        NVLog.log("report", "[report] 广告上报开始 [\(token)] 事件=\(event.rawValue) URL=\(urlString)")
        await performNetworkRequest(urlString: urlString,
                                    label: "广告上报",
                                    token: token)
    }
    
    /// 执行状态上报（使用 greport + /report_total）
    private func performStatusReport(success: Bool) async {
        guard let endpoint = ConfigVault.shared.reportEndpoint(for: .general),
              !endpoint.isEmpty else {
            NVLog.log("report", "[report] 状态上报终止：缺少 greport 端点")
            return
        }
        
        let statusCode = success ? "0" : "1"
        
        guard let urlString = buildEndpointURL(kind: .status,
                                               baseURL: endpoint,
                                               message: nil,
                                               statusCode: statusCode) else {
            NVLog.log("report", "[report] 状态上报终止：URL 构建失败")
            return
        }
        
        let token = String(UUID().uuidString.prefix(8))
        NVLog.log("report", "[report] 状态上报开始 [\(token)] isf=\(statusCode) URL=\(urlString)")
        await performNetworkRequest(urlString: urlString,
                                    label: "状态上报",
                                    token: token)
    }
    
    // MARK: - URL 构建（参数键名按后台约定）
    
    private func buildEndpointURL(
        kind: EndpointKind,
        baseURL: String,
        message: String?,
        statusCode: String?
    ) -> String? {
        let targetURL: String
        var queryItems: [URLQueryItem] = []
        
        let ctx = RequestContext.baseQuery()
        let uid = ctx["uid"] ?? ""
        let country = ctx["country"] ?? ""
        let lang = ctx["language"] ?? ""
        let pk = ctx["pk"] ?? ""
        let version = ctx["version"] ?? ""
        
        switch kind {
        case .log:
            targetURL = baseURL
            queryItems = [
                URLQueryItem(name: "imei", value: uid),
                URLQueryItem(name: "country", value: country),
                URLQueryItem(name: "lang", value: lang),
                URLQueryItem(name: "mobile", value: deviceType),
                URLQueryItem(name: "pk", value: pk),
                URLQueryItem(name: "version", value: version),
                URLQueryItem(name: "info", value: message ?? "")
            ]
            
        case .status:
            targetURL = baseURL + "/report_total"
            let isfValue = statusCode ?? ""
            queryItems = [
                URLQueryItem(name: "name", value: "getService"),
                URLQueryItem(name: "cty", value: country),
                URLQueryItem(name: "pk", value: pk),
                URLQueryItem(name: "v", value: version),
                URLQueryItem(name: "asn", value: "0"),
                URLQueryItem(name: "isf", value: isfValue),
                URLQueryItem(name: "cnt", value: "1")
            ]
        }
        
        guard var components = URLComponents(string: targetURL) else {
            return nil
        }
        components.queryItems = queryItems
        return components.url?.absoluteString
    }
    
    // MARK: - HTTP 请求执行
    
    private func performNetworkRequest(
        urlString: String,
        label: String,
        token: String
    ) async {
        guard let url = URL(string: urlString) else {
            NVLog.log("report", "[report] [\(label)] [\(token)] URL 无效：\(urlString)")
            return
        }
        
        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        
        let startTime = Date()
        
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            let duration = Date().timeIntervalSince(startTime)
            let durationStr = String(format: "%.2f", duration)
            
            guard let http = response as? HTTPURLResponse else {
                NVLog.log("report", "[report] [\(label)] [\(token)] 响应类型异常（非 HTTPURLResponse）")
                return
            }
            
            let statusCode = http.statusCode
            if (200...299).contains(statusCode) {
                NVLog.log("report", "[report] [\(label)] [\(token)] ✅ 成功 status=\(statusCode) 耗时=\(durationStr)s URL=\(url.absoluteString)")
            } else {
                NVLog.log("report", "[report] [\(label)] [\(token)] ❌ 失败 status=\(statusCode) 耗时=\(durationStr)s URL=\(url.absoluteString)")
            }
        } catch {
            let duration = Date().timeIntervalSince(startTime)
            let durationStr = String(format: "%.2f", duration)
            NVLog.log("report", "[report] [\(label)] [\(token)] ❌ 异常 error=\(error.localizedDescription) 耗时=\(durationStr)s URL=\(url.absoluteString)")
        }
    }
}

