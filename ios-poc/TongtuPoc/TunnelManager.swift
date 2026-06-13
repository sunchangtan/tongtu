@preconcurrency import NetworkExtension
import Foundation
import Combine

/// 主 App 侧隧道管理：通过 NETunnelProviderManager 控制扩展（specs/apple-packet-tunnel）。
@MainActor
final class TunnelManager: ObservableObject {
    @Published var status: NEVPNStatus = .invalid
    @Published var memoryText: String = "—"
    @Published var startResult: String = "—"
    @Published var lastError: String?

    private var manager: NETunnelProviderManager?
    private var statusObserver: AnyCancellable?
    private var memoryTimer: Timer?

    /// 直连验证配置：全部流量走 DIRECT，不需订阅节点即可验证 TUN 数据通路
    /// （问题 7/9 修复后应能正常打开网页）。压测时换成含真实节点的配置。
    private let demoConfig = """
    log-level: warning
    mode: direct
    dns:
      enable: true
      enhanced-mode: fake-ip
      fake-ip-range: 198.18.0.1/16
      nameserver: [223.5.5.5, 119.29.29.29]
    """

    func load() {
        Task { @MainActor in
            let managers = try? await NETunnelProviderManager.loadAllFromPreferences()
            self.manager = managers?.first ?? self.makeManager()
            self.status = self.manager?.connection.status ?? .invalid
            self.observeStatus()
        }
    }

    private func makeManager() -> NETunnelProviderManager {
        let m = NETunnelProviderManager()
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = "com.dingqi.tongtu.poc.packet-tunnel"
        proto.serverAddress = "Tongtu PoC"
        m.protocolConfiguration = proto
        m.localizedDescription = "通途 PoC"
        return m
    }

    func connect() {
        SharedStore.configYAML = demoConfig
        guard let manager = manager else { return }
        Task { @MainActor in
            manager.isEnabled = true
            do {
                // 全程在 @MainActor 上 await，避免回调闭包捕获 non-Sendable 的 manager/self
                try await manager.saveToPreferences()
                try await manager.loadFromPreferences()
                try manager.connection.startVPNTunnel()
                startMemoryPolling()
            } catch {
                lastError = "连接失败: \(error.localizedDescription)"
            }
        }
    }

    func disconnect() {
        manager?.connection.stopVPNTunnel()
        memoryTimer?.invalidate()
    }

    private func observeStatus() {
        guard let connection = manager?.connection else { return }
        statusObserver = NotificationCenter.default
            .publisher(for: .NEVPNStatusDidChange, object: connection)
            .sink { [weak self] _ in
                Task { @MainActor in self?.status = connection.status }
            }
    }

    /// 轮询读取扩展写入的内存指标（新鲜度 ≤10s 判定）
    private func startMemoryPolling() {
        memoryTimer?.invalidate()
        memoryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            Task { @MainActor in
                self.startResult = SharedStore.lastStartResult.isEmpty ? "—" : SharedStore.lastStartResult
                let age = Date().timeIntervalSince1970 - SharedStore.memoryStatsAt
                guard age <= 10, let data = SharedStore.memoryStatsJSON.data(using: .utf8),
                      let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                      let total = obj["totalSys"] as? NSNumber else {
                    self.memoryText = "—（数据过期）"
                    return
                }
                let mib = Double(truncating: total) / 1024 / 1024
                self.memoryText = String(format: "%.1f MiB（采集于 %.0fs 前）", mib, age)
            }
        }
    }

    var statusDescription: String {
        switch status {
        case .connected: return "已连接"
        case .connecting: return "连接中…"
        case .disconnecting: return "断开中…"
        case .disconnected: return "未连接"
        case .reasserting: return "重连中…"
        case .invalid: return "未配置"
        @unknown default: return "未知"
        }
    }
}
