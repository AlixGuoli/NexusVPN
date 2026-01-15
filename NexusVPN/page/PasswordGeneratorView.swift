//
//  PasswordGeneratorView.swift
//  NexusVPN
//
//  密码生成器工具
//

import SwiftUI

struct PasswordGeneratorView: View {
    @EnvironmentObject var language: AppLanguageManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var passwordLength: Double = 16
    @State private var includeNumbers: Bool = true
    @State private var includeSymbols: Bool = true
    @State private var generatedPassword: String = ""
    @State private var showCopied: Bool = false
    
    private let lowercaseLetters = "abcdefghijklmnopqrstuvwxyz"
    private let uppercaseLetters = "ABCDEFGHIJKLMNOPQRSTUVWXYZ"
    private let numbers = "0123456789"
    private let symbols = "!@#$%^&*()_+-=[]{}|;:,.<>?"
    
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
                        
                        Text(language.text("toolbox.password.title"))
                            .font(.system(size: 20, weight: .semibold))
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 8)
                    
                    // 提示文字
                    Text(language.text("toolbox.password.hint"))
                        .font(.system(size: 13))
                        .foregroundColor(.white.opacity(0.7))
                        .padding(.horizontal, 20)
                    
                    // 生成的密码显示
                    VStack(spacing: 12) {
                        if generatedPassword.isEmpty {
                            Text(language.text("toolbox.password.placeholder"))
                                .font(.system(size: 15, design: .monospaced))
                                .foregroundColor(.white.opacity(0.3))
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 20)
                        } else {
                            Text(generatedPassword)
                                .font(.system(size: 16, weight: .medium, design: .monospaced))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 20)
                        }
                        
                        // 复制按钮
                        Button {
                            copyPassword()
                        } label: {
                            HStack {
                                Image(systemName: showCopied ? "checkmark.circle.fill" : "doc.on.doc")
                                    .font(.system(size: 16))
                                Text(showCopied ? language.text("toolbox.password.copied") : language.text("toolbox.password.copy"))
                                    .font(.system(size: 15, weight: .semibold))
                            }
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
                        .disabled(generatedPassword.isEmpty)
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)
                    
                    // 长度滑块
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text(language.text("toolbox.password.length"))
                                .font(.system(size: 14, weight: .medium))
                                .foregroundColor(.white)
                            
                            Spacer()
                            
                            Text("\(Int(passwordLength))")
                                .font(.system(size: 14, weight: .semibold, design: .monospaced))
                                .foregroundColor(.cyan.opacity(0.9))
                        }
                        
                        Slider(value: $passwordLength, in: 8...32, step: 1)
                            .tint(.cyan.opacity(0.8))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)
                    
                    // 选项开关
                    VStack(spacing: 12) {
                        Toggle(isOn: $includeNumbers) {
                            Text(language.text("toolbox.password.includeNumbers"))
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                        }
                        .tint(.cyan.opacity(0.8))
                        
                        Toggle(isOn: $includeSymbols) {
                            Text(language.text("toolbox.password.includeSymbols"))
                                .font(.system(size: 15))
                                .foregroundColor(.white)
                        }
                        .tint(.cyan.opacity(0.8))
                    }
                    .padding(16)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.white.opacity(0.08))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                            )
                    )
                    .padding(.horizontal, 20)
                    
                    // 生成按钮
                    Button {
                        generatePassword()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.clockwise")
                                .font(.system(size: 16))
                            Text(language.text("toolbox.password.generate"))
                                .font(.system(size: 16, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
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
                    .padding(.horizontal, 20)
                    
                    Spacer(minLength: 40)
                }
                .padding(.top, 8)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            generatePassword()
        }
    }
    
    private func generatePassword() {
        var characterSet = lowercaseLetters + uppercaseLetters
        
        if includeNumbers {
            characterSet += numbers
        }
        if includeSymbols {
            characterSet += symbols
        }
        
        guard !characterSet.isEmpty else {
            generatedPassword = ""
            return
        }
        
        let length = Int(passwordLength)
        generatedPassword = String((0..<length).map { _ in
            characterSet.randomElement() ?? Character("")
        })
        
        showCopied = false
    }
    
    private func copyPassword() {
        UIPasteboard.general.string = generatedPassword
        showCopied = true
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            showCopied = false
        }
    }
}
