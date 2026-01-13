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
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(viewModel)
                .onAppear {
                    viewModel.initialize()
                }
        }
    }
}
