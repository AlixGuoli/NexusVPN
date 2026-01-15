//
//  Base64ToolView.swift
//  NexusVPN
//
//  Base64编码/解码工具
//

import SwiftUI

struct Base64ToolView: View {
    @EnvironmentObject var language: AppLanguageManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var inputText: String = ""
    @State private var outputText: String = ""
    @State private var errorText: String = ""
    
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
            
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // 顶部栏
                    HStack(spacing: 12) {
                        Button {
                            dismiss()
                        } label: {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(width: 44, height: 44)
                        }
                        
                        Text(language.text("toolbox.base64.title"))
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    // 提示文字
                    Text(language.text("toolbox.base64.hint"))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 20)
                    
                    // 输入框
                    ZStack(alignment: .topLeading) {
                        if inputText.isEmpty {
                            Text("Enter text here...")
                                .foregroundColor(.white.opacity(0.3))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                        }
                        TextEditor(text: $inputText)
                            .scrollContentBackground(.hidden)
                            .foregroundColor(.white)
                            .frame(minHeight: 120)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.08))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    
                    // 操作按钮
                    HStack(spacing: 12) {
                        Button {
                            encode()
                        } label: {
                            Text(language.text("toolbox.base64.encode"))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
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
                        
                        Button {
                            decode()
                        } label: {
                            Text(language.text("toolbox.base64.decode"))
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color.white.opacity(0.12))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                                        )
                                )
                        }
                    }
                    .padding(.horizontal, 20)
                    
                    // 输出框
                    ZStack(alignment: .topLeading) {
                        if outputText.isEmpty {
                            Text("Result will appear here...")
                                .foregroundColor(.white.opacity(0.3))
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                        }
                        TextEditor(text: .constant(outputText))
                            .scrollContentBackground(.hidden)
                            .foregroundColor(.white.opacity(0.95))
                            .frame(minHeight: 120)
                            .disabled(true)
                    }
                    .padding(12)
                    .background(Color.white.opacity(0.06))
                    .cornerRadius(12)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
                    .padding(.horizontal, 20)
                    
                    // 错误提示
                    if !errorText.isEmpty {
                        Text(errorText)
                            .font(.system(size: 13))
                            .foregroundColor(.red.opacity(0.9))
                            .padding(.horizontal, 20)
                    }
                    
                    Spacer(minLength: 40)
                }
                .padding(.top, 8)
            }
        }
        .navigationBarBackButtonHidden(true)
    }
    
    private func encode() {
        errorText = ""
        let data = inputText.data(using: .utf8) ?? Data()
        outputText = data.base64EncodedString()
    }
    
    private func decode() {
        errorText = ""
        guard let data = Data(base64Encoded: inputText.trimmingCharacters(in: .whitespacesAndNewlines)) else {
            errorText = language.text("toolbox.base64.error")
            outputText = ""
            return
        }
        outputText = String(data: data, encoding: .utf8) ?? ""
    }
}
