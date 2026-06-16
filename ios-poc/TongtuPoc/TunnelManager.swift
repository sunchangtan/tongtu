@preconcurrency import NetworkExtension
import Foundation
import Combine

/// 主 App 侧隧道管理：通过 NETunnelProviderManager 控制扩展（specs/apple-packet-tunnel）。
@MainActor
final class TunnelManager: ObservableObject {
    @Published var status: NEVPNStatus = .invalid
    @Published var footprintText: String = "—"   // phys_footprint：jetsam 50MiB 红线判据
    @Published var memoryText: String = "—"        // 内核 Go 堆 HeapAlloc：辅助趋势
    @Published var startResult: String = "—"
    @Published var lastError: String?

    private var manager: NETunnelProviderManager?
    private var statusObserver: AnyCancellable?
    private var memoryTimer: Timer?

    /// 直连验证配置：全部流量走 DIRECT，不需订阅节点即可验证 TUN 数据通路
    /// （问题 7/9 修复后应能正常打开网页）。设置环境变量 TONGTU_STRESS=1 时改用
    /// 打包进 App 的 stress-config.yaml（60 节点压测配置），见 resolveConfig()。
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
        let newManager = NETunnelProviderManager()
        let proto = NETunnelProviderProtocol()
        proto.providerBundleIdentifier = "com.dingqi.tongtu.poc.packet-tunnel"
        proto.serverAddress = "Tongtu PoC"
        newManager.protocolConfiguration = proto
        newManager.localizedDescription = "通途 PoC"
        return newManager
    }

    func connect() {
        SharedStore.configYAML = resolveConfig()
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

    /// 解析本次连接使用的内核配置：设置环境变量 TONGTU_STRESS=1 时，加载打包进 App 的
    /// 压测大配置 stress-config.yaml（任务 5.2/5.3/4.6）；否则用内联直连小配置，
    /// 保持原 4.3 数据通路验证行为不变。读不到资源时安全回退到 demoConfig。
    private func resolveConfig() -> String {
        guard ProcessInfo.processInfo.environment["TONGTU_STRESS"] == "1",
              let url = Bundle.main.url(forResource: "stress-config", withExtension: "yaml"),
              let yaml = try? String(contentsOf: url, encoding: .utf8) else {
            return demoConfig
        }
        return yaml
    }

    private func observeStatus() {
        guard let connection = manager?.connection else { return }
        statusObserver = NotificationCenter.default
            .publisher(for: .NEVPNStatusDidChange, object: connection)
            .sink { [weak self] _ in
                Task { @MainActor in self?.status = connection.status }
            }
    }

    /// 轮询读取扩展写入的内存指标（新鲜度 ≤10s 判定）：
    /// footprintText = phys_footprint（jetsam 红线判据），memoryText = 内核 Go 堆（辅助趋势）
    private func startMemoryPolling() {
        memoryTimer?.invalidate()
        memoryTimer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { _ in
            Task { @MainActor in
                self.startResult = SharedStore.lastStartResult.isEmpty ? "—" : SharedStore.lastStartResult
                let age = Date().timeIntervalSince1970 - SharedStore.memoryStatsAt
                guard age <= 10 else {
                    self.footprintText = "—（数据过期）"
                    self.memoryText = "—（数据过期）"
                    return
                }
                // phys_footprint：50MiB jetsam 红线判据
                let footprintMiB = Double(SharedStore.physFootprintBytes) / 1024 / 1024
                self.footprintText = footprintMiB > 0
                    ? String(format: "%.1f MiB（红线 50 / 常驻 40）", footprintMiB)
                    : "—"
                // 内核 Go 堆 HeapAlloc（实际活跃堆，区别于 totalSys 的虚拟保留）：辅助趋势
                if let data = SharedStore.memoryStatsJSON.data(using: .utf8),
                   let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let heap = obj["heapAlloc"] as? NSNumber {
                    let mib = Double(truncating: heap) / 1024 / 1024
                    self.memoryText = String(format: "%.1f MiB（采集 %.0fs 前）", mib, age)
                } else {
                    self.memoryText = "—"
                }
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
