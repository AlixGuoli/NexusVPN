//
//  NexusVPNApp.swift
//  NexusVPN
//
//  Created by ersao on 2026/1/8.
//

import SwiftUI

@main
struct NexusVPNApp: App {
    @StateObject private var viewModel = HomeSessionViewModel()
    @State private var showSplash: Bool = true
    
    var body: some Scene {
        WindowGroup {
            ZStack {
                ContentView()
                    .environmentObject(viewModel)
                    .onAppear {
                        viewModel.initialize()
                    }
                
                // 启动页（只在首次进入期间覆盖）
                if showSplash {
                    SplashView {
                        showSplash = false
                    }
                    .environmentObject(viewModel)
                    .ignoresSafeArea()
                }
            }
        }
    }
}
