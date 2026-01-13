//
//  DisconnectConfirmView.swift
//  NexusVPN
//
//  断开确认弹窗
//

import SwiftUI

struct DisconnectConfirmView: View {
    let onConfirm: () -> Void
    let onCancel: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 20) {
            Text("确认断开")
                .font(.headline)
            
            Text("确定要断开 VPN 连接吗？")
                .font(.body)
                .foregroundColor(.secondary)
            
            HStack(spacing: 15) {
                Button("取消") {
                    onCancel()
                    dismiss()
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                
                Button("断开") {
                    onConfirm()
                    dismiss()
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.red)
                .cornerRadius(8)
            }
        }
        .padding()
    }
}

#Preview {
    DisconnectConfirmView(
        onConfirm: {},
        onCancel: {}
    )
}
