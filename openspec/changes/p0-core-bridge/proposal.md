# Proposal: p0-core-bridge

## Why

FlMihomo 全项目最大的技术风险是 iOS Network Extension 的 50 MiB 内存上限（Apple 官方确认，超限即被 jetsam 杀进程）——mihomo Go 内核能否在该限额内稳定运行决定了 iOS/iPadOS 平台（用户指定的最高优先级平台）是否可行。P0 在投入任何 UI 开发之前，先构建内核桥接层并用最小 Demo 端到端验证内存可行性，避免方向性返工。

## What Changes

- 新建 `core-bridge/` Go 模块：直接依赖官方 `github.com/metacubex/mihomo`（跟踪 release tag，不 fork、不打私有补丁），导出启动/停止/重载/状态查询的精简接口。
- 建立 gomobile 构建管线：将 core-bridge 编译为 iOS/macOS 通用的 `MihomoCore.xcframework`（c-archive 静态库形态），构建脚本可一键复现。
- 新建最小 iOS 验证 App（Xcode 工程，非 Flutter）：主 App + Packet Tunnel Provider 扩展，扩展内静态链接 xcframework，能以 metacubex 推荐配置模板启动隧道并真实代理流量。
- 扩展内置内存防护参数（`GOMEMLIMIT`≈30MiB、`GOGC` 调低、`geodata-loader: memconservative`、定期 `FreeOSMemory()`）与内存指标上报。
- 产出内存压测报告：典型订阅（≥50 节点 + 常用规则集）下扩展常驻内存与峰值数据，给出 P1 的 go/no-go 结论。

## Capabilities

### New Capabilities

- `core-bridge`: mihomo 内核的 Go 封装层——基于官方仓库的依赖管理、生命周期接口（start/stop/reload/状态）、内存防护参数注入、xcframework 构建管线。
- `apple-packet-tunnel`: 苹果平台 Packet Tunnel Provider 最小实现——扩展内加载内核、YAML 配置传递、隧道虚拟接口与内核 TUN 栈对接、内存指标上报与 jetsam 防护。

### Modified Capabilities

（无——本项目为全新项目，`openspec/specs/` 当前为空。）

## Impact

- 新增目录：`core-bridge/`（Go 模块）、`ios-poc/`（最小验证 Xcode 工程）、`scripts/`（构建脚本）。
- 新增工具链依赖：Go（版本与 mihomo 上游 CI 对齐）、gomobile、Xcode 16+、付费 Apple 开发者账号（Network Extension entitlement，已具备）。
- 不影响任何现有代码（greenfield）。
- 风险决策点：若压测结论为内存不可行（典型配置 > 45MiB 且无法裁剪），P1 方案需降级（精简内核功能集或调整产品定位），将另立 change 重新评审。
