import Foundation
import Darwin

/// 在 NE 扩展进程内查找 NEPacketTunnelProvider 创建的 utun 控制 socket 的文件描述符（问题 6）。
///
/// 背景：iOS 26 上私有 KVC `packetFlow.value(forKeyPath: "socket.fileDescriptor")` 返回 nil，
/// 失效。sing-box/clashmi 的通行做法是扫描本进程已打开的 fd，对每个 fd 用
/// `getsockopt(SYSPROTO_CONTROL, UTUN_OPT_IFNAME)` 探测——只有 utun 控制 socket 才会成功
/// 返回形如 "utunN" 的接口名。因 iOS SDK 不公开 <net/if_utun.h>，常量在此硬编码。
enum TunFD {
    // 来自 <sys/sys_domain.h> / <net/if_utun.h>（iOS SDK 不公开，硬编码）；
    // 两常量沿用 C 头文件宏名，保留大写下划线对应原名，便于与系统文档对照。
    // swiftlint:disable:next identifier_name
    private static let SYSPROTO_CONTROL: Int32 = 2
    // swiftlint:disable:next identifier_name
    private static let UTUN_OPT_IFNAME: Int32 = 2

    /// 扫描并返回 utun 控制 socket 的 fd；找不到返回 -1。
    static func find() -> Int32 {
        var limit = rlimit()
        let maxFD: Int32 = getrlimit(RLIMIT_NOFILE, &limit) == 0 ? Int32(min(limit.rlim_cur, 1024)) : 1024

        var nameBuf = [CChar](repeating: 0, count: Int(IFNAMSIZ))
        for candidateFD in 0..<maxFD {
            var len = socklen_t(nameBuf.count)
            let optResult = getsockopt(candidateFD, SYSPROTO_CONTROL, UTUN_OPT_IFNAME, &nameBuf, &len)
            guard optResult == 0 else { continue }
            let name = String(cString: nameBuf)
            if name.hasPrefix("utun") {
                return candidateFD
            }
        }
        return -1
    }
}
