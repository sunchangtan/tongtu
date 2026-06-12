import NetworkExtension
import Foundation
import Combine

/// 主 App 侧隧道管理：通过 NETunnelProviderManager 控制扩展（specs/apple-packet-tunnel）。
@MainActor
final class TunnelManager: ObservableObject {
    @Published var status: NEVPNStatus = .invalid
    @Published var memoryText: String = "—"
    @Published var lastError: String?

    private var manager: NETunnelProviderManager?
    private var statusObserver: AnyCancellable?
    private var memoryTimer: Timer?

    /// 最小验证配置：只起内核与控制器，不接真实节点（P0 关注内核常驻内存）
    private let demoConfig = """
    log-level: warning
    mode: rule
    """

    func load() {
        NETunnelProviderManager.loadAllFromPreferences { [weak self] managers, _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.manager = managers?.first ?? self.makeManager()
                self.status = self.manager?.connection.status ?? .invalid
                self.observeStatus()
            }
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
        manager.isEnabled = true
        manager.saveToPreferences { [weak self] error in
            if let error = error {
                Task { @MainActor in self?.lastError = "保存配置失败: \(error.localizedDescription)" }
                return
            }
            manager.loadFromPreferences { _ in
                do {
                    try manager.connection.startVPNTunnel()
                    Task { @MainActor in self?.startMemoryPolling() }
                } catch {
                    Task { @MainActor in self?.lastError = "启动隧道失败: \(error.localizedDescription)" }
                }
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
