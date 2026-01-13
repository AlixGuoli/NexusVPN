//
//  StreamRelayAgent.swift
//  NexusVPN
//
//  Created by ersao on 2026/1/9.
//

import Foundation
import NetworkExtension
import os
import CommonCrypto
import Dispatch
import CryptoKit
import Network

class StreamRelayAgent {
    // 底层连接与调度
    var linkConnection: NWConnection? = nil
    var linkQueue: DispatchQueue?
    
    // 远端配置（运行期派生自 profile）
    let profile = StreamRelayProfile()
    var remoteAddress = ""
    var remoteSNIHost = ""
    
    // 收包缓存与运行期混淆跨度
    var streamBuffer: Data = Data()
    var codecSpanLimit: Int = 32
    
    // HTTP 头相关
    var requestHeaders  = [
        "User-Agent": "Kotlin HTTP Client",
        "Content-Type": "application/json"
    ]
    
    var responseHeaders = [String: String]()
    var parsedHeaders = [String: String]()
    var headerBufferData = Data()
    
    var isParsingBodyHeader = true
    var expectedBodyLength = 0
    var headerTerminator = "\r\n\r\n".data(using: .ascii)!
    
    // 由外部注入的网络设置回调与 TUN 流
    var applyNetworkSettings: ((NEPacketTunnelNetworkSettings, @escaping (Error?) -> Void) -> Void)?
    var tunnelFlow: NEPacketTunnelFlow
  
    init(packetFlow: NEPacketTunnelFlow) {
        self.tunnelFlow = packetFlow
    }
    
    // 启动与远端的加密通道
    func startLinkChannel() {
        os_log("[SRL] link bootstrap: %{public}@", log: OSLog.default, type: .error, "setupWithTlsTCPConnection")
        prepareEndpointIdentity()
        let connectionComponents = buildConnectionParameters()
        startConnection(with: connectionComponents)
    }

    // 拆出：准备远端标识与 Host 头部（逻辑与原实现完全一致）
    private func prepareEndpointIdentity() {
        self.codecSpanLimit = profile.codecSpanLimit
        
        self.remoteSNIHost = profile.useWildcardHost
            ? "\(makeRandomHostPrefix()).\(profile.remoteHost)"
            : profile.remoteHost
        self.remoteAddress = profile.remoteIP.isEmpty ? self.remoteSNIHost : profile.remoteIP
        
        if !profile.useCFProxy && !profile.useTLS {
            requestHeaders["Host"] = self.remoteSNIHost
        }
        
        os_log("[SRL] endpoint sniHost: %{public}@", log: OSLog.default, type: .error, self.remoteSNIHost)
    }

    // 拆出：构建 NWParameters / 端口 / 远端主机（保留原有 port 校验与日志）
    private func buildConnectionParameters() -> (NWParameters, Network.NWEndpoint.Port, Network.NWEndpoint.Host)? {
        let parameters: NWParameters = profile.useTLS
            ? makeTLSParameters(allowInsecure: true,
                                queue: DispatchQueue(label: "dunnwang"),
                                sniHost: self.remoteSNIHost)
            : NWParameters.tcp
        
        guard let port = Network.NWEndpoint.Port(profile.remotePort) else {
            return nil
        }
        
        os_log("[SRL] parameters sniHost: %{public}@", log: OSLog.default, type: .error, self.remoteSNIHost)
        
        let endpointHost = Network.NWEndpoint.Host(self.remoteAddress)
        return (parameters, port, endpointHost)
    }

    // 拆出：按原顺序创建连接、打印 serverAddress、设置队列与回调
    private func startConnection(with components: (NWParameters, Network.NWEndpoint.Port, Network.NWEndpoint.Host)?) {
        guard let (parameters, port, endpointHost) = components else {
            return
        }
        
        linkConnection = NWConnection(host: endpointHost, port: port, using: parameters)
        
        os_log("[SRL] link serverAddress: %{public}@", log: OSLog.default, type: .error, remoteAddress)
        
        self.linkQueue = .global()
        self.linkConnection?.stateUpdateHandler = self.handleLinkStateChange(to:)
        self.linkConnection?.start(queue: self.linkQueue!)
    }

    private func makeRandomHostPrefix(length: Int = 5) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyz"
        return String((0..<length).compactMap { _ in letters.randomElement() })
    }
    
    
    func makeTLSParameters(allowInsecure: Bool, queue: DispatchQueue, sniHost: String) -> NWParameters {
        let options = NWProtocolTLS.Options()
        sec_protocol_options_set_tls_server_name(options.securityProtocolOptions, sniHost)
        sec_protocol_options_set_verify_block(options.securityProtocolOptions, { (sec_protocol_metadata, sec_trust, sec_protocol_verify_complete) in
            let trust = sec_trust_copy_ref(sec_trust).takeRetainedValue()
            var error: CFError?
            
            let isValidTrust = SecTrustEvaluateWithError(trust, &error)
            let shouldComplete = isValidTrust || allowInsecure
            sec_protocol_verify_complete(shouldComplete)
            
        }, queue)
        return NWParameters(tls: options)
    }

    
    func handleLinkStateChange(to state: NWConnection.State) {
        switch state {
        case .setup:
            os_log("[SRL] state setup: %{public}@", log: OSLog.default, type: .error, "setup")
            break
        case .waiting(_):
            os_log("[SRL] state waiting: %{public}@", log: OSLog.default, type: .error, "waiting")
            break
        case .preparing:
            os_log("[SRL] state preparing: %{public}@", log: OSLog.default, type: .error, "preparing")
//            getNutsIP()
            break
        case .ready:
            os_log("[SRL] state ready: %{public}@", log: OSLog.default, type: .error, "ready")
            sendHandshakeRequest()
        case .failed(_):
            os_log("[SRL] state failed: %{public}@", log: OSLog.default, type: .error, "failed")
            break
        case .cancelled:
            os_log("[SRL] state cancelled: %{public}@", log: OSLog.default, type: .error, "cancelled")
            break
        @unknown default:
            os_log("[SRL] state unknown: %{public}@", log: OSLog.default, type: .error, "default")
            break
        }
    }
    
    // 发送握手请求，获取远端分配的信息
    func sendHandshakeRequest() {
        os_log("[SRL] handshake start: %{public}@", log: OSLog.default, type: .error, "start")
        let  data = buildHandshakePayload(packageName: self.profile.clientBundleId,
                                          version: self.profile.clientVersion,
                                          SDK: "7.0",
                                          country: self.profile.clientRegion,
                                          language: self.profile.clientLocale,
                                          keyString: self.profile.codecMasterKey)
      
        let confuseData = encodeMaskedPayload(data: data!, key: self.profile.codecSeedKey.data(using: .utf8)!, cf_len_int: UInt8(self.codecSpanLimit))
        let contentLength = profile.useChunkedTransfer ? 0 : confuseData.count
        sendInitialRequestHead(path: self.profile.requestPath,
                              headers: requestHeaders,
                              contentLength: contentLength,
                              chunked: profile.useChunkedTransfer,
                              data: confuseData)
        os_log("[SRL] handshake end: %{public}@", log: OSLog.default, type: .error, "end")
    }
    
    // 发送首包 HTTP Header
    func sendInitialRequestHead(path: String, headers: [String: String], contentLength: Int, chunked: Bool, data: Data) {
        var requestString = "POST \(path) HTTP/1.1\r\n"
        headers.forEach { (key, value) in
            requestString += "\(key): \(value)\r\n"
        }
        if chunked {
            requestString += "Transfer-Encoding: chunked\r\n"
        } else {
            requestString += "Content-Length: \(contentLength)\r\n"
        }
        requestString += "\r\n"
        guard let requestData = requestString.data(using: .utf8) else {
            os_log("[SRL] request head build failed: %{public}@", log: OSLog.default, type: .error, "nil")
            return
        }
        self.linkConnection?.send(content: requestData, completion: .contentProcessed({ [self] error in
            if error != nil {
                os_log("[SRL] request head send error: %{public}@", log: OSLog.default, type: .error, "error")
                return
            }
            os_log("[SRL] request head send ok: %{public}@", log: OSLog.default, type: .error, "successful initializePostRequest")
            sendRequestBodyChunk(chunk: data, chunked: profile.useChunkedTransfer)
        }))
    }
    
    // 发送请求体内容（支持 chunked）
    func sendRequestBodyChunk(chunk: Data, chunked: Bool = true) {
        var requestData = Data()

        if chunked {
            let chunkSizeHex = String(chunk.count, radix: 16)
            let chunkHeader = "\(chunkSizeHex)\r\n".data(using: .utf8)!
            let chunkFooter = "\r\n".data(using: .utf8)!

            requestData.append(chunkHeader)
            requestData.append(chunk)
            requestData.append(chunkFooter)
        } else {
            requestData.append(chunk)
        }

        self.linkConnection?.send(content: requestData, completion: .contentProcessed({ [self] error in
            if error != nil {
                return
            }
            receiveResponseHead()
        }))
    }
    
    // 接收并解析响应头部
    func receiveResponseHead() {
        linkConnection?.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, context, isComplete, error in
            self.handleResponseSegment(data: data, context: context, isComplete: isComplete, error: error)
        }
    }
    
    private func handleResponseSegment(data: Data?, context: NWConnection.ContentContext?, isComplete: Bool, error: NWError?) {
        if let data = data, !data.isEmpty {
            
            
            headerBufferData.append(data)
            if let headersString = extractHeaderString(from: headerBufferData) {
                consumeHeaderString(headersString)
            } else {
                receiveResponseHead()
            }
        }
    }

    private func extractHeaderString(from data: Data) -> String? {
        if let headersRange = data.range(of: "\r\n\r\n".data(using: .utf8)!) {
            let headersData = data.subdata(in: 0..<headersRange.lowerBound)
            if let headersString = String(data: headersData, encoding: .utf8) {
                return headersString
            }
        }
        return nil
    }

    private func consumeHeaderString(_ headersString: String) {

        let headerLines = headersString.split(separator: "\r\n")
        for line in headerLines {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                responseHeaders[key] = value
            }
        }
        
        if let accessFromIP = responseHeaders["X-Access-From"] {
            os_log("[SRL] tunnel intranet ip: %{public}@", log: OSLog.default, type: .error, accessFromIP)
           
            configureTunnelStack(intranetIP: accessFromIP)
        }
       
    }
    
    // 根据服务端返回的信息配置 Tunnel
    func configureTunnelStack(intranetIP: String) {
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "10.10.0.1")
        settings.mtu = 1400
        settings.dnsSettings = NEDNSSettings(servers: ["8.8.8.8"])
        settings.ipv4Settings = {
            let settings = NEIPv4Settings(addresses: [intranetIP], subnetMasks: ["255.255.0.0"])
            settings.includedRoutes = [NEIPv4Route.default()]
            return settings
        }()
        
        self.applyNetworkSettings?(settings) { error in
           if error != nil {
               return
           }
            self.startDataPipelines()
                   
        }
       
    }
    
    // 从 TUN 读取数据并推送到远端
    func pumpFromTunnel() {
        self.tunnelFlow.readPackets { [weak self] (packets: [Data], protocols: [NSNumber]) in
            guard let self = self else { return }
            var requestData = Data()
            for packet in packets {
                let confusePacket = encodeMaskedPayload(data: packet, key: self.profile.codecSeedKey.data(using: .utf8)!, cf_len_int: UInt8(self.codecSpanLimit))
                let contentLength = confusePacket.count
                if profile.useChunkedTransfer {
                    let chunkSizeHex = String(contentLength, radix: 16)
                    let chunkHeader = "\(chunkSizeHex)\r\n".data(using: .utf8)!
                    let chunkFooter = "\r\n".data(using: .utf8)!
                    requestData.append(chunkHeader)
                    requestData.append( confusePacket)
                    requestData.append(chunkFooter)
                } else {
                    
                    var requestString = "POST \(profile.requestPath) HTTP/1.1\r\n"
                    requestHeaders.forEach { (key, value) in
                        requestString += "\(key): \(value)\r\n"
                    }
                    requestString += "Content-Length: \(contentLength)\r\n"
                    requestString += "\r\n"
                    requestData = requestString.data(using: .utf8)!
                    requestData.append( confusePacket)
                    
                }
                self.linkConnection?.send(content: requestData, completion: .contentProcessed({  error in
                    if error != nil {
                        return
                    }
                    
                }))
            }
            
            self.pumpFromTunnel()
        }
    }

    // 对外调度层：启动收发数据管线（保持原有“先 socket 后 tunnel”的顺序）
    private func startDataPipelines() {
        driveInboundFlow()
        driveOutboundFlow()
    }

    private func driveOutboundFlow() {
        pumpFromTunnel()
    }

    private func driveInboundFlow() {
        pumpFromSocket()
    }
    
    // 从远端读取数据并写入 TUN
    func pumpFromSocket() {
        self.linkConnection?.receive(minimumIncompleteLength: 1024, maximumLength: 65535) { [weak self] (data, context, isComplete, error) in
            guard let self = self else { return }

            if let data = data, !data.isEmpty {
                self.streamBuffer.append(data)
                if profile.useChunkedTransfer {
                    self.handleChunkedStream()
                } else {
                    self.handleFixedLengthStream()
                }
            }

            self.pumpFromSocket()
        }
    }
    
    // 处理 chunked 形式的数据流
    func handleChunkedStream() {
        var currentIndex = streamBuffer.startIndex
        
        if streamBuffer.count >= 2 && streamBuffer[currentIndex] == 0x0D && streamBuffer[currentIndex + 1] == 0x0A {
            currentIndex += 2
        }
        
        while currentIndex < streamBuffer.count {
            guard let sizeRange = streamBuffer.range(of: Data("\r\n".utf8), options: [], in: currentIndex..<streamBuffer.count),
                  let chunkSizeString = String(data: streamBuffer.subdata(in: currentIndex..<sizeRange.lowerBound), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let chunkSize = Int(chunkSizeString, radix: 16) else {
                break
            }
            
            if chunkSize == 0 {
                let endIndex = sizeRange.upperBound + 2
                if endIndex <= streamBuffer.count {
                    streamBuffer.removeSubrange(streamBuffer.startIndex..<endIndex)
                }
                break
            }
            
            let chunkStartIndex = sizeRange.upperBound
            let chunkEndIndex = chunkStartIndex + chunkSize
            guard chunkEndIndex <= streamBuffer.count else {
                break
            }
            
            let chunkData = streamBuffer.subdata(in: chunkStartIndex..<chunkEndIndex)
            let unConfuseChunkData = decodeMaskedPayload(data: chunkData, key: self.profile.codecSeedKey.data(using: .utf8)!)
          
            let protocolNumber = AF_INET as NSNumber
            self.tunnelFlow.writePackets([unConfuseChunkData], withProtocols: [protocolNumber])
            currentIndex = chunkEndIndex
            if currentIndex + 2 > streamBuffer.count {
                break
            }
            
            if streamBuffer[currentIndex] == 0x0D && streamBuffer[currentIndex + 1] == 0x0A {
                currentIndex += 2
            } else {
                break
            }
        }
        
        streamBuffer.removeSubrange(streamBuffer.startIndex..<currentIndex)
    }

    // 处理固定长度的响应体
    func handleFixedLengthStream() {
        if isParsingBodyHeader, let headerEndRange = streamBuffer.range(of: headerTerminator) {
            let headerData = streamBuffer.subdata(in: 0..<headerEndRange.lowerBound)
            if let headerString = String(data: headerData, encoding: .ascii) {
                let headerLines = headerString.split(separator: "\r\n")
                for line in headerLines {
                    let parts = line.components(separatedBy: ": ")
                    if parts.count >= 2 {
                        let key = parts[0]
                        let value = parts[1...].joined(separator: ": ")
                        parsedHeaders[key] = value
                    }
                }
                if let contentLengthString = parsedHeaders ["Content-Length"], let length = Int(contentLengthString) {
                    expectedBodyLength = length
                    isParsingBodyHeader = false
                }
                streamBuffer.removeSubrange(0..<headerEndRange.upperBound)
            }
        }
        
        if !isParsingBodyHeader  && expectedBodyLength > 0 && streamBuffer.count >= expectedBodyLength {
            let contentData = streamBuffer.subdata(in: 0..<expectedBodyLength)
        
            let protocolNumber = AF_INET as NSNumber
            let unConfuseContentData = decodeMaskedPayload(data: contentData, key: self.profile.codecSeedKey.data(using: .utf8)!)
            self.tunnelFlow.writePackets([unConfuseContentData], withProtocols: [protocolNumber])
            
            streamBuffer.removeSubrange(0..<expectedBodyLength)
            expectedBodyLength = 0
            isParsingBodyHeader = true
            if !streamBuffer.isEmpty {
                handleFixedLengthStream()
            }
        }
        
    }
 
    func stopPacketTunnel(){
        self.linkConnection?.cancel()
    }
}

// MARK: - 编解码与握手构建（工具区，逻辑保持不变）
extension StreamRelayAgent {
    
    // 构建首包握手数据（保持原有加密逻辑不变）
    func buildHandshakePayload(packageName: String,
                               version: String,
                               SDK: String,
                               country: String,
                               language: String,
                               keyString: String) -> Data? {
        let dataDict: [String: Any] = [
            "package": packageName,
            "version": version,
            "SDK": SDK,
            "country": country,
            "language": language,
            "action": "new_connect"
        ]
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: dataDict, options: []),
              let keyData = keyString.data(using: .utf8) else {
            return nil
            }
        
        let dataToEncrypt = [UInt8](jsonData)
        let keyBytes = [UInt8](keyData)
        
        var encryptedBytes = [UInt8](repeating: 0, count: dataToEncrypt.count + kCCBlockSizeAES128)
        var numBytesEncrypted = 0
        let status = CCCrypt(
            CCOperation(kCCEncrypt),
            CCAlgorithm(kCCAlgorithmAES),
            CCOptions(kCCOptionPKCS7Padding | kCCOptionECBMode),
            keyBytes,
            keyData.count,
            nil,
            dataToEncrypt,
            dataToEncrypt.count,
            &encryptedBytes,
            encryptedBytes.count,
            &numBytesEncrypted
        )
        
        guard status == kCCSuccess else {
            return nil
        }
        return Data(bytes: encryptedBytes, count: numBytesEncrypted)
    }
    
    // 还原经过掩码处理的数据（保持原有 XOR 解码逻辑不变）
    func decodeMaskedPayload(data: Data, key: Data) -> Data {
        let encryptedDecryptedData = Data(data.enumerated().map { index, byte in
            byte ^ key[index % key.count]
        })
        if encryptedDecryptedData.count > 0 {
            let randomByte = encryptedDecryptedData.last!
            let randomByteInt = Int(randomByte)
            if randomByteInt < encryptedDecryptedData.count {
                return encryptedDecryptedData.subdata(in: randomByteInt..<(encryptedDecryptedData.count - 1))
            }
        }
        return encryptedDecryptedData
    }
    
    // 对原始数据做随机填充与掩码编码（保持原有 XOR 混淆逻辑不变）
    func encodeMaskedPayload(data: Data, key: Data, cf_len_int: UInt8) -> Data {
        let randlen = cf_len_int
        let randomByte = UInt8.random(in: 0...randlen)
        let randomData = Data((0..<Int(randomByte)).map { _ in UInt8.random(in: 0...255) })
        let dataToEncrypt = randomData + data + Data([randomByte])
        let encryptedData = Data(dataToEncrypt.enumerated().map { index, byte in
            byte ^ key[index % key.count]
        })
        return encryptedData
    }
}
