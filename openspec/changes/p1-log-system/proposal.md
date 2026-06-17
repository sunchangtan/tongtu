## Why

真机数据通路调试（如订阅 proxy-provider 拉不到节点）高度依赖内核日志，但当前日志能力薄弱：不可复制、无时间戳、无法暂停、量大时卡顿；且**主 App 的 WebSocket `/logs` 在隧道 connected 之后才订阅，收不到内核启动最早一段（provider 下载正发生在此），也无任何持久化、无法跨会话回看**。需要一套完整的日志系统支撑诊断与长期运维。

## What Changes

- **内核侧落盘（关键）**：扩展进程内核启动即 `log.Subscribe` 订阅日志并写入 App Group 文件，捕获从最早（含 provider 下载）的全量日志，弥补主 App WS 订阅前的盲区。
- **文件滚动机制（硬约束）**：日志文件单文件限大小、保留有限个、总大小封顶（如 5MB），**绝不无限增长**。
- **主 App 实时日志**：每条加接收时间戳；可选中复制（`SelectionArea`）；暂停/继续（冻结当前画面便于查看复制）；节流批量刷新（高频不卡）；内存仅保留最近 N 条。
- **完整日志回看**：从落盘文件读取全量日志（含最早、跨会话），支持搜索。
- **导出分享**：把完整日志文件经系统分享导出（诊断 / 存档）。
- 新增依赖：`path_provider`（定位目录）、`share_plus`（分享导出）。

## Capabilities

### New Capabilities
- `runtime-logging`: 运行时日志的端到端能力——内核侧落盘（全量、从最早、滚动限容）、主 App 实时显示（时间戳 / 复制 / 暂停 / 节流）、完整回看（跨会话 / 搜索）、导出分享。

### Modified Capabilities
<!-- 无：日志为新增独立能力。内核落盘的实现改动（mihomocore / 扩展）在 design.md 与 tasks.md 体现，不改变 core-bridge / apple-packet-tunnel 既有需求的对外契约。 -->

## Impact

- **Go `core-bridge/mihomocore`**：Start 流程新增 `log.Subscribe` 落盘协程 + 文件滚动；经 overrides 接收日志文件路径。
- **Swift 扩展**：经 `providerConfiguration` 把日志文件路径（App Group 容器内）传给内核。
- **Dart**：`clash_api` 的 `LogEntry` 加接收时间戳；新增 `LogStore`（读文件 / 滚动 / 导出 / 清空）；`monitor_page` 实时日志改造；新增完整日志回看页。
- **依赖**：`pubspec.yaml` 增加 `path_provider`、`share_plus`。
- **specs**：新增 `runtime-logging`。
- **iOS NE 内存红线**：落盘协程在扩展进程运行（常驻 <40MiB / 峰值 <50MiB 红线内），需评估缓冲与文件句柄开销（预计极小），design.md 中说明并要求真机复测。
