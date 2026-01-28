//
//  EducationRoutes.swift
//  NexusVPN
//
//  对外暴露的业务接口入口。
//  目前只实现 AppSettings 接口：/education/config/curriculum
//

import Foundation

enum EducationRoutes {
    
    /// 调用 AppSettings 接口：请求接口 → 保存结果 → 检查 Git 版本
    static func callAppSettings() async {
        NVLog.log("Wire", "[Wire] 准备请求 AppSettings /education/config/curriculum")
        
        guard let json = await WireClient.shared.send(.appSettings) else {
            NVLog.log("Wire", "[Wire] AppSettings 接口请求失败或无内容")
            return
        }
        
        // 保存到缓存
        AppSettingsCache.shared.keepCache(json)
        
        // 检查 Git 版本，如果接口版本大于本地版本则更新 Git
        if let remoteVersion = AppSettingsCache.shared.remoteGitVersion() {
            let localVersion = AppSettingsCache.shared.localGitVersion()
            NVLog.log("Wire", "[Wire] Git 版本比较：接口版本=\(remoteVersion)，本地版本=\(localVersion)")
            
            if remoteVersion > localVersion {
                NVLog.log("Wire", "[Wire] 接口版本大于本地版本，开始更新 Git 配置")
                let gitUpdateSuccess = await ConfigVault.shared.refreshConfigFromGit()
                if gitUpdateSuccess {
                    NVLog.log("Wire", "[Wire] ✅ Git 配置更新成功")
                    // 更新本地 Git 版本号
                    AppSettingsCache.shared.saveLocalGitVersion(remoteVersion)
                } else {
                    NVLog.log("Wire", "[Wire] ❌ Git 配置更新失败")
                }
            } else {
                NVLog.log("Wire", "[Wire] 接口版本不大于本地版本，跳过 Git 更新")
            }
        } else {
            NVLog.log("Wire", "[Wire] 接口未返回 git_version，跳过 Git 更新")
        }
    }

    /// 调用广告配置接口：请求接口 → 解析并扁平化保存
    static func callAdSettings() async {
        NVLog.log("Wire", "[Wire] 准备请求广告配置 /education/ads/scholarship")
        
        guard let json = await WireClient.shared.send(.adSettings) else {
            NVLog.log("Wire", "[Wire] 广告配置接口请求失败或无内容")
            return
        }
        
        // 打印完整响应内容
        NVLog.log("Wire", "[Wire] 广告配置接口响应内容：\(json)")
        
        // 保存到缓存（写入时解析并扁平化）
        AdSettingsCache.shared.keepCache(json)

        // 广告配置成功后，自动请求一次跳过按钮布局（与广告绑定的一体接口）
        await callAdSkipLayout()
    }

    /// 调用跳过按钮布局接口：获取 location/x/y 并保存
    static func callAdSkipLayout() async {
        NVLog.log("Wire", "[Wire] 准备请求广告跳过布局 /education/page/campus")

        // 原始接口：getpageconfig?pagename=ads_skip_yandex&pk=...
        // pk 已在通用参数里，这里只需要附加 pagename
        let extraParams = ["pagename": "ads_skip_yandex"]

        guard let json = await WireClient.shared.send(.pageLayout, extra: extraParams) else {
            NVLog.log("Wire", "[Wire] 广告跳过布局接口请求失败或无内容")
            return
        }

        NVLog.log("Wire", "[Wire] 广告跳过布局接口响应内容：\(json)")

        // 保存跳过按钮布局
        AdSettingsCache.shared.keepSkipLayout(json)
    }

    /// 调用节点列表接口：请求接口 → 更新节点列表
    static func callCourseCatalog() async {
        NVLog.log("Wire", "[Wire] 准备请求节点列表 /education/category/course")
        
        guard let json = await WireClient.shared.send(.courseCatalog) else {
            NVLog.log("Wire", "[Wire] 节点列表接口请求失败或无内容")
            return
        }
        
        NVLog.log("Wire", "[Wire] 节点列表接口完成")

        // 使用接口结果更新节点列表（包含 auto 节点，选中 ID 逻辑由 RelayStore 自己处理）
        RelayStore.shared.updateFromCourseCatalog(json: json)
    }
}

