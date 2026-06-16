# 变更提案：p1-m1-ios-skeleton

## Why

通途 P0 已用真机满负载验证 iOS 内核内存可行（满负载 go：峰值 35.2 MiB < 50 MiB jetsam 红线，GOMEMLIMIT=30 定为默认）。P1 进入 iOS/iPadOS MVP 交付，是第一波 Apple 三端的起点。M1 作为 P1 第一个里程碑，在 P0 的 PoC 工程之上立起**生产级骨架**并打通**最小可连接闭环**：真正的 Flutter 主应用 + 生产级 NE 扩展 + 订阅链接导入 + 连接/断开。先把骨架与端到端连接打通、用真实订阅验证，再在 M2–M4 铺开节点管理/面板/按需连接，延续 P0「先验证再铺开」的节奏。

## What Changes

- 新建 Flutter 工程脚手架于仓库根多平台目录（`lib/core`、`lib/config` 等，见 architecture.md §7），作为五平台共享主应用的起点。
- NE 扩展从 `ios-poc` 迁入 `ios/PacketTunnel` 并生产化：复用 P0 已验证的 fd 注入、gvisor 栈、出站接口监听、phys_footprint 上报，去除 PoC 的固定端口/写死 secret/调试开关。
- 新增 CoreController(Dart) 统一内核控制抽象 + `apple_core_controller` 经 Platform Channel 控制扩展（start/stop/状态流）。
- **BREAKING**（相对 PoC）：external-controller 端口/secret 改由 Dart 随机生成、经 Platform Channel 注入扩展，替代 ios-poc 固定 9090 + 写死 secret。
- 订阅链接导入：消费 mihomo 原生 `proxy-providers`；运行时 YAML = metacubex 推荐模板 + 用户 override 合并生成，不发明私有格式。
- 连接/断开 + 隧道状态显示（最小 UI，节点列表/切换等留 M2）。

## Capabilities

### New Capabilities
- `flutter-app-shell`: Flutter 主应用骨架与统一内核控制抽象——CoreController/apple_core_controller、Platform Channel 协议、连接生命周期与隧道状态流。
- `subscription-config`: 订阅链接导入与运行时配置生成——proxy-providers 消费、模板+override 合并、随机 external-controller 端口/secret 的生成与注入。

### Modified Capabilities
- `apple-packet-tunnel`: 由 P0 的 PoC 级升级为生产级——扩展迁入 `ios/PacketTunnel`；external-controller 端口/secret 改为经 Platform Channel 注入（不再固定 9090/写死 secret）；运行时配置来源由订阅生成的生产配置替代 PoC 的 demoConfig/TONGTU_STRESS 开关。

## Impact

- 新增目录：仓库根 Flutter 工程（`lib/`、`pubspec.yaml`、`ios/`）；`ios/PacketTunnel`（从 ios-poc 迁入）。
- `ios-poc/` 保留为 P0 归档参照（不删；M1 验证通过后可标记废弃）。
- 复用：`core-bridge` 的 `MihomoCore.xcframework`（无需改 Go 代码）；P0 已验证的 4 个 iOS 沙盒坑修复（TunFD 扫描、gvisor 栈、InterfaceMonitor）随扩展迁入。
- 工具链：新增 Flutter SDK；xcframework 构建管线复用；Apple 开发者账号 NE entitlement 已具备。
- 退出 gate：真实订阅节点连通 + 满负载内存复测（P0 已 go）；未达标则按 apple-packet-tunnel 的内存缓解阶梯处理。
- M2–M4（节点管理/面板/按需连接/上架）不在本 change 范围，后续各自成 change。
