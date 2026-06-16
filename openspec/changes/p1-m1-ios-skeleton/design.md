## Context

P0 已用真机满负载验证 iOS 内核内存可行（满负载 go，GOMEMLIMIT=30）。当前可工作的是 `ios-poc`：纯 Swift/SwiftUI 单 App + Packet Tunnel 扩展，用固定 9090 端口 + 写死 secret + 内联 demoConfig + `TONGTU_STRESS` 调试开关。M1 要在此之上立起生产级 Flutter 主应用骨架并打通最小可连接闭环。约束：只用官方 mihomo 内核、GPL-3.0、遵循 architecture.md v1.3 与 2026-06-15 brainstorming 决策、复用 `core-bridge` 的 `MihomoCore.xcframework`（不改 Go 代码）。

## Goals / Non-Goals

**Goals:**
- Flutter 工程脚手架建于仓库根多平台目录，作为五平台共享主应用起点（architecture.md §7）。
- NE 扩展从 `ios-poc` 迁入 `ios/PacketTunnel` 并生产化，复用 P0 验证的 4 个沙盒坑修复（TunFD 扫描、gvisor 栈、InterfaceMonitor、phys_footprint 上报）。
- CoreController(Dart) 抽象 + apple_core_controller 经 Platform Channel 控制 NE 扩展（启停 + 状态流）。
- external-controller 端口/secret 由 Dart 随机生成、经 Platform Channel + App Group 注入扩展。
- 订阅链接导入（proxy-providers）+ 运行时 YAML 生成（模板 + override 合并）。
- 连接/断开 + 隧道状态显示。
- 退出 gate：真实订阅节点连通 + 满负载内存复测。

**Non-Goals:**
- 节点列表/切换/延迟测试、流量/连接/日志监控（M2）。
- zashboard 面板、按需连接 NEOnDemandRule、订阅自动更新（M3）。
- UI 打磨、错误处理完善、App Store 上架（M4）。
- macOS/Android/Windows/Linux（后续阶段）。

## Decisions

- **Flutter 工程位置**：仓库根（`flutter create .` 风格），五平台共享 `lib/`。理由：对齐 architecture.md §7 与 FlClash 同构；避免子目录嵌套带来的路径复杂度。
- **NE 扩展集成**：Flutter 的 `ios/` Runner 工程中加入 `PacketTunnel` 扩展 target，迁入 ios-poc 的 Swift 代码 + App Group + NE entitlement，链接复用的 xcframework。理由：Flutter 原生层落在 `ios/`，扩展 target 须并入该 Xcode 工程。
- **内核控制路径**：Dart CoreController → MethodChannel → Swift 主 App → NETunnelProviderManager → 扩展；隧道状态经 EventChannel 回流 Dart。理由：architecture.md §3 的 Platform Channel 抽象。
- **端口/secret 注入**：Dart 随机生成（端口避冲突、secret 随机串）→ 经 App Group（及/或 NETunnelProviderManager providerConfiguration）传扩展，扩展启动内核前读取。理由：替代 PoC 硬编码，安全且支持未来多实例。
- **配置生成**：metacubex 推荐模板 + 用户 override + 订阅 proxy-providers 合并为 mihomo 原生 YAML，写入 App Group 供扩展加载。理由：与官方 wiki 兼容，不发明私有格式。
- **core-bridge 复用**：不改 Go 代码，复用 `MihomoCore.xcframework`（含 with_gvisor）。

## Risks / Trade-offs

- [Flutter `ios/` 工程加 NE 扩展 target 非标准流程] → 先用最小可行方式（手动 pbxproj 或 xcodegen 脚本化）打通，M1 只求可构建可运行；稳定方案在实施中定。
- [端口/secret 经 App Group 传递的时序] → 主 App 必须在 `startTunnel` 触发前写好 App Group，扩展启动时即可读到。
- [迁移引入回归] → ios-poc 4 个沙盒坑修复迁移时可能遗漏 → 迁移后真机复测数据通路（直连打开网页）+ 满负载内存复测兜底。
- [Flutter iOS 链接 314M xcframework 的体积/时间] → P0 已验证可链接，复用即可。

## Open Questions

- Flutter `ios/` 加 PacketTunnel 扩展 target 的最稳方式（手动 pbxproj vs xcodegen vs 插件）——M1 实施首个任务中敲定。
- 订阅存储与多订阅管理——M1 最小化为单订阅，多订阅留 M2。
