## Context

日志系统跨三层：Go 内核（`core-bridge/mihomocore`，运行在 iOS NE 扩展进程）、Swift 扩展（PacketTunnel）、Dart 主 App。关键约束：
- **iOS NE 内存红线**：扩展常驻 <40MiB、峰值 <50MiB（jetsam），落盘协程开销必须可忽略。
- **不 fork mihomo**：内核落盘只能用官方 API（`log` 包的订阅能力，与 `/logs` 路由同源）。
- **盲区**：主 App 的 WS `/logs` 在隧道 `connected` 后才订阅，收不到内核启动最早段（含 proxy-provider 下载）。
- **硬约束**：日志文件滚动限容，绝不无限增长。

参照 clashmi 等成熟 iOS mihomo 客户端的工程经验，但不复制代码。

## Goals / Non-Goals

**Goals:**
- 内核侧从最早全量落盘到 App Group 文件（含 provider 下载日志）。
- 文件滚动 + 总量封顶，重启不累积。
- 主 App 实时显示（时间戳 / 复制 / 暂停 / 节流 / 内存上限）。
- 完整回看（全量 / 跨会话 / 搜索）+ 导出分享。

**Non-Goals:**
- 日志上传远端 / 云端聚合。
- 日志结构化分析、告警。
- 修改 mihomo 日志格式或级别语义。

## Decisions

### D1：内核落盘用 mihomo `log` 订阅（不 fork）
core.go `Start` 流程中订阅内核日志（与 `hub/route` 的 `/logs` 同源 API），启一个 goroutine 把日志写入文件。订阅在 `applyConfig` 之前建立，确保捕获 provider 下载等最早日志。
- **备选**：① 重定向 stdout → gomobile 环境 stdout 不可见，否决；② fork mihomo 内置落盘 → 违反「不 fork」红线，否决。

### D2：文件滚动用 lumberjack
日志写入 `lumberjack.Logger`（`gopkg.in/natefinch/lumberjack`）作为 `io.Writer`，配置 `MaxSize=1MiB`、`MaxBackups=4`、`Compress=false`，使总量封顶约 5MiB、滚动自动、重启续写不累积。
- **理由**：成熟库，size/backups 直接落地「滚动限容」硬约束，避免自实现滚动的边界 bug。
- **备选**：自实现 rotate（几十行）→ 省一个 Go 依赖但需充分测边界；lumberjack 更稳，且是普通 Go 依赖（非 mihomo fork），不踩红线。

### D3：日志目录由扩展自身从 App Group 容器算出（实施简化）
扩展进程用 `containerURL(appGroup)` 直接得到 App Group 容器路径，拼出 `logs/` 子目录，经 overrides `log-dir` 传给内核 `Start`。主 App 读取时也用同一 App Group 容器（经 channel `logDir` 由原生返回绝对路径）。
- **理由**：扩展与主 App 共享同一 App Group 容器、路径相同，扩展自身即可定位日志目录，无需经 `providerConfiguration` 从主 App 传，更简单可靠。
- **实施修正**：原计划经 `providerConfiguration` 传路径，实施 2.1 时发现冗余，简化为扩展自算。

### D4：主 App 经 channel 取日志目录路径后用 dart:io 读
新增 channel method（如 `logDir`），原生返回 App Group 容器日志目录的绝对路径；Dart 侧 `LogStore` 用 `dart:io` 直接读取文件（回看）、定位文件（导出）。
- **理由**：主 App 自身 `path_provider` 拿不到 App Group 容器路径，必须由原生 `containerURL` 提供。读用 dart:io 比 channel 传大段内容高效。

### D5：实时显示——时间戳 + 暂停 + 节流
- 时间戳：`LogEntry` 加 `time`（接收时刻 `DateTime.now()`，mihomo `/logs` 不带时间）。
- 复制：日志区 `SelectionArea` 包裹。
- 暂停：`_paused` + 冻结快照 `_frozenLogs`；暂停期间日志仍入内存缓冲不丢，继续后展示。
- 节流：WS 日志先入缓冲，`Timer` 每 ~300ms 批量 `setState` 一次，避免逐条重绘。
- 内存上限：内存仅留最近 N=1000 条，超出丢最旧（完整历史在落盘文件）。

### D6：回看页 + 导出
- 回看：新增 `LogViewerPage`，`LogStore` 读全量文件（含 backups，按时间合并），分页渲染 + 关键词过滤。
- 导出：`share_plus` 调系统分享，分享日志文件（或合并后的临时文件）。

## Risks / Trade-offs

- **内存红线** → 落盘缓冲用 lumberjack 默认（无大缓冲）+ 订阅 channel 有界；预计增量 <1MiB，但**必须真机复测扩展 footprint** 后才算通过。
- **订阅 channel 阻塞内核** → 消费 goroutine 必须非阻塞；channel 满时丢弃最旧日志条目，绝不回压内核主流程。
- **高频日志 IO** → lumberjack 顺序写 + OS 缓冲，单文件 1MiB 滚动；warning 级别下压力极小。
- **mihomo `log` 订阅 API 形态不确定** → 实施首步先读 `mihomo@v1.19.27` 的 `log` 包与 `hub/route` 的 `/logs` 实现，确认订阅/取消订阅签名再编码（systematic）。
- **主 App 读扩展正在写的文件** → 读时容忍不完整尾行；导出前可触发一次 flush（或接受最后一行可能截断）。

## Migration Plan

分阶段实施、每阶段可独立验证：
1. 内核落盘（Go + lumberjack + 路径下发）→ 真机看 App Group 文件生成、含最早日志、内存达标。
2. 主 App 实时改造（时间戳 / 复制 / 暂停 / 节流）→ 热重载验证。
3. 回看页 + 导出 → 真机验证回看最早、导出分享。

回滚：不下发日志路径时内核不落盘，主 App 退回纯 WS 实时显示，无破坏性。

## Open Questions

- mihomo `log` 包订阅的确切 API 与事件结构（实施首步确认）。
- `share_plus` 在 iOS 的最小配置（Info.plist / 分享 sheet）。
- 日志目录放 App Group 容器根下 `logs/` 还是 `Library/`（实施时定，倾向 `logs/`）。
