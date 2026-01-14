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
    @EnvironmentObject var language: AppLanguageManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text(language.text("disconnect.title"))
                .font(.headline)
            
            Text(language.text("disconnect.message"))
                .font(.body)
                .foregroundColor(.secondary)
            
            HStack(spacing: 15) {
                Button(language.text("common.cancel")) {
                    onCancel()
                    dismiss()
                }
                .foregroundColor(.secondary)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.gray.opacity(0.2))
                .cornerRadius(8)
                
                Button(language.text("disconnect.confirm")) {
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
