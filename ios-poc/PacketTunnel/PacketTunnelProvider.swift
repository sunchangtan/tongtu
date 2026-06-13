import NetworkExtension
import MihomoCore
import Foundation

/// Packet Tunnel Provider：扩展进程内加载 mihomo 内核（specs/apple-packet-tunnel）。
/// P0 验证目标：扩展常驻 <40MiB、峰值 <50MiB（jetsam 50MiB 限额）。
class PacketTunnelProvider: NEPacketTunnelProvider {

    private var memoryTimer: Timer?
    private let interfaceMonitor = InterfaceMonitor()

    override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
        // 1. 配置隧道虚拟接口（IPv4 + DNS，路由全量接管）
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "127.0.0.1")
        let ipv4 = NEIPv4Settings(addresses: ["198.18.0.1"], subnetMasks: ["255.255.0.0"])
        ipv4.includedRoutes = [NEIPv4Route.default()]
        settings.ipv4Settings = ipv4
        settings.mtu = 9000
        let dns = NEDNSSettings(servers: ["198.18.0.2"])
        dns.matchDomains = [""]   // 接管全部 DNS
        settings.dnsSettings = dns

        setTunnelNetworkSettings(settings) { [weak self] error in
            guard let self = self else { return }
            if let error = error {
                completionHandler(error)
                return
            }
            self.startCore(completionHandler: completionHandler)
        }
    }

    private func startCore(completionHandler: @escaping (Error?) -> Void) {
        // 2. 内核工作目录指向 App Group 容器
        guard let container = FileManager.default
            .containerURL(forSecurityApplicationGroupIdentifier: SharedStore.appGroup) else {
            completionHandler(NSError(domain: "Tongtu", code: -1,
                userInfo: [NSLocalizedDescriptionKey: "无法访问 App Group 容器"]))
            return
        }

        // 3. 取 TUN fd（D3，问题 6）：iOS 26 上 KVC socket.fileDescriptor 返回 nil，
        //    改用扫描 fd 找 utun 控制 socket。取不到则无法承载流量，直接失败（不再静默回退）。
        let tunFD = TunFD.find()
        guard tunFD > 0 else {
            SharedStore.lastStartResult = "❌ 未找到 utun fd（扫描失败）"
            completionHandler(NSError(domain: "Tongtu", code: -3,
                userInfo: [NSLocalizedDescriptionKey: "无法获取 tun 文件描述符"]))
            return
        }

        // 4. 覆写项：本地控制器 + 内存参数 + home-dir + tun-fd（D2/D3/D4）
        //    用固定回环端口（不能用端口 0：Start 的就绪轮询无法连接未确定的端口）
        let overrides: [String: Any] = [
            "external-controller": "127.0.0.1:9090",
            "secret": UUID().uuidString,
            "home-dir": container.path,
            "gomemlimit-mib": 30,
            "gogc": 30,
            "tun-fd": Int(tunFD),
        ]
        let overridesJSON = (try? JSONSerialization.data(withJSONObject: overrides))
            .flatMap { String(data: $0, encoding: .utf8) } ?? ""

        // 5. 启动出站接口监听（问题 9）：在内核启动前先注入一次当前接口，再持续随网络变化更新
        interfaceMonitor.start()

        // 6. 启动内核（粗粒度 JSON 协议；gomobile 导出名以 Go 包名 Mihomocore 为前缀，
        //    BOOL + NSError** 约定，未桥接为 throws，按 ObjC 指针形式调用）
        var startErr: NSError?
        let ok = MihomocoreStart(SharedStore.configYAML, overridesJSON, &startErr)
        if !ok {
            let msg = startErr?.localizedDescription ?? "内核启动失败"
            SharedStore.lastStartResult = "❌ 启动失败: \(msg)"
            completionHandler(startErr ?? NSError(domain: "Tongtu", code: -2,
                userInfo: [NSLocalizedDescriptionKey: msg]))
            return
        }
        SharedStore.lastStartResult = "✅ 内核已启动 tunFD=\(tunFD) 状态=\(MihomocoreState())"
        startMemoryReporting()
        completionHandler(nil)
    }

    override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
        memoryTimer?.invalidate()
        memoryTimer = nil
        interfaceMonitor.stop()
        var stopErr: NSError?
        MihomocoreStop(&stopErr)   // 资源回收：监听端口、TUN 栈
        completionHandler()
    }

    /// 周期性把内核内存指标写入 App Group（新鲜度 ≤10s）
    private func startMemoryReporting() {
        let timer = Timer(timeInterval: 5, repeats: true) { _ in
            SharedStore.memoryStatsJSON = MihomocoreMemoryStats()
            SharedStore.memoryStatsAt = Date().timeIntervalSince1970
        }
        RunLoop.main.add(timer, forMode: .common)
        timer.fire()
        memoryTimer = timer
    }
}
