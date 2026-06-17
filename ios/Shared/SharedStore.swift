import Foundation

/// App Group 共享存储：主 App 与扩展进程通过它交换配置与内存指标。
/// 设计见 specs/apple-packet-tunnel：内存指标新鲜度 ≤10s。
enum SharedStore {
    static let appGroup = "group.com.dingqi.tongtu"

    private static var defaults: UserDefaults? {
        UserDefaults(suiteName: appGroup)
    }

    // 主 App 写入、扩展读取：内核 YAML 配置
    static var configYAML: String {
        get { defaults?.string(forKey: "configYAML") ?? "" }
        set { defaults?.set(newValue, forKey: "configYAML") }
    }

    // 扩展写入、主 App 读取：内存指标 JSON（来自 MihomoCore.MemoryStats）
    static var memoryStatsJSON: String {
        get { defaults?.string(forKey: "memoryStatsJSON") ?? "" }
        set { defaults?.set(newValue, forKey: "memoryStatsJSON") }
    }

    // 扩展写入的指标采集时间戳（Unix 秒），用于判定新鲜度
    static var memoryStatsAt: TimeInterval {
        get { defaults?.double(forKey: "memoryStatsAt") ?? 0 }
        set { defaults?.set(newValue, forKey: "memoryStatsAt") }
    }

    // 扩展写入、主 App 读取：扩展进程 phys_footprint（字节）——iOS jetsam 50MiB 红线判据，
    // 区别于 memoryStatsJSON 的 Go 堆；满负载内存验证用它对照门槛。
    static var physFootprintBytes: Int {
        get { defaults?.integer(forKey: "physFootprintBytes") ?? 0 }
        set { defaults?.set(newValue, forKey: "physFootprintBytes") }
    }

    // 扩展写入、主 App 读取：内核启动结果诊断（绕开真机日志通道，直接在 UI 呈现）
    static var lastStartResult: String {
        get { defaults?.string(forKey: "lastStartResult") ?? "" }
        set { defaults?.set(newValue, forKey: "lastStartResult") }
    }
}
