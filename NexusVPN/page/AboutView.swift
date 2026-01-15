//
//  AboutView.swift
//  NexusVPN
//
//  关于我们页面：展示 Logo、版本号、简介和官网链接
//

import SwiftUI

struct AboutView: View {
    @EnvironmentObject var language: AppLanguageManager
    @Environment(\.dismiss) private var dismiss
    
    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        return build.isEmpty ? version : "\(version) (\(build))"
    }
    
    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.05, green: 0.15, blue: 0.25),
                    Color(red: 0.02, green: 0.05, blue: 0.10)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            
            VStack(spacing: 24) {
                // 顶部栏
                HStack {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    
                    Spacer()
                    
                    Text(language.text("about.title"))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: "chevron.left")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(.clear)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                
                ScrollView {
                    VStack(spacing: 20) {
                        // 顶部卡片：Logo + 名称 + 版本
                        VStack(spacing: 14) {
                            Image("logo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 72, height: 72)
                                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                                .shadow(color: Color.cyan.opacity(0.5), radius: 16, x: 0, y: 8)
                            
                            Text(language.text("app.title"))
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundColor(.white)
                            
                            Text("\(language.text("about.version")) \(appVersion)")
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.7))
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 28)
                        .background(
                            RoundedRectangle(cornerRadius: 20, style: .continuous)
                                .fill(Color.white.opacity(0.06))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                                        .stroke(Color.white.opacity(0.14), lineWidth: 1)
                                )
                        )
                        .padding(.horizontal, 20)
                        
                        // 简介文案
                        VStack(alignment: .leading, spacing: 10) {
                            Text(language.text("about.description.title"))
                                .font(.system(size: 15, weight: .medium))
                                .foregroundColor(.white)
                            
                            Text(language.text("about.description.body"))
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.75))
                                .lineSpacing(4)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(18)
                        .background(
                            RoundedRectangle(cornerRadius: 18, style: .continuous)
                                .fill(Color.white.opacity(0.05))
                        )
                        .padding(.horizontal, 20)
                        
                        // 官网按钮
                        Button {
                            UIApplication.shared.open(AppLinks.officialWebsite)
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "safari")
                                    .font(.system(size: 15, weight: .medium))
                                Text(language.text("about.website.button"))
                                    .font(.system(size: 15, weight: .semibold))
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(
                                        LinearGradient(
                                            colors: [
                                                Color.cyan.opacity(0.7),
                                                Color.blue.opacity(0.6)
                                            ],
                                            startPoint: .leading,
                                            endPoint: .trailing
                                        )
                                    )
                            )
                        }
                        .padding(.horizontal, 20)
                        
                        Spacer(minLength: 32)
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .toolbar(.hidden, for: .navigationBar)
    }
}

