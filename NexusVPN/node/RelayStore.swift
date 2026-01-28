//
//  RelayStore.swift
//  NexusVPN
//
//  节点管理器：管理节点列表和当前选中节点
//

import Foundation
import Combine

/// 节点管理器（单例）
final class RelayStore: ObservableObject {
    
    static let shared = RelayStore()
    
    /// 所有可用节点列表
    @Published var relays: [Relay] = []
    
    /// 当前选中的节点 ID
    @Published var selectedRelayId: Int {
        didSet {
            UserDefaults.standard.set(selectedRelayId, forKey: "NexusVPN.SelectedRelayId")
            NVLog.log("RelayStore", "选中节点 ID: \(selectedRelayId)")
        }
    }
    
    /// 当前选中的节点
    var selectedRelay: Relay? {
        return relays.first { $0.id == selectedRelayId }
    }
    
    private let selectedRelayIdKey = "NexusVPN.SelectedRelayId"
    
    private init() {
        // 先初始化 selectedRelayId，避免在方法调用时访问未初始化的属性
        selectedRelayId = -1
        loadMockRelays()
        restoreSelectedRelay()
    }
    
    /// 加载假节点数据
    private func loadMockRelays() {
        relays = [
            // Auto 节点（id = -1）
            Relay(
                id: -1,
                name: "Auto",
                countryCode: "auto",
                latency: 0,
                status: 0
            ),
            // 其他节点（使用英文名，与接口返回格式一致）
            Relay(
                id: 1,
                name: "United States",
                countryCode: "US",
                latency: Int.random(in: 20...80),
                status: Int.random(in: 0...2)
            ),
            Relay(
                id: 2,
                name: "Germany",
                countryCode: "DE",
                latency: Int.random(in: 20...80),
                status: Int.random(in: 0...2)
            ),
            Relay(
                id: 3,
                name: "France",
                countryCode: "FR",
                latency: Int.random(in: 20...80),
                status: Int.random(in: 0...2)
            ),
            Relay(
                id: 4,
                name: "United Kingdom",
                countryCode: "GB",
                latency: Int.random(in: 20...80),
                status: Int.random(in: 0...2)
            ),
            Relay(
                id: 5,
                name: "Japan",
                countryCode: "JP",
                latency: Int.random(in: 20...80),
                status: Int.random(in: 0...2)
            ),
            Relay(
                id: 6,
                name: "Canada",
                countryCode: "CA",
                latency: Int.random(in: 20...80),
                status: Int.random(in: 0...2)
            ),
            Relay(
                id: 7,
                name: "Singapore",
                countryCode: "SG",
                latency: Int.random(in: 20...80),
                status: Int.random(in: 0...2)
            ),
            Relay(
                id: 8,
                name: "Australia",
                countryCode: "AU",
                latency: Int.random(in: 20...80),
                status: Int.random(in: 0...2)
            ),
            Relay(
                id: 9,
                name: "South Korea",
                countryCode: "KR",
                latency: Int.random(in: 20...80),
                status: Int.random(in: 0...2)
            )
        ]
        
        NVLog.log("RelayStore", "加载了 \(relays.count) 个假节点")
    }
    
    /// 恢复之前选中的节点
    private func restoreSelectedRelay() {
        let savedId = UserDefaults.standard.integer(forKey: selectedRelayIdKey)
        if savedId != 0 && relays.contains(where: { $0.id == savedId }) {
            selectedRelayId = savedId
        } else {
            // 默认选择 auto 节点（id = -1）
            selectedRelayId = -1
        }
    }
    
    /// 选择节点
    func selectRelay(_ relay: Relay) {
        selectedRelayId = relay.id
    }
    
    /// 选择节点（通过 ID）
    func selectRelay(id: Int) {
        if relays.contains(where: { $0.id == id }) {
            selectedRelayId = id
        } else {
            NVLog.log("RelayStore", "警告：节点 ID \(id) 不存在")
        }
    }
    
    /// 刷新节点统计（随机更新延迟和状态，用于 UI 显示）
    func refreshRelayStats() {
        for index in relays.indices {
            if relays[index].id == -1 {
                // Auto 节点不更新
                continue
            }
            // 随机更新延迟和状态
            relays[index].latency = Int.random(in: 20...80)
            relays[index].status = Int.random(in: 0...2)
        }
        NVLog.log("RelayStore", "刷新了节点统计")
    }

    // MARK: - 从接口更新节点列表

    /// 使用节点接口返回的 JSON 更新节点列表：
    /// - 保留 auto 节点（id = -1）
    /// - 将所有 categories 里的 nodes 平铺成真实节点列表
    /// - 如果之前选中的节点不在新列表中，则重置为 auto
    func updateFromCourseCatalog(json: String) {
        guard let data = json.data(using: .utf8),
              let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let categories = root["categories"] as? [[String: Any]] else {
            NVLog.log("RelayStore", "节点列表 JSON 解析失败")
            return
        }

        var parsedRelays: [Relay] = []

        // 遍历所有 categories，将所有 nodes 平铺
        for category in categories {
            guard let nodes = category["nodes"] as? [[String: Any]] else { continue }
            for nodeDict in nodes {
                guard let id = nodeDict["id"] as? Int,
                      let name = nodeDict["name"] as? String,
                      let country = nodeDict["country"] as? String else {
                    continue
                }

                let countryCode = country.uppercased()
                let relay = Relay(
                    id: id,
                    name: name,
                    countryCode: countryCode,
                    latency: Int.random(in: 20...80),
                    status: Int.random(in: 0...2)
                )
                parsedRelays.append(relay)
            }
        }

        guard !parsedRelays.isEmpty else {
            NVLog.log("RelayStore", "节点列表解析结果为空，保留现有假节点")
            return
        }

        let previousSelectedId = selectedRelayId

        // 重建节点列表：auto 节点 + 接口返回节点
        var newRelays: [Relay] = [
            Relay(
                id: -1,
                name: "Auto",
                countryCode: "auto",
                latency: 0,
                status: 0
            )
        ]
        newRelays.append(contentsOf: parsedRelays)

        relays = newRelays
        NVLog.log("RelayStore", "已根据接口更新节点列表：\(relays.count) 个（含 auto）")

        // 如果之前选中的节点还存在，则保留选中；否则重置为 auto
        if relays.contains(where: { $0.id == previousSelectedId }) {
            selectedRelayId = previousSelectedId
        } else {
            selectedRelayId = -1
        }
    }
}
