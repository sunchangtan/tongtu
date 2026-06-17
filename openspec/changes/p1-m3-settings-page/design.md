# 设计：M3 子项目 1「设置页」

## 1. 背景与范围

P1-M3 第一块。brainstorming 收敛 + design review（实证 mihomo route 行为）敲定：设置页 = 导航第 4 tab + 应用设置（主题持久化 + 关于）+ 配置查看（订阅原文只读）+ 规则查看（生效规则）。真机挂起期优先——软件部分本地完整可测，唯一真机 gate 是规则查看真实数据。

## 2. 架构与导航

- `home_shell` 底部导航由 3 tab → **4 tab**（连接 / 节点 / 监控 / **设置**），`IndexedStack` 加一项。
- `settings_page` = `ListView` 分组卡片，点进子页：外观（主题）/ 配置（→ 配置查看子页）/ 规则（→ 规则查看子页）/ 关于。

## 3. 关键决策（design review 实证敲定）

### 决策 1：配置查看 = 订阅原文，非 `/configs` 注入后
review 发现：`SubscriptionStore.loadContent()` 是**订阅原文**，看不到 `coreOverrides` 在 Go 层注入的 fake-ip DNS / external-controller / tun-fd。本子项目只做**订阅原文只读查看**（本地完整、命名为「订阅配置」以免误解为运行时生效配置）；运行时生效配置（`/configs` 含注入，需内核运行）留后续/真机功能，不在本范围。

### 决策 2：内核版本用静态常量，非 `/version`
review 实证 `GET /version` 返回 `{meta, version}` 但**需内核运行**（真机）。改用 Dart 静态常量 `lib/core/kernel_version.dart`（与 `core-bridge/go.mod` 锁定的 `v1.19.27` 同步，改内核版本时一并更新）——编译期静态、不依赖运行、本地可测；「关于」页全本地。

### 决策 3：`/rules` 按实证格式（避免测试假绿）
实证 `GET /rules` 返回 `{"rules":[{index, type, payload, proxy, size, extra}]}`。`RuleItem` 模型取 `type`/`payload`/`proxy`（+ `index` 排序），`getRules` 的 mock HTTP 测试**按此真实格式**写——践行「不验证就假设 → 测试假绿」的复盘教训（见 `docs/guidelines/code-review-checklist.md`）。

### 决策 4：抽共享「只读文本查看页」组件（复用）
`config_viewer` 与现有 `log_viewer_page` 高度雷同（读文本 + 搜索 + SelectionArea 复制 + share_plus 导出）→ 抽 `text_viewer_page`（接受标题 + 文本加载器），`log_viewer` 重构复用、`config_viewer` 复用，避免复制粘贴。

### 决策 5：主题驱动机制
`ThemeController` = `ValueNotifier<ThemeMode>` + shared_preferences 持久化（key `theme_mode`）。`main.dart` 用 `ValueListenableBuilder` 包 `MaterialApp`，切换即时重建；启动读取持久值（缺省 system）。

## 4. 模块划分

| 文件 | 职责 |
|------|------|
| `lib/ui/text_viewer_page.dart` | 共享只读文本查看（搜索/复制/导出），log_viewer + config_viewer 复用 |
| `lib/ui/settings_page.dart` | 设置主页（分组 + 子页入口）|
| `lib/ui/config_viewer_page.dart` | 订阅配置原文查看（复用 text_viewer + loadContent）|
| `lib/ui/rules_page.dart` | 规则查看（getRules + 列表/搜索/空态）|
| `lib/core/theme_controller.dart` | 主题模式状态 + 持久化 |
| `lib/core/kernel_version.dart` | 内核版本静态常量（与 go.mod 同步）|
| `lib/core/clash_api.dart` | 新增 `getRules()` + `RuleItem` |

## 5. 真机边界

- **本地完整**：设置页/主题/关于/配置查看（含空态）/规则页 UI 与空态 / `getRules` 单测。
- **真机 gate**：仅规则查看展示内核运行时的真实生效规则。

## 6. 测试策略（TDD）

`getRules` 按实证格式 mock HTTP 单测；主题切换持久化 widget 测试（SharedPreferences mock）；配置查看 mock content + 空态；规则页空态 + mock rules；设置页 4-tab 渲染。

## 7. archive 顺序

`clash-api` 修订基线在 `p1-m2-nodes-monitor`（未 archive）；本 change 须在 m2 之后 archive。
