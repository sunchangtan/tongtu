import Foundation
import Network
import MihomoCore

/// 监听网络路径变化，取真实出站接口名（WiFi 优先）喂给内核（问题 9）。
///
/// 背景：mihomo 的 auto-detect-interface 在 NE 沙盒用 socket 探测总命中蜂窝（pdp_ip0），
/// 即便在 WiFi 下也走蜂窝导致打不开网页。这里关闭内核侧自动探测，改由 NWPathMonitor
/// 取真实接口，WiFi 优先，经 MihomocoreUpdateDefaultInterface 注入内核出站绑定。
final class InterfaceMonitor {
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "tongtu.interface-monitor")

    func start() {
        monitor.pathUpdateHandler = { path in
            guard let name = Self.preferredInterfaceName(path) else { return }
            MihomocoreUpdateDefaultInterface(name)
        }
        monitor.start(queue: queue)
    }

    func stop() {
        monitor.cancel()
    }

    /// WiFi 优先，其次有线/其他，最后蜂窝；排除 utun 自身。
    private static func preferredInterfaceName(_ path: NWPath) -> String? {
        let usable = path.availableInterfaces.filter { !$0.name.hasPrefix("utun") }
        if let wifi = usable.first(where: { $0.type == .wifi }) { return wifi.name }
        if let wired = usable.first(where: { $0.type == .wiredEthernet }) { return wired.name }
        if let other = usable.first(where: { $0.type == .other }) { return other.name }
        if let cell = usable.first(where: { $0.type == .cellular }) { return cell.name }
        return usable.first?.name
    }
}
