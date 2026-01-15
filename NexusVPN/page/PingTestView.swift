//
//  PingTestView.swift
//  NexusVPN
//
//  Ping测试工具
//

import SwiftUI

struct PingTestView: View {
    @EnvironmentObject var language: AppLanguageManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var host: String = "example.com"
    @State private var isTesting: Bool = false
    @State private var result: PingResult = PingResult()
    @State private var statusText: String = ""
    
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
                    
                    Text(language.text("toolbox.ping.title"))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 提示文字
                        Text(language.text("toolbox.ping.hint"))
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 20)
                        
                        // 输入框
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
                        
                        // 开始测试按钮
                        Button {
                            dismissKeyboard()
                            startPing()
                        } label: {
                            HStack {
                                if isTesting {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                Text(isTesting
                                     ? language.text("toolbox.ping.running")
                                     : language.text("toolbox.ping.start"))
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
                        .disabled(isTesting || host.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .padding(.horizontal, 20)
                        
                        // 状态文字
                        if !statusText.isEmpty {
                            Text(statusText)
                                .font(.system(size: 13))
                                .foregroundColor(.white.opacity(0.7))
                                .padding(.horizontal, 20)
                        }
                        
                        // 结果显示
                        if let latest = result.latest {
                            VStack(alignment: .leading, spacing: 12) {
                                StatLine(
                                    label: language.text("toolbox.ping.latest"),
                                    value: "\(Int(latest)) ms"
                                )
                                if let min = result.min {
                                    StatLine(
                                        label: language.text("toolbox.ping.min"),
                                        value: "\(Int(min)) ms"
                                    )
                                }
                                if let max = result.max {
                                    StatLine(
                                        label: language.text("toolbox.ping.max"),
                                        value: "\(Int(max)) ms"
                                    )
                                }
                                if let avg = result.avg {
                                    StatLine(
                                        label: language.text("toolbox.ping.avg"),
                                        value: "\(Int(avg)) ms"
                                    )
                                }
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
    
    private func startPing() {
        let target = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return }
        
        isTesting = true
        statusText = language.text("toolbox.ping.running")
        result = PingResult()
        
        // 模拟Ping测试（5次尝试）
        let attempts = 5
        var completed = 0
        
        // 模拟延迟：20-150ms之间
        for i in 0..<attempts {
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.3) {
                let simulatedLatency = Double.random(in: 20...150)
                result.samples.append(simulatedLatency)
                completed += 1
                
                if completed == attempts {
                    isTesting = false
                    statusText = language.text("toolbox.ping.done")
                }
            }
        }
    }
}

// MARK: - Ping结果结构

struct PingResult {
    var samples: [Double] = []
    
    var latest: Double? { samples.last }
    var min: Double? { samples.min() }
    var max: Double? { samples.max() }
    var avg: Double? {
        guard !samples.isEmpty else { return nil }
        return samples.reduce(0, +) / Double(samples.count)
    }
}

// MARK: - 统计行组件

struct StatLine: View {
    let label: String
    let value: String
    
    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 14))
                .foregroundColor(.white.opacity(0.7))
            
            Spacer()
            
            Text(value)
                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                .foregroundColor(.white)
        }
    }
}
