import SwiftUI

@main
struct TongtuPocApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @StateObject private var tunnel = TunnelManager()

    var body: some View {
        VStack(spacing: 24) {
            Text("通途 · 内核内存验证 PoC")
                .font(.headline)

            VStack(spacing: 8) {
                Text("隧道状态：\(tunnel.statusDescription)")
                Text("扩展内存：\(tunnel.memoryText)")
                    .font(.system(.body, design: .monospaced))
                Text("内核启动：\(tunnel.startResult)")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            HStack(spacing: 16) {
                Button("连接") { tunnel.connect() }
                    .buttonStyle(.borderedProminent)
                Button("断开") { tunnel.disconnect() }
                    .buttonStyle(.bordered)
            }

            if let err = tunnel.lastError {
                Text(err).foregroundColor(.red).font(.caption)
            }
        }
        .padding()
        .onAppear {
            tunnel.load()
            // 调试自动连接：仅当启动环境含 TONGTU_AUTOCONNECT 时触发（默认行为不变），
            // 用于模拟器/CI 无人值守验证隧道建立链路。
            if ProcessInfo.processInfo.environment["TONGTU_AUTOCONNECT"] == "1" {
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) { tunnel.connect() }
            }
        }
    }
}
