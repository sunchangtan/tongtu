## Why

P1-M3 子项目 1：设置页。当前 app 无设置入口——主题固定跟随系统、无「关于」、无配置原文查看、无生效规则查看。补齐基础设置体验与运维可视（订阅配置原文、内核生效规则）。真机挂起期优先做：软件部分本地完整可测，唯一真机 gate 是规则查看的真实数据。

经 brainstorming 收敛 + design review（实证 mihomo `/rules`、`/version` 行为）敲定范围。

## What Changes

- `home_shell` 加第 4 个底部 tab「设置」（连接 / 节点 / 监控 / 设置）。
- 应用设置：主题模式（亮 / 暗 / 跟随系统）切换并**持久化**；关于（app 版本、mihomo 内核版本、GPL-3.0、日志入口）。
- 配置查看子页：**只读**展示订阅配置原文 + 搜索 / 复制 / 导出；抽共享「只读文本查看页」组件，与现有 `log_viewer_page` 复用、避免重复。
- 规则查看子页：`clash_api` 新增 `getRules`（GET `/rules`）+ 列表 / 搜索 / 空态。
- **BREAKING**（内部）：`main.dart` 的 `themeMode` 从固定 `system` 改为 `ThemeController` 驱动（持久化）。
- 范围排除（YAGNI）：配置编辑、规则编辑、多订阅配置管理。

## Capabilities

### New Capabilities

- `settings`: 设置页能力——导航第 4 tab、应用设置（主题持久化 + 关于）、订阅配置原文只读查看、分流规则查看。

### Modified Capabilities

- `clash-api`: 新增「规则查询」——经 external-controller `GET /rules` 获取内核当前生效规则并解析为规则项列表。

## Impact

- **代码**：`lib/ui/home_shell.dart`（第 4 tab）、`lib/ui/settings_page.dart`、`lib/ui/config_viewer_page.dart`、`lib/ui/rules_page.dart`、`lib/ui/text_viewer_page.dart`（共享只读文本查看，`log_viewer_page` 重构复用）、`lib/main.dart` + `lib/core/theme_controller.dart`、`lib/core/clash_api.dart`（`getRules` + `RuleItem`）、`lib/core/kernel_version.dart`（内核版本静态常量，与 `core-bridge/go.mod` 锁定版本同步）。
- **测试**：设置页渲染、主题切换持久化、配置查看（mock content + 空态）、规则查看空态、`getRules` 按实证格式的 mock HTTP 单测。
- **真机 gate**：仅规则查看展示内核运行时的真实生效规则。
- **依赖**：无新增第三方依赖（复用 shared_preferences / clash_api / SubscriptionStore / share_plus）。
- **archive 顺序**：`clash-api` 修订基线在 `p1-m2-nodes-monitor`（未 archive），本 change 须在 m2 之后 archive。
