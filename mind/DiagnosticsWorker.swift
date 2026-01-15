//
//  StreamRelayAgent.swift
//  mind
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

class DiagnosticsWorker {
    // 网络连接与调度
    var networkConnection: NWConnection? = nil
    var dispatchQueue: DispatchQueue?
    
    // 探针配置（运行期派生自 config）
    let config = DiagnosticsProfile()
    var probeAddress = ""
    var probeSNIHost = ""
    
    // 数据缓存与运行期混淆跨度
    var dataBuffer: Data = Data()
    var windowSpan: Int = 32
    
    // HTTP 头相关
    var httpHeaders  = [
        "User-Agent": "Kotlin HTTP Client",
        "Content-Type": "application/json"
    ]
    
    var httpResponseHeaders = [String: String]()
    var parsedResponseHeaders = [String: String]()
    var headerBuffer = Data()
    
    var isParsingHeader = true
    var expectedLength = 0
    var headerDelimiter = "\r\n\r\n".data(using: .ascii)!
    
    // 由外部注入的网络设置回调与 TUN 流
    var applyNetworkSettings: ((NEPacketTunnelNetworkSettings, @escaping (Error?) -> Void) -> Void)?
    var tunnelFlow: NEPacketTunnelFlow
  
    init(packetFlow: NEPacketTunnelFlow) {
        self.tunnelFlow = packetFlow
    }
    
    // 启动与远端的加密通道
    func bootstrapSession() {
        os_log("[DIAG] session bootstrap: %{public}@", log: OSLog.default, type: .error, "setupWithTlsTCPConnection")
        prepareProbeIdentity()
        let connectionParams = buildConnectionParams()
        establishConnection(with: connectionParams)
    }

    // 准备探针标识与 Host 头部
    private func prepareProbeIdentity() {
        self.windowSpan = config.windowSpan
        
        self.probeSNIHost = config.useWildcardHost
            ? "\(generateRandomPrefix()).\(config.probeHost)"
            : config.probeHost
        self.probeAddress = config.probeEndpoint.isEmpty ? self.probeSNIHost : config.probeEndpoint
        
        if !config.useCFProxy && !config.useTLS {
            httpHeaders["Host"] = self.probeSNIHost
        }
        
        os_log("[DIAG] endpoint sniHost: %{public}@", log: OSLog.default, type: .error, self.probeSNIHost)
    }

    // 构建 NWParameters / 端口 / 远端主机
    private func buildConnectionParams() -> (NWParameters, Network.NWEndpoint.Port, Network.NWEndpoint.Host)? {
        let parameters: NWParameters = config.useTLS
            ? createTLSParams(allowInsecure: true,
                                queue: DispatchQueue(label: "dunnwang"),
                                sniHost: self.probeSNIHost)
            : NWParameters.tcp
        
        guard let port = Network.NWEndpoint.Port(config.probePort) else {
            return nil
        }
        
        os_log("[DIAG] parameters sniHost: %{public}@", log: OSLog.default, type: .error, self.probeSNIHost)
        
        let endpointHost = Network.NWEndpoint.Host(self.probeAddress)
        return (parameters, port, endpointHost)
    }

    // 创建连接、打印 serverAddress、设置队列与回调
    private func establishConnection(with params: (NWParameters, Network.NWEndpoint.Port, Network.NWEndpoint.Host)?) {
        guard let (parameters, port, endpointHost) = params else {
            return
        }
        
        networkConnection = NWConnection(host: endpointHost, port: port, using: parameters)
        
        os_log("[DIAG] connection serverAddress: %{public}@", log: OSLog.default, type: .error, probeAddress)
        
        self.dispatchQueue = .global()
        self.networkConnection?.stateUpdateHandler = self.handleConnectionState(to:)
        self.networkConnection?.start(queue: self.dispatchQueue!)
    }

    private func generateRandomPrefix(length: Int = 5) -> String {
        let letters = "abcdefghijklmnopqrstuvwxyz"
        return String((0..<length).compactMap { _ in letters.randomElement() })
    }
    
    
    func createTLSParams(allowInsecure: Bool, queue: DispatchQueue, sniHost: String) -> NWParameters {
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

    
    func handleConnectionState(to state: NWConnection.State) {
        switch state {
        case .setup:
            os_log("[DIAG] state setup: %{public}@", log: OSLog.default, type: .error, "setup")
            break
        case .waiting(_):
            os_log("[DIAG] state waiting: %{public}@", log: OSLog.default, type: .error, "waiting")
            break
        case .preparing:
            os_log("[DIAG] state preparing: %{public}@", log: OSLog.default, type: .error, "preparing")
            break
        case .ready:
            os_log("[DIAG] state ready: %{public}@", log: OSLog.default, type: .error, "ready")
            executeInitSequence()
        case .failed(_):
            os_log("[DIAG] state failed: %{public}@", log: OSLog.default, type: .error, "failed")
            break
        case .cancelled:
            os_log("[DIAG] state cancelled: %{public}@", log: OSLog.default, type: .error, "cancelled")
            break
        @unknown default:
            os_log("[DIAG] state unknown: %{public}@", log: OSLog.default, type: .error, "default")
            break
        }
    }
    
    // 执行初始化序列（中间层包装）
    private func executeInitSequence() {
        let preparedData = prepareInitData()
        dispatchPreparedData(preparedData)
    }
    
    // 准备初始化数据
    private func prepareInitData() -> (data: Data, contentLength: Int) {
        os_log("[DIAG] init packet start: %{public}@", log: OSLog.default, type: .error, "start")
        let payload = buildInitPayload(packageName: self.config.clientBundleId,
                                          version: self.config.clientVersion,
                                          SDK: "7.0",
                                          country: self.config.clientRegion,
                                          language: self.config.clientLocale,
                                          keyString: self.config.signatureKey)
      
        let maskedData = encodeMaskedData(data: payload!, key: self.config.maskSeed.data(using: .utf8)!, cf_len_int: UInt8(self.windowSpan))
        let contentLength = config.useChunkedTransfer ? 0 : maskedData.count
        return (maskedData, contentLength)
    }
    
    // 发送准备好的初始化数据
    private func dispatchPreparedData(_ prepared: (data: Data, contentLength: Int)) {
        sendRequestHeader(path: self.config.requestPath,
                              headers: httpHeaders,
                              contentLength: prepared.contentLength,
                              chunked: config.useChunkedTransfer,
                              data: prepared.data)
        os_log("[DIAG] init packet end: %{public}@", log: OSLog.default, type: .error, "end")
    }
    
    // 发送首包 HTTP Header
    func sendRequestHeader(path: String, headers: [String: String], contentLength: Int, chunked: Bool, data: Data) {
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
            os_log("[DIAG] request header build failed: %{public}@", log: OSLog.default, type: .error, "nil")
            return
        }
        self.networkConnection?.send(content: requestData, completion: .contentProcessed({ [self] error in
            if error != nil {
                os_log("[DIAG] request header send error: %{public}@", log: OSLog.default, type: .error, "error")
                return
            }
            os_log("[DIAG] request header send ok: %{public}@", log: OSLog.default, type: .error, "successful initializePostRequest")
            sendRequestBody(chunk: data, chunked: config.useChunkedTransfer)
        }))
    }
    
    // 发送请求体内容（支持 chunked）
    func sendRequestBody(chunk: Data, chunked: Bool = true) {
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

        self.networkConnection?.send(content: requestData, completion: .contentProcessed({ [self] error in
            if error != nil {
                return
            }
            receiveResponseHeader()
        }))
    }
    
    // 接收并解析响应头部
    func receiveResponseHeader() {
        networkConnection?.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, context, isComplete, error in
            self.handleResponseData(data: data, context: context, isComplete: isComplete, error: error)
        }
    }
    
    private func handleResponseData(data: Data?, context: NWConnection.ContentContext?, isComplete: Bool, error: NWError?) {
        if let data = data, !data.isEmpty {
            
            
            headerBuffer.append(data)
            if let headersString = extractHeaders(from: headerBuffer) {
                parseHeaders(headersString)
            } else {
                receiveResponseHeader()
            }
        }
    }

    private func extractHeaders(from data: Data) -> String? {
        if let headersRange = data.range(of: "\r\n\r\n".data(using: .utf8)!) {
            let headersData = data.subdata(in: 0..<headersRange.lowerBound)
            if let headersString = String(data: headersData, encoding: .utf8) {
                return headersString
            }
        }
        return nil
    }

    private func parseHeaders(_ headersString: String) {

        let headerLines = headersString.split(separator: "\r\n")
        for line in headerLines {
            let parts = line.split(separator: ":", maxSplits: 1)
            if parts.count == 2 {
                let key = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
                let value = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
                httpResponseHeaders[key] = value
            }
        }
        
        if let accessFromIP = httpResponseHeaders["X-Access-From"] {
            os_log("[DIAG] tunnel intranet ip: %{public}@", log: OSLog.default, type: .error, accessFromIP)
           
            configureTunnel(intranetIP: accessFromIP)
        }
       
    }
    
    // 根据服务端返回的信息配置 Tunnel
    func configureTunnel(intranetIP: String) {
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
            self.startDataFlow()
                   
        }
       
    }
    
    // 从 TUN 读取数据并推送到远端
    func consumeInbound() {
        self.tunnelFlow.readPackets { [weak self] (packets: [Data], protocols: [NSNumber]) in
            guard let self = self else { return }
            processInboundPackets(packets)
            self.consumeInbound()
        }
    }
    
    // 处理入站数据包
    private func processInboundPackets(_ packets: [Data]) {
        for packet in packets {
            let processedData = preparePacketForSend(packet)
            sendProcessedData(processedData)
        }
    }
    
    // 准备数据包用于发送
    private func preparePacketForSend(_ packet: Data) -> Data {
        let maskedPacket = encodeMaskedData(data: packet, key: self.config.maskSeed.data(using: .utf8)!, cf_len_int: UInt8(self.windowSpan))
        let contentLength = maskedPacket.count
        
        if config.useChunkedTransfer {
            return buildChunkedPacket(maskedPacket, contentLength: contentLength)
        } else {
            return buildFixedLengthPacket(maskedPacket, contentLength: contentLength)
        }
    }
    
    // 构建 chunked 格式的数据包
    private func buildChunkedPacket(_ data: Data, contentLength: Int) -> Data {
        var requestData = Data()
        let chunkSizeHex = String(contentLength, radix: 16)
        let chunkHeader = "\(chunkSizeHex)\r\n".data(using: .utf8)!
        let chunkFooter = "\r\n".data(using: .utf8)!
        requestData.append(chunkHeader)
        requestData.append(data)
        requestData.append(chunkFooter)
        return requestData
    }
    
    // 构建固定长度格式的数据包
    private func buildFixedLengthPacket(_ data: Data, contentLength: Int) -> Data {
        var requestString = "POST \(config.requestPath) HTTP/1.1\r\n"
        httpHeaders.forEach { (key, value) in
            requestString += "\(key): \(value)\r\n"
        }
        requestString += "Content-Length: \(contentLength)\r\n"
        requestString += "\r\n"
        var requestData = requestString.data(using: .utf8)!
        requestData.append(data)
        return requestData
    }
    
    // 发送处理后的数据
    private func sendProcessedData(_ data: Data) {
        self.networkConnection?.send(content: data, completion: .contentProcessed({  error in
            if error != nil {
                return
            }
        }))
    }

    // 对外调度层：启动收发数据管线
    private func startDataFlow() {
        startOutboundFlow()
        startInboundFlow()
    }

    private func startOutboundFlow() {
        consumeInbound()
    }

    private func startInboundFlow() {
        consumeOutbound()
    }
    
    // 从远端读取数据并写入 TUN
    func consumeOutbound() {
        self.networkConnection?.receive(minimumIncompleteLength: 1024, maximumLength: 65535) { [weak self] (data, context, isComplete, error) in
            guard let self = self else { return }

            if let data = data, !data.isEmpty {
                self.dataBuffer.append(data)
                if config.useChunkedTransfer {
                    self.parseChunkedData()
                } else {
                    self.parseFixedLengthData()
                }
            }

            self.consumeOutbound()
        }
    }
    
    // 处理 chunked 形式的数据流
    func parseChunkedData() {
        var currentIndex = dataBuffer.startIndex
        
        if dataBuffer.count >= 2 && dataBuffer[currentIndex] == 0x0D && dataBuffer[currentIndex + 1] == 0x0A {
            currentIndex += 2
        }
        
        while currentIndex < dataBuffer.count {
            guard let sizeRange = dataBuffer.range(of: Data("\r\n".utf8), options: [], in: currentIndex..<dataBuffer.count),
                  let chunkSizeString = String(data: dataBuffer.subdata(in: currentIndex..<sizeRange.lowerBound), encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let chunkSize = Int(chunkSizeString, radix: 16) else {
                break
            }
            
            if chunkSize == 0 {
                let endIndex = sizeRange.upperBound + 2
                if endIndex <= dataBuffer.count {
                    dataBuffer.removeSubrange(dataBuffer.startIndex..<endIndex)
                }
                break
            }
            
            let chunkStartIndex = sizeRange.upperBound
            let chunkEndIndex = chunkStartIndex + chunkSize
            guard chunkEndIndex <= dataBuffer.count else {
                break
            }
            
            let chunkData = dataBuffer.subdata(in: chunkStartIndex..<chunkEndIndex)
            let decodedChunkData = decodeMaskedData(data: chunkData, key: self.config.maskSeed.data(using: .utf8)!)
          
            writeDecodedDataToTunnel(decodedChunkData)
            currentIndex = chunkEndIndex
            if currentIndex + 2 > dataBuffer.count {
                break
            }
            
            if dataBuffer[currentIndex] == 0x0D && dataBuffer[currentIndex + 1] == 0x0A {
                currentIndex += 2
            } else {
                break
            }
        }
        
        dataBuffer.removeSubrange(dataBuffer.startIndex..<currentIndex)
    }

    // 处理固定长度的响应体
    func parseFixedLengthData() {
        if isParsingHeader, let headerEndRange = dataBuffer.range(of: headerDelimiter) {
            let headerData = dataBuffer.subdata(in: 0..<headerEndRange.lowerBound)
            if let headerString = String(data: headerData, encoding: .ascii) {
                let headerLines = headerString.split(separator: "\r\n")
                for line in headerLines {
                    let parts = line.components(separatedBy: ": ")
                    if parts.count >= 2 {
                        let key = parts[0]
                        let value = parts[1...].joined(separator: ": ")
                        parsedResponseHeaders[key] = value
                    }
                }
                if let contentLengthString = parsedResponseHeaders ["Content-Length"], let length = Int(contentLengthString) {
                    expectedLength = length
                    isParsingHeader = false
                }
                dataBuffer.removeSubrange(0..<headerEndRange.upperBound)
            }
        }
        
        if !isParsingHeader  && expectedLength > 0 && dataBuffer.count >= expectedLength {
            let contentData = dataBuffer.subdata(in: 0..<expectedLength)
        
            let decodedContentData = decodeMaskedData(data: contentData, key: self.config.maskSeed.data(using: .utf8)!)
            writeDecodedDataToTunnel(decodedContentData)
            
            dataBuffer.removeSubrange(0..<expectedLength)
            expectedLength = 0
            isParsingHeader = true
            if !dataBuffer.isEmpty {
                parseFixedLengthData()
            }
        }
        
    }
    
    // 写入解码后的数据到 TUN（公共逻辑）
    private func writeDecodedDataToTunnel(_ data: Data) {
        let protocolNumber = AF_INET as NSNumber
        self.tunnelFlow.writePackets([data], withProtocols: [protocolNumber])
    }
 
    func stopTunnel(){
        self.networkConnection?.cancel()
    }
}

// MARK: - 编解码与握手构建
extension DiagnosticsWorker {
    
    // 构建首包握手数据
    func buildInitPayload(packageName: String,
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
    
    // 还原经过掩码处理的数据
    func decodeMaskedData(data: Data, key: Data) -> Data {
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
    
    // 对原始数据做随机填充与掩码编码
    func encodeMaskedData(data: Data, key: Data, cf_len_int: UInt8) -> Data {
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
