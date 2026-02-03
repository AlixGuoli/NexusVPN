//
//  ReturnOverlayView.swift
//  NexusVPN
//
//  后台切回前台时的覆盖页（展示广告前的过渡）
//

import SwiftUI

struct ReturnOverlayView: View {
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

            VStack(spacing: 20) {
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                    .shadow(
                        color: Color(red: 0.25, green: 0.85, blue: 1.0).opacity(0.55),
                        radius: 20,
                        x: 0,
                        y: 10
                    )

                Text("FKey VPN")
                    .font(.system(size: 26, weight: .semibold, design: .rounded))
                    .foregroundColor(.white)
            }
        }
    }
}
