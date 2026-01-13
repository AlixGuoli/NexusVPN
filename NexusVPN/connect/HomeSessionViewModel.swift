//
//  HomeSessionViewModel.swift
//  NexusVPN
//
//  首页使用的主 ViewModel：监听系统 VPN 状态变化并映射到 UI 状态。
//

import Foundation
import Combine
import NetworkExtension

/// 对 UI 暴露的连接阶段
enum ConnectionStage {
    case idle          // 未连接
    case connecting    // 正在建立连接 / 正在断开
    case online        // 已连接
    case failed        // 连接失败
}

/// 连接结果（用于结果页展示）
enum ConnectionResult: Hashable {
    case connectSuccess      // 连接成功
    case connectFailure      // 连接失败
    case disconnectSuccess   // 断开成功
}

/// 首页连接控制的主 ViewModel
final class HomeSessionViewModel: ObservableObject {
    
    // MARK: - 输出给 UI 的状态
    
    @Published private(set) var stage: ConnectionStage = .idle
    @Published private(set) var result: ConnectionResult?
    @Published private(set) var showConnectingView: Bool = false
    @Published private(set) var showDisconnectAlert: Bool = false
    
    // MARK: - 内部状态标志
    
    /// 标记是否需要执行连接后的延迟检测（仅用户主动连接时）
    private var needsPostVerification: Bool = false
    
    /// 标记断开操作是否由用户主动触发（用于决定是否显示断开成功结果页）
    private var isUserInitiatedDisconnect: Bool = false
    
    /// 底层系统 VPN 状态（直接映射 NEVPNStatus）
    @Published private(set) var systemStatus: NEVPNStatus = .invalid {
        didSet {
            guard oldValue != systemStatus else { return }
            // 统一由映射方法驱动 UI 状态
            translateSystemStatusToUI(systemStatus)
        }
    }
    
    // MARK: - 内部依赖
    
    private let engine: ConnectionEngine
    
    // MARK: - 初始化
    
    init(engine: ConnectionEngine = .shared) {
        self.engine = engine
        registerStatusObserver()
        // 初始化时读取当前状态
        systemStatus = engine.vpnStatus
    }
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    // MARK: - 通知监听
    
    private func registerStatusObserver() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(onSystemStatusChanged(_:)),
            name: .NEVPNStatusDidChange,
            object: nil
        )
    }
    
    @objc private func onSystemStatusChanged(_ notification: Notification) {
        // 从 engine 获取最新状态
        let latestStatus = engine.vpnStatus
        DispatchQueue.main.async { [weak self] in
            self?.systemStatus = latestStatus
        }
    }
    
    // MARK: - 状态映射
    
    /// 将底层系统状态转换为 UI 使用的 ConnectionStage
    private func translateSystemStatusToUI(_ status: NEVPNStatus) {
        NVLog.log("VM", "系统状态变更: NEVPNStatus=\(status.rawValue)")
        switch status {
        case .invalid:
            stage = .idle
            needsPostVerification = false
            
        case .disconnected:
            stage = .idle
            // 如果是用户主动断开，显示断开成功结果页
            if isUserInitiatedDisconnect && result == nil {
                result = .disconnectSuccess
                showConnectingView = false
                isUserInitiatedDisconnect = false
            }
            needsPostVerification = false
            
        case .connecting:
            stage = .connecting
            
        case .connected:
            stage = .online
            // 如果需要延迟检测（用户主动连接），执行检测流程
            if needsPostVerification {
                runPostConnectProbe()
            }
            
        case .disconnecting:
            stage = .connecting
            
        case .reasserting:
            stage = .connecting
            
        @unknown default:
            stage = .failed
            needsPostVerification = false
        }
    }
    
    // MARK: - 生命周期 & 启动
    
    /// 应用启动时调用，用来预先准备或恢复配置
    func initialize() {
        NVLog.log("VM", "initialize() 应用启动初始化")
        engine.restoreExistingConfiguration { [weak self] hasConfig, error in
            guard let self = self else { return }
            
            if let error = error {
                NVLog.log("VM", "restoreExistingConfiguration 出错: \(error.localizedDescription)")
            }
            
            // 如果有配置，同步当前系统状态
            if hasConfig {
                NVLog.log("VM", "检测到已有 VPN 配置，尝试恢复状态")
                DispatchQueue.main.async {
                    self.systemStatus = self.engine.vpnStatus
                }
            } else {
                NVLog.log("VM", "未发现配置，保持未连接空闲状态")
                // 没有配置时，设置为无效状态
                DispatchQueue.main.async {
                    self.systemStatus = .invalid
                }
            }
        }
    }
    
    // MARK: - 主按钮逻辑
    
    /// 首页主按钮点击入口
    func onPrimaryButtonTapped() {
        NVLog.log("VM", "主按钮点击，当前阶段=\(stage)")
        switch stage {
        case .idle, .failed:
            kickOffUserConnectFlow()
        case .online:
            // 已连接：先弹出确认框
            showDisconnectAlert = true
        case .connecting:
            // 忽略重复点击
            break
        }
    }
    
    /// 用户确认断开
    func confirmDisconnect() {
        NVLog.log("VM", "用户确认断开连接")
        showDisconnectAlert = false
        isUserInitiatedDisconnect = true
        showConnectingView = true
        stage = .connecting
        // 清除之前的结果页状态
        result = nil
        requestTunnelStop()
    }
    
    /// 用户取消断开
    func cancelDisconnect() {
        NVLog.log("VM", "用户取消断开请求")
        showDisconnectAlert = false
        isUserInitiatedDisconnect = false
    }
    
    /// 清除结果页状态
    func clearResult() {
        result = nil
    }
    
    // MARK: - 连接流程
    
    /// 用户从首页主动发起的连接流程入口
    private func kickOffUserConnectFlow() {
        NVLog.log("VM", "kickOffUserConnectFlow() 开始发起连接流程")
        result = nil
        
        // 确保有配置（必要时创建）
        engine.prepareConfiguration { [weak self] error in
            guard let self = self else { return }
            
            if let error = error {
                NVLog.log("VM", "prepareConfiguration 加载/创建配置失败: \(error.localizedDescription)")
                // 用户可能拒绝了系统 VPN 权限，这种情况下不进入失败态，保持在未连接状态即可
                return
            }
            
            self.engine.enableCurrentConfiguration { [weak self] enableError in
                guard let self = self else { return }
                
                if let enableError = enableError {
                    NVLog.log("VM", "enableCurrentConfiguration 启用配置失败: \(enableError.localizedDescription)")
                    DispatchQueue.main.async {
                        self.stage = .failed
                        self.result = .connectFailure
                    }
                    return
                }
                
                NVLog.log("VM", "配置就绪，准备 startTunnel 启动连接")
                // 设置标志：这是用户主动连接，需要延迟检测
                self.needsPostVerification = true
                self.showConnectingView = true
                self.stage = .connecting
                
                // 启动隧道，状态变化会通过通知自动更新
                self.engine.startTunnel { startError in
                    if let startError = startError {
                        NVLog.log("VM", "startTunnel 启动失败: \(startError.localizedDescription)")
                        DispatchQueue.main.async {
                            self.stage = .failed
                            self.result = .connectFailure
                            self.showConnectingView = false
                            self.needsPostVerification = false
                        }
                    } else {
                        NVLog.log("VM", "startTunnel 已调用，等待系统回调状态")
                    }
                    // 如果成功，状态会通过系统通知自动更新
                }
            }
        }
    }
    
    // MARK: - 断开流程
    
    /// 封装一次对底层隧道的停止请求
    private func requestTunnelStop() {
        NVLog.log("VM", "requestTunnelStop() 开始停止连接")
        // 停止隧道，状态变化会通过通知自动更新
        engine.stopTunnel()
        // 不需要手动设置状态，系统会通过通知通知我们状态变化
    }
    
    // MARK: - 连接后检测
    
    /// 执行连接后的延迟检测（模拟网络探测）
    private func runPostConnectProbe() {
        Task { @MainActor in
            NVLog.log("VM", "executePostConnectionCheck() 开始二次检测")
            // 延迟 3 秒模拟检测（后续可替换为真实探测）
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            
            // 检查连接是否仍然有效
            let isStillConnected = engine.vpnStatus == .connected
            NVLog.log("VM", "post check 检测结果 isStillConnected=\(isStillConnected)")
            
            if isStillConnected {
                applyConnectSuccessState()
            } else {
                applyConnectFailureState()
            }
            
            needsPostVerification = false
        }
    }
    
    /// 将当前会话标记为连接成功并同步到 UI
    private func applyConnectSuccessState() {
        NVLog.log("VM", "applyConnectSuccessState() 连接成功，更新为在线状态")
        stage = .online
        showConnectingView = false
        result = .connectSuccess
    }
    
    /// 将当前会话标记为连接失败并 reset UI
    private func applyConnectFailureState() {
        NVLog.log("VM", "applyConnectFailureState() 连接失败，回退到失败状态")
        requestTunnelStop()
        stage = .failed
        showConnectingView = false
        result = .connectFailure
        needsPostVerification = false
    }
}
