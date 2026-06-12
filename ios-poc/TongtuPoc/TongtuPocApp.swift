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
        .onAppear { tunnel.load() }
    }
}
