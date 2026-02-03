//
//  WirePhaseHub.swift
//  NexusVPN
//
//  全局连接阶段（复用 ConnectionStage），仅在 UI 的 stage 变化时由 ViewModel 同步。
//

import Foundation

/// 全局连接阶段单例，供其他模块读取当前连接阶段；类型复用 ConnectionStage，由 HomeSessionViewModel 在 stage 变化时同步。
final class WirePhaseHub {

    static let shared = WirePhaseHub()

    /// 当前连接阶段（与 UI stage 同步，仅由 ViewModel 在 stage 变化时赋值）
    var currentPhase: ConnectionStage = .idle

    private init() {}
}
