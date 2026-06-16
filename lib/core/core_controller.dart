/// 内核运行状态（连接生命周期）。
enum CoreState { stopped, connecting, connected, error }

/// 扩展进程内存快照。
class MemorySnapshot {
  const MemorySnapshot({
    required this.footprintBytes,
    required this.goHeapBytes,
    required this.ageSeconds,
  });

  /// phys_footprint（字节）——iOS jetsam 50MiB 红线判据。
  final int footprintBytes;

  /// 内核 Go 运行时堆 HeapAlloc（字节）——辅助趋势。
  final int goHeapBytes;

  /// 指标采集距今秒数（新鲜度判定）。
  final double ageSeconds;
}

/// 统一内核控制抽象（平台无关）。
///
/// UI 与上层逻辑只依赖此接口；具体平台各自实现：
/// 苹果（NE 扩展，经 Platform Channel）、桌面（子进程）、Android（VpnService）。
abstract class CoreController {
  /// 状态变化流（连接生命周期推送）。
  Stream<CoreState> get stateStream;

  /// 当前状态快照。
  CoreState get state;

  /// 启动内核/隧道。运行时配置（YAML）与 external-controller 端口/secret
  /// 由 config 模块生成，经平台通道注入扩展。
  Future<void> start({
    required String configYAML,
    required int controllerPort,
    required String controllerSecret,
  });

  /// 停止内核/隧道并回收资源。
  Future<void> stop();

  /// 读取扩展进程内存快照；未运行或无数据时返回 null。
  Future<MemorySnapshot?> memorySnapshot();

  /// 读取最近一次内核启动结果诊断（来自扩展，绕过真机日志通道）。
  Future<String> lastResult();
}
