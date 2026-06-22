## Why

当前订阅只支持单条（`SubscriptionStore` 单 `subscription_url`），且订阅输入与连接操作混在连接页（HomePage）；内核设置占一个底部 tab、其中的运行模式（规则/全局/直连）是高频切换却深在内核设置里。用户要求：① 支持多订阅管理；② 底部导航重排为 连接 / 订阅 / 设置；③ 内核设置降为设置页二级入口；④ 运行模式移到连接首页（更顺手，clash 客户端惯例）。

## What Changes

- **底部导航重排**：连接 / 设置 / 内核设置 → **连接 / 订阅 / 设置**（内核设置不再是底部 tab）。
- **新增多订阅管理**：`SubscriptionStore` 单订阅 → **多订阅模型**（list + 当前选中 currentId，content/info 按 id 落盘）；订阅 tab 提供列表 / 添加 / 切换 / 更新 / 删除。开发期不兼容旧单订阅数据（不做迁移）。
- **连接页拆分**：订阅相关（链接输入/获取配置/流量·到期）从连接页移到订阅 tab；连接页专注连接（状态/连接按钮/内存/诊断）+ **运行模式**。
- **运行模式移连接页**：从内核设置移到连接首页（连接中经 `PATCH /configs` 热改）；抽 `RunModeSelector` 复用既有 clash_api 逻辑。
- **内核设置降级**：从底部 tab 降为**设置页二级入口（push）**；内核设置去掉运行模式（留日志级别/IPv6/维护/配置规则/内核信息），恢复 AppBar（二级页需标题/返回）。
- **切换订阅**：切换设当前；已连接则提示「重连生效」（不自动断流）。

## Capabilities

### New Capabilities

- `multi-subscription`: 多订阅管理——订阅列表的增/删/切换/更新、当前选中、content/info 按订阅落盘；连接使用当前选中订阅；订阅 tab 承载订阅 UI，连接页专注连接。

### Modified Capabilities

- `app-navigation`: 底部三层导航由「连接/设置/内核设置」改为「**连接/订阅/设置**」；内核设置不再是底部 tab；连接首页连接子页新增运行模式。
- `kernel-settings`: 内核设置由底部 tab 降为**设置页二级入口**；运行参数**移除运行模式**（移至连接首页），保留日志级别/IPv6。

## Impact

- **代码**：
  - 新增 `lib/config/subscriptions_store.dart`（多订阅模型；`subscription.dart` 瘦身为无状态拉取/校验）、`lib/ui/subscriptions_page.dart`（订阅 tab）、`lib/ui/run_mode_selector.dart`（运行模式组件）。
  - 改 `lib/ui/home_shell.dart`（连接/订阅/设置）、`lib/ui/home_page.dart`（去订阅、加运行模式）、`lib/ui/settings_page.dart`（加内核设置入口）、`lib/ui/kernel_settings_page.dart`（去运行模式、恢复 AppBar）、`lib/ui/config_viewer_page.dart`（改读多订阅当前正文）。
- **测试**：SubscriptionsStore 多订阅 CRUD/currentId 单测；SubscriptionsPage widget；连接页运行模式 + 无订阅态；内核设置降级；home_shell IA。
- **依赖**：无新增。
- **关联**：修订 `p1-m3-kernel-settings`（已提交 0a07574）的 app-navigation/kernel-settings 能力；archive 顺序在其后。
- **YAGNI**：不做订阅自动更新（手动更新按钮）、不做订阅分组/排序、**不兼容旧单订阅数据（开发期，不做迁移）**。
