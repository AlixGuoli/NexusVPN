//
//  ResultView.swift
//  NexusVPN
//
//  结果页面
//

import SwiftUI

struct ResultView: View {
    let result: ConnectionResult
    let onDismiss: () -> Void
    @EnvironmentObject var language: AppLanguageManager
    
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: iconName)
                .font(.system(size: 60))
                .foregroundColor(iconColor)
            
            Text(resultText)
                .font(.title)
            
            Button(language.text("common.ok")) {
                onDismiss()
            }
            .foregroundColor(.white)
            .padding(.horizontal, 30)
            .padding(.vertical, 10)
            .background(iconColor)
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
    
    private var iconName: String {
        switch result {
        case .connectSuccess, .disconnectSuccess:
            return "checkmark.circle.fill"
        case .connectFailure:
            return "xmark.circle.fill"
        }
    }
    
    private var iconColor: Color {
        switch result {
        case .connectSuccess:
            return .green
        case .connectFailure:
            return .red
        case .disconnectSuccess:
            return .blue
        }
    }
    
    private var resultText: String {
        switch result {
        case .connectSuccess:
            return language.text("result.connectSuccess")
        case .connectFailure:
            return language.text("result.connectFailure")
        case .disconnectSuccess:
            return language.text("result.disconnectSuccess")
        }
    }
}

#Preview {
    NavigationStack {
        ResultView(result: .connectSuccess) {}
    }
}
