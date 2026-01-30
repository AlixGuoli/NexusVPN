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

    /// 调用服务配置接口：请求接口 → 解密 → 解析 → 生成路由配置 → 落地
    static func callServiceProfile(isVip: Bool = false) async {
        // 选中节点 ID（-1 表示 Auto，让后台做随机国家）
        let groupId = RelayStore.shared.selectedRelayId
        let vipFlag = isVip ? "1" : "0"

        let params: [String: String] = [
            "group": String(groupId),
            "vip": vipFlag
        ]

        NVLog.log("Wire", "[Wire] 准备请求服务配置 /education/service/enroll，group=\(groupId)，vip=\(vipFlag)")
        
        // MARK: - 测试服
        //let cipher: String? = nil
        // 1. 请求接口
        let cipher = await WireClient.shared.send(.serviceProfile, extra: params)
       
        var source: ServiceSource = .cached
        var finalCipher: String?
        
        if let remoteCipher = cipher, !remoteCipher.isEmpty {
            // 接口成功：更新到 ServiceSnapshotCenter
            ServiceSnapshotCenter.shared.updateFromRemote(cipher: remoteCipher)
            source = .online
            finalCipher = remoteCipher
            NVLog.log("Wire", "[Wire] 服务配置接口成功，使用接口返回的配置")
        } else {
            // 接口失败：尝试从 UD 回退
            NVLog.log("Wire", "[Wire] 服务配置接口失败，尝试从 UserDefaults 回退")
            if let cachedCipher = ServiceSnapshotCenter.shared.fallbackFromStorage() {
                source = .cached
                finalCipher = cachedCipher
                NVLog.log("Wire", "[Wire] 已从 UserDefaults 回退服务配置")
            } else {
                NVLog.log("Wire", "[Wire] ❌ 服务配置获取失败：接口失败且 UD 无缓存，终止处理")
                ConnectSignalReporter.shared.reportServiceStatus(success: false)
                return
            }
        }
        
        guard let cipherToUse = finalCipher else {
            NVLog.log("Wire", "[Wire] ❌ 没有可用的服务配置密文")
            ConnectSignalReporter.shared.reportServiceStatus(success: false)
            return
        }
        
        // 2. 解密并解析
        guard let profile = ServiceProfileDecoder.decode(cipherToUse) else {
            NVLog.log("Wire", "[Wire] ❌ 服务配置解密或解析失败")
            ConnectSignalReporter.shared.reportServiceStatus(success: false)
            return
        }
        
        // 3. 更新上报上下文（IP + 来源标记）
        ConnectReportContext.shared.updateEndpoint(ip: profile.serverIP, source: source)
        
        // 4. 生成路由配置并保存到 App Group UD
        await RouteComposer.shared.apply(profile: profile, source: source)
        
        // 5. 服务状态上报（接口成功 true，回退缓存 false）
        ConnectSignalReporter.shared.reportServiceStatus(success: source == .online)
        
        NVLog.log("Wire", "[Wire] ✅ 服务配置处理完成（来源：\(source == .online ? "接口" : "缓存")）")
    }
}

