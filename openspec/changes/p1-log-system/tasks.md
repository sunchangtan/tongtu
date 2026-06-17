## 1. 内核落盘（Go / mihomocore）

- [x] 1.1 读 `mihomo@v1.19.27` 的 `log` 包与 `hub/route` 的 `/logs` 实现，确认日志订阅 / 取消订阅 API 与事件结构（systematic 首步，落地前先取证）。取证结论：`log.Subscribe()→Subscription[Event]`（buffer 200）/`UnSubscribe`；`Event{LogLevel,Payload}`；**无缓冲 logCh + 阻塞 Emit → 慢消费会回压卡内核 → 落盘须两级 buffer + select default 丢弃，绝不回压**
- [x] 1.2 `go.mod` 加 `gopkg.in/natefinch/lumberjack.v2` 依赖
- [x] 1.3 `core.go`：`Start` 在 `applyConfig` 前订阅日志，goroutine 非阻塞写入 `lumberjack`（`MaxSize=1MiB` / `MaxBackups=4`）；overrides 增加日志目录路径；`Stop` 取消订阅并结束 goroutine（两级 buffer + select default 防回压；编译 + vet 通过）
- [x] 1.4 Go 单测：落盘写入正确；文件滚动限容（4 个测试全过，含 condition-based poll 处理 lumberjack 异步删除）
- [x] 1.5 `go vet` + `go build` + 全量 `go test` 通过（4 个日志测试 + 回归全绿）；golangci-lint 已在 5.2 补跑零问题

## 2. 日志路径下发（Swift 扩展）

- [x] 2.1 （简化）扩展进程自身用 `containerURL(appGroup)` 算 App Group 容器内日志目录，无需经 `providerConfiguration` 从主 App 传——并入 2.2
- [x] 2.2 `PacketTunnelProvider.startCore`：用 `containerURL` 算 `logs/` 目录、确保存在、经 overrides `log-dir` 传内核
- [x] 2.3 `AppDelegate`：新增 channel method `logDir` 返回 App Group 日志目录绝对路径（供主 App 读取）
- [x] 2.4 `swiftlint --strict` 通过

## 3. 主 App 实时日志（Dart，TDD）

- [x] 3.1 `LogEntry` 加接收时间戳 `time` 字段（含单测）
- [x] 3.2 `monitor_page`：日志区 `SelectionArea` 可选中复制 + 显示 `HH:mm:ss` 时间戳
- [x] 3.3 暂停 / 继续：冻结当前画面快照 + 暂停期间不丢日志、继续后补上（含 widget 测试）
- [x] 3.4 节流批量刷新（~300ms）+ 内存上限 `N=1000`、超出丢最旧（含 widget 测试）

## 4. LogStore + 回看 + 导出（Dart，TDD）

- [x] 4.1 `pubspec.yaml` 加 `share_plus`（path_provider 评估后移除——LogStore 用 channel 取目录、未实际使用），`pub get`
- [x] 4.2 `LogStore`：经 channel 取日志目录、读全量文件（含 backups 按时间合并）、定位当前文件、清空（含单测）
- [x] 4.3 `LogViewerPage`：从文件回看全量日志（含最早、跨会话）+ 关键词搜索 + 刷新（含 widget 测试）
- [x] 4.4 导出：`share_plus` 分享日志文件（回看页导出按钮）；监控页日志 tab 加「完整」入口跳回看页

## 5. 质量门禁与真机验证

- [x] 5.1 `flutter analyze` 0 警告 0 错误 + `dart format` 规范 + `flutter test` 全过（25 个测试）
- [x] 5.2 `swiftlint --strict` 通过 + `go vet` 通过 + **`golangci-lint` v2.12.2 补跑零问题**（2026-06-18 安装后跑 `core-bridge/mihomocore`，errcheck 报 7 处未检查 `Close` 返回值，已逐个显式忽略 `_ = x.Close()`；第一方门禁全绿）
- [ ] 5.3 真机验证：App Group 日志文件生成、含最早 provider 下载日志、滚动限容（多次重启不累积）、实时显示 / 暂停 / 回看 / 搜索 / 导出
- [ ] 5.4 真机内存复测：扩展 `phys_footprint` 仍在 <40MiB 常驻 / <50MiB 峰值红线内（落盘开销可忽略）
- [ ] 5.5 `openspec validate p1-log-system --strict` 通过，实施完成后 `openspec archive`
