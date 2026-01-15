//
//  PortCheckView.swift
//  NexusVPN
//
//  端口检测工具
//

import SwiftUI

struct PortCheckView: View {
    @EnvironmentObject var language: AppLanguageManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var host: String = "example.com"
    @State private var portText: String = "443"
    @State private var isChecking: Bool = false
    @State private var resultText: String = ""
    
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
                    
                    Text(language.text("toolbox.port.title"))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 提示文字
                        Text(language.text("toolbox.port.hint"))
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 20)
                        
                        // 主机输入框
                        TextField("example.com", text: $host)
                            .textInputAutocapitalization(.never)
                            .disableAutocorrection(true)
                            .padding(14)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                            .padding(.horizontal, 20)
                        
                        // 端口输入框
                        TextField("443", text: $portText)
                            .keyboardType(.numberPad)
                            .padding(14)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                            .foregroundColor(.white)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                            .padding(.horizontal, 20)
                        
                        // 开始检测按钮
                        Button {
                            dismissKeyboard()
                            checkPort()
                        } label: {
                            HStack {
                                if isChecking {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text(isChecking
                                     ? language.text("toolbox.port.running")
                                     : language.text("toolbox.port.start"))
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
                        .disabled(isChecking || !canStart)
                        .padding(.horizontal, 20)
                        
                        // 结果显示
                        if !resultText.isEmpty {
                            Text(resultText)
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(resultText.contains("✅") ? .green.opacity(0.9) : .red.opacity(0.9))
                                .padding(16)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(Color.white.opacity(0.08))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12)
                                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                        )
                                )
                                .padding(.horizontal, 20)
                        }
                        
                        Spacer(minLength: 40)
                    }
                    .padding(.top, 8)
                    .onTapGesture {
                        dismissKeyboard()
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
    }
    
    /// 收起键盘
    private func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
    
    private var canStart: Bool {
        guard !host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let port = UInt16(portText), port > 0 else {
            return false
        }
        return true
    }
    
    private func checkPort() {
        guard let portValue = UInt16(portText), portValue > 0 else { return }
        
        isChecking = true
        resultText = ""
        
        // 模拟端口检测（延迟1-2秒后返回结果）
        // 常见端口（80, 443, 22, 21, 25, 53）有较高概率开放
        let commonPorts: Set<UInt16> = [80, 443, 22, 21, 25, 53]
        let isLikelyOpen = commonPorts.contains(portValue) || Bool.random()
        
        DispatchQueue.main.asyncAfter(deadline: .now() + Double.random(in: 1.0...2.0)) {
            isChecking = false
            if isLikelyOpen {
                resultText = language.text("toolbox.port.open")
            } else {
                resultText = language.text("toolbox.port.closed")
            }
        }
    }
}
