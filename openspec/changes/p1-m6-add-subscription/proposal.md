## Why

当前「添加订阅」简陋：订阅 tab FAB 弹一个仅含「名称(可选) + 订阅链接 + 添加」的小弹窗，只能手敲/粘贴 URL。对照 clashmi「添加配置」缺：从剪贴板导入、扫码二维码、直接粘贴配置内容、每订阅自动更新间隔、自定义 User-Agent。用户要求对齐 clashmi 添加订阅体验。

> 核实 clashmi（开源 Flutter KaringX/clashmi）i18n：importFromUrl / importFromClipboard / qrcodeScan / profileAddUrlOrContent（URL 或内容）/ updateInterval（最小 5m）/ userAgent。

## What Changes

- **弹窗 → 全屏「添加订阅」页**：FAB push `AddSubscriptionPage`（容纳更多字段，对齐 clashmi 全屏添加）。
- **四种导入来源**：① URL（fetch）；② 直接粘贴 clash 配置内容（本地校验、不走 HTTP）；③ 从剪贴板导入（一键填入）；④ 扫码二维码（`mobile_scanner`，相机）。
- **每订阅自动更新**：`updateIntervalMinutes`（关 / 6h / 12h / 24h / 自定义≥5m）+ `lastUpdatedMs`；启动时对到期订阅自动重拉。
- **自定义 User-Agent**：拉取订阅时 UA 可配（默认 `clash.meta`，替换硬编码）。
- **模型扩展**：`Subscription` 加 `userAgent` / `updateIntervalMinutes` / `lastUpdatedMs`，随 JSON 持久化。

## Capabilities

### Modified Capabilities

- `multi-subscription`: 「订阅增删切换更新」的**添加**由「仅 URL + 名称」扩展为**多来源**（URL / 直接内容 / 剪贴板 / 扫码）+ 可设 User-Agent 与更新间隔；**新增**每订阅自动更新（间隔到期启动时重拉）。

## Impact

- **代码**：
  - 新增 `lib/ui/add_subscription_page.dart`（全屏添加页）、`lib/ui/scan_page.dart`（扫码，`mobile_scanner` 包装，结果回调可注入）。
  - 改 `lib/config/subscription.dart`（`fetch` 加 `userAgent` 参数、暴露内容校验）、`lib/config/subscriptions_store.dart`（`Subscription` 加字段；`add` 带 UA/interval、`addContent`、`dueForAutoUpdate`、`update` 用存储 UA 并置 lastUpdated）、`lib/ui/subscriptions_page.dart`（FAB 改 push 页）、`lib/ui/home_shell.dart`（启动时跑到期自动更新）。
- **依赖**：新增 `mobile_scanner`（iOS 扫码）。
- **原生**：iOS `Info.plist` 加 `NSCameraUsageDescription`。
- **测试**：Store 新字段/`addContent`/`dueForAutoUpdate`/update 带 UA 置 lastUpdated 单测；AddSubscriptionPage widget（剪贴板 mock、URL/内容识别、扫码回调注入、字段、添加成功）；ScanPage 结果处理。
- **真机 gate**：扫码相机实际可用；自动更新到期实际触发。
- **关联**：MODIFIED `p1-m4-multi-subscription-nav` 的 multi-subscription 能力；archive 顺序在其后。
- **YAGNI**：不做前台周期轮询自动更新（仅启动时检查）、不做「优先机场设置」间隔（我们订阅为完整配置、无标准 provider 间隔字段）、不做订阅分组。
