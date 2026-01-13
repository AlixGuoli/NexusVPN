//
//  ContentView.swift
//  NexusVPN
//
//  Created by ersao on 2026/1/8.
//

import SwiftUI

enum NavigationDestination: Hashable {
    case connecting
    case result(ConnectionResult)
}

struct ContentView: View {
    @EnvironmentObject var viewModel: HomeSessionViewModel
    @State private var navigationPath = NavigationPath()
    
    var body: some View {
        NavigationStack(path: $navigationPath) {
            // 主界面
            VStack(spacing: 30) {
                // 状态显示
                VStack(spacing: 10) {
                    Text("状态")
                        .font(.headline)
                    Text(statusText)
                        .font(.title2)
                        .foregroundColor(statusColor)
                }
                .padding()
                
                // 主按钮
                Button(action: {
                    viewModel.onPrimaryButtonTapped()
                }) {
                    Text(buttonText)
                        .font(.title)
                        .foregroundColor(.white)
                        .frame(width: 200, height: 60)
                        .background(buttonColor)
                        .cornerRadius(12)
                }
                .disabled(viewModel.stage == .connecting)
            }
            .padding()
            .navigationDestination(for: NavigationDestination.self) { destination in
                switch destination {
                case .connecting:
                    ConnectingView()
                case .result(let result):
                    ResultView(result: result) {
                        viewModel.clearResult()
                        navigationPath.removeLast()
                    }
                }
            }
            .sheet(isPresented: Binding(
                get: { viewModel.showDisconnectAlert },
                set: { _ in }
            )) {
                DisconnectConfirmView(
                    onConfirm: {
                        viewModel.confirmDisconnect()
                    },
                    onCancel: {
                        viewModel.cancelDisconnect()
                    }
                )
                .presentationDetents([.height(200)])
            }
            .onChange(of: viewModel.showConnectingView) { show in
                if show {
                    navigationPath.append(NavigationDestination.connecting)
                } else {
                    // 如果连接中页关闭，移除导航栈中的连接中页
                    if navigationPath.count > 0 {
                        navigationPath.removeLast()
                    }
                }
            }
            .onChange(of: viewModel.result) { result in
                if let result = result {
                    // 如果连接中页还在，先移除
                    if viewModel.showConnectingView {
                        navigationPath.removeLast()
                    }
                    navigationPath.append(NavigationDestination.result(result))
                }
            }
        }
    }
    
    // MARK: - 计算属性
    
    private var statusText: String {
        switch viewModel.stage {
        case .idle:
            return "未连接"
        case .connecting:
            return "连接中..."
        case .online:
            return "已连接"
        case .failed:
            return "连接失败"
        }
    }
    
    private var statusColor: Color {
        switch viewModel.stage {
        case .idle:
            return .gray
        case .connecting:
            return .orange
        case .online:
            return .green
        case .failed:
            return .red
        }
    }
    
    private var buttonText: String {
        switch viewModel.stage {
        case .idle, .failed:
            return "连接"
        case .connecting:
            return "连接中..."
        case .online:
            return "断开"
        }
    }
    
    private var buttonColor: Color {
        switch viewModel.stage {
        case .idle, .failed:
            return .blue
        case .connecting:
            return .gray
        case .online:
            return .red
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(HomeSessionViewModel())
}
