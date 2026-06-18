## Why

当前底部导航为扁平 4 tab（连接 / 节点 / 节点 / 监控 / 设置），节点与监控各占一个底部 tab；且缺少调节 mihomo 内核运行参数（运行模式、日志级别、IPv6、域名嗅探）与执行内核维护动作（更新 GEO、清理缓存）的入口。参照 clashmi「核心设置 vs 应用设置」分层形态，把节点/监控收进连接首页、底部导航精简为三层，并新增「内核设置」承载内核运行参数与维护。

## What Changes

- **导航重构**：底部导航 4 tab → **3 tab（连接 / 设置 / 内核设置）**。
- **节点/监控收进连接首页**：连接 tab 内用顶部 TabBar（连接 / 节点 / 监控）承载三页，复用现有 `HomePage`/`NodesPage`/`MonitorPage`（逻辑不动）。
- **新增「内核设置」页**：运行参数（运行模式 / 日志级别 / IPv6 / 域名嗅探，连接中经 `PATCH /configs` 热改、立即生效）、维护动作（更新 GEO / 清 fake-ip / 清 DNS 缓存）、配置与规则（查看订阅配置 / 分流规则）、内核信息（内核版本 / unified-delay / 日志）。
- **clash_api 扩展**：新增 `GET /configs`（回填）、`PATCH /configs`（热改）、`POST /configs/geo`（更新 GEO）、`POST /cache/fakeip/flush` 与 `POST /cache/dns/flush`（清缓存）封装——当前 clash_api 仅有读/数据面方法，无 `/configs` 读写。
- **设置页瘦身**：移出配置查看 / 分流规则 / 日志 / 内核版本（归内核设置）；保留外观主题 / 按需连接 / 关于（app 版本·许可）。

## Capabilities

### New Capabilities

- `app-navigation`: 应用底部导航与连接首页结构——三层底部导航（连接 / 设置 / 内核设置），连接首页用顶部 TabBar 整合连接 / 节点 / 监控，设置与内核设置按「应用层 vs 内核层」分工。
- `kernel-settings`: 内核设置能力——连接中经 external-controller 热改 mihomo 运行参数（模式 / 日志级别 / IPv6 / 嗅探）、执行维护动作（更新 GEO / 清缓存）、查看内核配置/规则/版本/日志；未连接时可调项灰置。

### Modified Capabilities

（无——节点/监控/连接/配置查看/规则/日志各页逻辑均复用不改，仅重组导航位置。）

## Impact

- **代码**：
  - `lib/ui/home_shell.dart`（4→3 tab）、新增 `lib/ui/connect_shell.dart`（连接首页 TabBar 容器）、新增 `lib/ui/kernel_settings_page.dart`（内核设置页）、`lib/ui/settings_page.dart`（瘦身）。
  - `lib/core/clash_api.dart`（新增 `GET /configs`/`PATCH /configs`/`POST /configs/geo`/`POST /cache/*` 封装 + `KernelConfig` 模型）。
  - 复用不动：`home_page.dart`/`nodes_page.dart`/`monitor_page.dart`/`config_viewer_page.dart`/`rules_page.dart`/`log_viewer_page.dart`。
- **测试**：clash_api 新方法 mock HTTP 单测（按实证格式）；KernelSettingsPage widget 测试（连接中/未连接态、改参数调 patch）；导航重构 widget 测试（3 tab + 连接 TabBar 切换）；真机 gate（运行参数热改实际生效、更新 GEO/清缓存生效）。
- **依赖**：无新增（复用 http/web_socket_channel/clash_api）。
- **红线**：内核设置不暴露通途强制写死项（tun.stack/auto-route/DNS fake-ip）与 NE 内危险动作（restart/upgrade）。
