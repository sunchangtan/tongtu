## Context

通途当前仅支持手动连接/断开（`ios/Runner/AppDelegate.swift` 的 `TunnelController.start/stop`）。iOS 提供系统级按需连接 `NEOnDemandRule`：在 `NETunnelProviderManager` 上设置有序规则数组 `onDemandRules` + 开关 `isOnDemandEnabled`，系统据网络条件（接口类型、WiFi SSID 等）自动启停隧道。`architecture.md` §7 既定 `lib/ondemand/`（统一 UI 规则模型，分平台落地）。

现状约束（已实查）：
- `TunnelController` 注入点 = `mgr.onDemandRules` + `mgr.isOnDemandEnabled`，须在 `saveToPreferences` 前设置；改动后 `saveToPreferences` 即生效、无需重启隧道。
- `Runner.entitlements` 仅含 `networkextension` + `application-groups`；读 SSID 需补 `com.apple.developer.networking.wifi-info`。
- `Info.plist` 无 `NSLocationWhenInUseUsageDescription`（iOS 读 SSID 的前提）。
- deployment target：PacketTunnel 扩展 = 15.0；Runner 主 App 继承 project-level 13.0（未显式覆盖）。

## Goals / Non-Goals

**Goals:**
- 「网络条件开关」形态的按需连接：总开关 + 触发范围（全部/仅WiFi/仅蜂窝）+ 信任 WiFi 列表（命中→断开）。
- 软件部分本地完整可测（Dart 模型/UI + Swift 规则映射纯函数 XCTest + 编译验证），真机 gate 最小化。
- 读取当前 WiFi 自动填充信任列表（手动输入为基础、自动填充为增强）。

**Non-Goals:**
- 完整自定义有序规则列表（Surge 式）、域名探测（`EvaluateConnection`）、DNS 维度匹配。
- 「手动断开后抑制自动重连直到下次手动」的复杂调度。
- macOS/其他平台落地（本期仅 iOS；模型预留统一）。

## Decisions

### D1 MVP 形态 = 网络条件开关
预设开关（总开关 + 触发范围 + 信任 WiFi）映射为少量 `NEOnDemandRule`。**备选**：完整自定义规则列表——UI 重、规则模型与序列化复杂、测试面大、部分维度需真机；YAGNI 排除。

### D2 信任 WiFi 动作 = 断开（Disconnect）
信任 WiFi 命中时断开隧道直连，符合「可信网络不需要代理」主流心智。**备选**：`Ignore`（保持现状）——用户易困惑「无自动反应」，不选。

### D3 规则映射位置 = Swift 纯函数 `OnDemandRuleBuilder`
Dart 仅持有语义配置，经 MethodChannel 传 Swift；Swift 侧 `OnDemandRuleBuilder.build(config) -> [NEOnDemandRule]` 为**纯函数**，贴近 NE API 且可用 `RunnerTests` XCTest 断言字段（不依赖真机）。**备选**：Dart 构造规则中间表示、Swift 仅机械翻译——需自定义 IR 协议，过度设计。

### D4 生效时机 = 即时 `saveToPreferences`
配置改动即调 `applyOnDemand` 写入并保存，立刻生效（manager 不存在则 `makeManager`）。on-demand 与手动连接解耦：`updateOnDemand` 即时持久化 `onDemandRules`/`isOnDemandEnabled`，`start()` 复用 manager 已持久化的 on-demand（`start` 的 `saveToPreferences` 仅更新 protocol/isEnabled，不覆盖 `onDemandRules`）。**备选**：仅连接时下发——改完不生效、违背直觉。

> 边界：on-demand 自动连接复用上次 `start` 持久化的 `providerConfiguration`（端口/secret）与 App Group `configYAML`，故首次使用前需至少手动连接一次。该行为列入真机 gate 验证。

### D5 读 SSID API = `NEHotspotNetwork.fetchCurrent`（iOS 14+）
配合 `CLLocationManager` When-In-Use 授权。**备选**：`CNCopyCurrentNetworkInfo`——iOS 13 起弃用路径，不选。

### D6 SSID 录入 = 手动输入 + 「读取当前 WiFi」填充
核心规则注入靠系统匹配，不需 App 读 SSID；仅「一键填入当前 WiFi 名」需定位权限 + entitlement。手动输入零权限、完全本地可测；自动填充为增强。

### D7 Runner deployment target 对齐 15.0
消除「主 App 13.0 < 扩展 15.0」既有矛盾（<15.0 设备本就无法用 VPN 核心功能，无实际用户损失），使 iOS 14+ API 直用、避免无意义 `@available` 劣化。

### D8 与连接单按钮的交互 = 不做规避，UI 文案提示
on-demand 开启后系统自动启停，手动「断开」若规则仍匹配会被系统重连（iOS 既定行为）。MVP 仅以 UI 文案提示，连接页单按钮保持现状。

### 核心映射表（有序首匹配，信任优先）

| 触发范围 | 信任列表 | 生成的有序 `[NEOnDemandRule]` |
|---|---|---|
| 任意 | 非空 | `Disconnect(ssidMatch=信任)` 置顶 + 下列范围规则 |
| 全部 all | — | `Connect(.any)` |
| 仅 WiFi | — | `Connect(.wiFi)` + `Disconnect(.any)` 兜底 |
| 仅蜂窝 | — | `Connect(.cellular)` + `Disconnect(.any)` 兜底 |

> 受限范围（仅 WiFi/仅蜂窝）放行目标接口、其余由 `Disconnect(.any)` 兜底；全部范围由 `Connect(.any)` 覆盖、无需兜底。避免「`Disconnect(具体接口)` + `Disconnect(.any)`」对同一断开动作的冗余死规则。

## Risks / Trade-offs

- **[NE API 假设未经独立文档验证]**（WebFetch 未能抓取 Apple SPA，返回与模型记忆同源）→ 以实施期 `xcodebuild` 编译（字段/API 误用即编译失败）+ 真机 gate 双重验证；且这些为稳定公知 NE API。
- **[读 SSID 无定位授权 → ssid 为 nil]** → UI 降级：提示前往系统设置开启权限，手动输入不受影响、功能不致命。
- **[on-demand 开启后手动断开被自动重连，用户困惑]** → UI 文案明确提示该行为属正常。
- **[deployment target 提升]** → 扩展已锁 15.0，对齐主 App 无实际用户损失。
- **[`RunnerTests` 能否 `@testable import` Runner 测 `OnDemandRuleBuilder`]** → 实施期确认；若不可，将 builder 置于可被测试 target 编译的位置（见 Open Questions）。

## Migration Plan

1. 本地实施软件部分（Dart 模型/UI + Swift builder/注入 + entitlement/Info.plist/pbxproj），TDD 推进。
2. 质量门禁全绿（`flutter analyze`/`test`、`swiftlint --strict`、`xcodebuild` 编译 + XCTest）。
3. 真机 gate 验收（on-demand 实际触发、读 SSID）后，按 archive 顺序归档。
- **回滚**：按需连接为增量功能，关闭总开关即 `isOnDemandEnabled=false` 回到纯手动；entitlement/权限改动不影响既有手动连接路径。

## Open Questions

- ~~`RunnerTests` target 是否已配置可 `@testable import Runner`？~~ **已确认**：`RunnerTests` 以 Runner.app 为 `TEST_HOST`/`BUNDLE_LOADER`，支持 `@testable import Runner`。`OnDemandRuleBuilder` 逻辑另经 iOS Simulator SDK 编译 + `simctl spawn` 本地运行验证（因 `.cellular` 在 macOS 标记 `@available(macOS, unavailable)`，须经模拟器跑）。
