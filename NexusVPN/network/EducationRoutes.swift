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
}

