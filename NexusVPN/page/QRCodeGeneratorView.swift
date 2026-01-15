//
//  QRCodeGeneratorView.swift
//  NexusVPN
//
//  二维码生成器工具
//

import SwiftUI
#if canImport(UIKit)
import UIKit
#endif
import CoreImage.CIFilterBuiltins

struct QRCodeGeneratorView: View {
    @EnvironmentObject var language: AppLanguageManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var inputText: String = ""
    @State private var qrCodeImage: UIImage?
    @State private var showShareSheet: Bool = false
    
    private let context = CIContext()
    private let filter = CIFilter.qrCodeGenerator()
    
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
                // 顶部栏（固定，不随内容滚动）
                HStack(spacing: 12) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundColor(.white)
                            .frame(width: 44, height: 44)
                    }
                    
                    Text(language.text("toolbox.qrcode.title"))
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundColor(.white)
                    
                    Spacer()
                }
                .padding(.horizontal, 20)
                .padding(.top, 8)
                
                ScrollView {
                    VStack(alignment: .leading, spacing: 20) {
                        // 提示文字
                        Text(language.text("toolbox.qrcode.hint"))
                            .font(.system(size: 13))
                            .foregroundColor(.white.opacity(0.7))
                            .padding(.horizontal, 20)
                        
                        // 输入框
                        ZStack(alignment: .topLeading) {
                            if inputText.isEmpty {
                                Text("Enter text or URL here...")
                                    .foregroundColor(.white.opacity(0.3))
                                    .padding(.horizontal, 4)
                                    .padding(.vertical, 8)
                            }
                            TextEditor(text: $inputText)
                                .scrollContentBackground(.hidden)
                                .foregroundColor(.white)
                                .frame(minHeight: 100)
                        }
                        .padding(12)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color.white.opacity(0.12), lineWidth: 1)
                        )
                        .padding(.horizontal, 20)
                        
                        // 生成按钮（点击后才生成二维码，并收起键盘）
                        Button {
                            dismissKeyboard()
                            generateQRCode()
                        } label: {
                            Text(language.text("toolbox.qrcode.generate"))
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 12)
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
                        .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        .padding(.horizontal, 20)
                        
                        // 二维码显示区域
                        if let qrImage = qrCodeImage {
                            VStack(spacing: 16) {
                                Image(uiImage: qrImage)
                                    .interpolation(.none)
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 250, height: 250)
                                    .background(Color.white)
                                    .cornerRadius(12)
                                    .padding(20)
                                    .background(
                                        RoundedRectangle(cornerRadius: 16)
                                            .fill(Color.white.opacity(0.08))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 16)
                                                    .stroke(Color.white.opacity(0.12), lineWidth: 1)
                                            )
                                    )
                                
                                // 操作按钮（仅分享，避免相册权限问题）
                                HStack(spacing: 12) {
                                    Button {
                                        showShareSheet = true
                                    } label: {
                                        HStack {
                                            Image(systemName: "square.and.arrow.up")
                                                .font(.system(size: 16))
                                            Text(language.text("toolbox.qrcode.share"))
                                                .font(.system(size: 15, weight: .semibold))
                                        }
                                        .foregroundColor(.white)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
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
                                }
                            }
                            .padding(.horizontal, 20)
                        } else {
                            // 空状态提示
                            VStack(spacing: 12) {
                                Image(systemName: "qrcode")
                                    .font(.system(size: 48))
                                    .foregroundColor(.white.opacity(0.3))
                                
                                Text(language.text("toolbox.qrcode.placeholder"))
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
                    .onTapGesture {
                        dismissKeyboard()
                    }
                }
            }
        }
        .navigationBarBackButtonHidden(true)
        .sheet(isPresented: $showShareSheet) {
            if let qrImage = qrCodeImage {
                ShareSheet(activityItems: [qrImage])
            }
        }
    }
    
    /// 收起键盘
    private func dismissKeyboard() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }
    
    private func generateQRCode() {
        guard !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            qrCodeImage = nil
            return
        }
        
        let data = Data(inputText.utf8)
        filter.message = data
        
        if let outputImage = filter.outputImage {
            let transform = CGAffineTransform(scaleX: 10, y: 10)
            let scaledImage = outputImage.transformed(by: transform)
            
            if let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) {
                qrCodeImage = UIImage(cgImage: cgImage)
            }
        }
    }
}

// MARK: - Share Sheet

struct ShareSheet: UIViewControllerRepresentable {
    let activityItems: [Any]
    
    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
        return controller
    }
    
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
