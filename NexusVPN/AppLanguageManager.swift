//
//  AppLanguageManager.swift
//  NexusVPN
//
//  简单的应用内多语言管理：支持英文 / 简体中文，运行时切换无需重启。
//

import Foundation
import SwiftUI
import Combine

/// 支持的应用语言
enum AppLanguage: String, CaseIterable, Identifiable {
    case system   = "system"
    case english  = "en"
    case chineseSimplified = "zh-Hans"
    
    var id: String { rawValue }
    
    /// 展示名称（不走多语言，直接用固定文案避免循环依赖）
    var displayName: String {
        switch self {
        case .system:
            return "跟随系统"
        case .english:
            return "English"
        case .chineseSimplified:
            return "简体中文"
        }
    }
    
    /// 对应 .lproj 目录名
    var localeIdentifier: String {
        switch self {
        case .system:
            // 跟随系统时，只在「中英」之间做一次归一化，避免出现 zh-Hans-CN 之类找不到目录的情况
            let preferred = Locale.preferredLanguages.first ?? "en"
            if preferred.lowercased().hasPrefix("zh") {
                return "zh-Hans"
            } else {
                return "en"
            }
        case .english:
            return "en"
        case .chineseSimplified:
            return "zh-Hans"
        }
    }
}

/// 负责在运行时切换本地化 Bundle，并通过 @Published 触发 UI 刷新
final class AppLanguageManager: ObservableObject {
    static let shared = AppLanguageManager()
    
    private let storageKey = "NexusVPN.AppLanguage"
    
    /// 当前选择的语言
    @Published private(set) var current: AppLanguage {
        didSet {
            persistLanguage()
            updateBundle()
        }
    }
    
    /// 当前使用的本地化 Bundle
    @Published private(set) var bundle: Bundle = .main
    
    init() {
        if let raw = UserDefaults.standard.string(forKey: storageKey),
           let saved = AppLanguage(rawValue: raw) {
            current = saved
        } else {
            current = .system
        }
        updateBundle()
    }
    
    /// 便捷构造，供预览使用
    convenience init(previewLanguage: AppLanguage) {
        self.init()
        current = previewLanguage
        updateBundle()
    }
    
    /// 切换语言
    func setLanguage(_ language: AppLanguage) {
        guard language != current else { return }
        current = language
    }
    
    /// 获取指定 key 的本地化文案
    /// 如果当前 bundle 中找不到，将回退到主 bundle；仍然不行才返回 key 本身，避免界面直接展示 raw key。
    func text(_ key: String) -> String {
        // 使用 NSLocalizedString，和旧项目保持一致
        // 如果在指定 bundle 找不到，会自动回退到主 bundle
        let result = NSLocalizedString(key, tableName: nil, bundle: bundle, value: key, comment: "")
        // 如果返回的还是 key 本身，说明两个 bundle 都找不到，尝试强制用英文 bundle
        if result == key, bundle != Bundle.main {
            if let enPath = Bundle.main.path(forResource: "en", ofType: "lproj"),
               let enBundle = Bundle(path: enPath) {
                let enResult = NSLocalizedString(key, tableName: nil, bundle: enBundle, value: key, comment: "")
                if enResult != key { return enResult }
            }
        }
        return result
    }
    
    // MARK: - Private
    
    private func persistLanguage() {
        UserDefaults.standard.set(current.rawValue, forKey: storageKey)
    }
    
    private func updateBundle() {
        let identifier = current.localeIdentifier
        
        // 当前选中的语言
        if let path = Bundle.main.path(forResource: identifier, ofType: "lproj"),
           let langBundle = Bundle(path: path) {
            bundle = langBundle
            return
        }
        
        // 找不到就优先强制回退到英文资源
        if let enPath = Bundle.main.path(forResource: "en", ofType: "lproj"),
           let enBundle = Bundle(path: enPath) {
            bundle = enBundle
            return
        }
        
        // 最后再退回主 bundle（通常也会是英文）
        bundle = .main
    }
}

