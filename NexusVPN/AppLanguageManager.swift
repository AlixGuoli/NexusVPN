//
//  AppLanguageManager.swift
//  NexusVPN
//
//  简单的应用内多语言管理：支持多语言，运行时切换无需重启。
//

import Foundation
import SwiftUI
import Combine

/// 支持的应用语言
enum AppLanguage: String, CaseIterable, Identifiable {
    case system   = "system"
    case english  = "en"
    case russian  = "ru"
    case german   = "de"
    case french   = "fr"
    case spanish  = "es"
    case japanese = "ja"
    case korean   = "ko"
    
    var id: String { rawValue }
    
    /// 展示名称（不走多语言，直接用固定文案避免循环依赖）
    var displayName: String {
        switch self {
        case .system:
            return "跟随系统"
        case .english:
            return "English"
        case .russian:
            return "Русский"
        case .german:
            return "Deutsch"
        case .french:
            return "Français"
        case .spanish:
            return "Español"
        case .japanese:
            return "日本語"
        case .korean:
            return "한국어"
        }
    }
    
    /// 对应 .lproj 目录名
    var localeIdentifier: String {
        switch self {
        case .system:
            // 跟随系统时，检查系统语言是否在支持列表中
            let preferred = Locale.preferredLanguages.first ?? "en"
            let supportedLanguages = ["en", "ru", "de", "fr", "es", "ja", "ko"]
            
            // 检查完整匹配（如 "ru"）或前缀匹配（如 "ru-RU"）
            for lang in supportedLanguages {
                if preferred == lang || preferred.hasPrefix("\(lang)-") {
                    return lang
                }
            }
            // 不支持的语言回退到英文
            return "en"
        case .english:
            return "en"
        case .russian:
            return "ru"
        case .german:
            return "de"
        case .french:
            return "fr"
        case .spanish:
            return "es"
        case .japanese:
            return "ja"
        case .korean:
            return "ko"
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

