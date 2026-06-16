import Foundation

/// 读取本进程 phys_footprint——iOS jetsam 判定扩展是否超 50MiB 的物理内存足迹，
/// 等同 Xcode Instruments / Activity Monitor 的 Footprint，区别于 mihomo 内核的 Go 运行时堆。
/// 用于满负载内存验证时在 app 界面直接呈现红线指标（标准 task_info(TASK_VM_INFO) 取法）。
enum ProcessMemory {
    /// 返回当前进程 phys_footprint（字节）；读取失败返回 0。
    static func physFootprintBytes() -> Int {
        var info = task_vm_info_data_t()
        var count = mach_msg_type_number_t(MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size)
        let result = withUnsafeMutablePointer(to: &info) { pointer in
            pointer.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { rebound in
                task_info(mach_task_self_, task_flavor_t(TASK_VM_INFO), rebound, &count)
            }
        }
        guard result == KERN_SUCCESS else { return 0 }
        return Int(info.phys_footprint)
    }
}
