//
//  IPInfoView.swift
//  NexusVPN
//
//  IP信息查询工具
//

import SwiftUI
import Network

struct IPInfoView: View {
    @EnvironmentObject var language: AppLanguageManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var ipInfo: IPInfo?
    @State private var isLoading: Bool = false
    
    var body: some View {
        ZStack {
            // 背景
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.15, blue: 0.25),
                    Color(red: 0.02, green: 0.05, blue: 0.1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // 顶部栏（固定）
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                    
                    Text(language.text("toolbox.ipinfo.title"))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 提示文字
                        Text(language.text("toolbox.ipinfo.hint"))
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 20)
                        
                        // 刷新按钮
                        Button {
                            loadIPInfo()
                        } label: {
                            HStack {
                                if isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                } else {
                                    Image(systemName: "arrow.clockwise")
                                        .font(.system(size: 16))
                                }
                                Text(isLoading ? language.text("toolbox.ipinfo.loading") : language.text("toolbox.ipinfo.refresh"))
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.cyan.opacity(0.6),
                                                Color.blue.opacity(0.5)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                        }
                        .disabled(isLoading)
                        .padding(.horizontal, 20)
                        
                        // 信息显示
                        if let info = ipInfo {
                            VStack(spacing: 16) {
                                InfoRow(
                                    icon: "network",
                                    label: language.text("toolbox.ipinfo.ip"),
                                    value: info.ipAddress
                                )
                                
                                InfoRow(
                                    icon: "location.fill",
                                    label: language.text("toolbox.ipinfo.location"),
                                    value: info.location
                                )
                                
                                InfoRow(
                                    icon: "building.2.fill",
                                    label: language.text("toolbox.ipinfo.isp"),
                                    value: info.isp
                                )
                                
                                InfoRow(
                                    icon: "globe",
                                    label: language.text("toolbox.ipinfo.country"),
                                    value: info.country
                                )
                                
                                InfoRow(
                                    icon: "antenna.radiowaves.left.and.right",
                                    label: language.text("toolbox.ipinfo.networkType"),
                                    value: info.networkType
                                )
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.white.opacity(0.08))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                    )
                            )
                            .padding(.horizontal, 20)
                        } else if !isLoading {
                            // 空状态
                            VStack(spacing: 12) {
                                Image(systemName: "info.circle")
                                    .font(.system(size: 48))
                                    .foregroundColor(.white.opacity(0.3))
                                
                                Text(language.text("toolbox.ipinfo.placeholder"))
                                    .font(.system(size: 14))
                                    .foregroundColor(.white.opacity(0.5))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 60)
                            .padding(.horizontal, 20)
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 8)
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            if ipInfo == nil {
                loadIPInfo()
            }
        }
    }
    
    private func loadIPInfo() {
        isLoading = true
        
        // 模拟获取IP信息（延迟1-2秒）
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 1.0...2.0)) {
            // 模拟数据
            let countries = ["United States", "United Kingdom", "Germany", "Japan", "Canada", "Australia"]
            let cities = ["New York", "London", "Berlin", "Tokyo", "Toronto", "Sydney"]
            let isps = ["AT&T", "Verizon", "Comcast", "BT", "Deutsche Telekom", "NTT"]
            let networkTypes = ["WiFi", "Cellular", "Ethernet"]
            
            let randomIndex = Int.random(in: 0..<countries.count)
            let randomIP = "\(Int.random(in: 1...255)).\(Int.random(in: 1...255)).\(Int.random(in: 1...255)).\(Int.random(in: 1...255))"
            
            ipInfo = IPInfo(
                ipAddress: randomIP,
                location: cities[randomIndex],
                isp: isps[randomIndex],
                country: countries[randomIndex],
                networkType: networkTypes.randomElement() ?? "WiFi"
            )
            
            isLoading = false
        }
    }
}

// MARK: - IP信息结构

struct IPInfo {
    let ipAddress: String
    let location: String
    let isp: String
    let country: String
    let networkType: String
}

// MARK: - 信息行组件

struct InfoRow: View {
    let icon: String
    let label: String
    let value: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.cyan.opacity(0.8))
                .frame(width: 24)
            
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.trailing)
        }
    }
}
