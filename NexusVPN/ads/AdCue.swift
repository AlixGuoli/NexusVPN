//
//  AdCue.swift
//  NexusVPN
//
//  广告触发时机枚举（用于打点与加载策略，字符串值仅用于日志和上报）
//

import Foundation

/// 广告触发时机（与旧项目的概念类似，但命名更新为 AdCue）
enum AdCue: String {
    /// App 冷启动启动页完成
    case launch = "launchApp"
    /// 前后台切换回前台
    case foreground = "foreground"
    /// 用户主动发起连接
    case connect = "connect"
    /// 用户主动断开连接
    case disconnect = "disconnect"
    /// 媒体关闭后（用于预加载下一支）
    case closeAd = "closead"
    /// 其他场景入口（结果页、工具箱等）
    case scene = "scene"
}

