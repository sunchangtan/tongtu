# 设计：UI 导航重构 + 内核设置页

## 1. 背景与现状

`home_shell.dart` 当前为扁平 4 底部 tab（连接 / 节点 / 监控 / 设置，`IndexedStack` + `NavigationBar`）。节点（`nodes_page`，select 组节点/切换/测延迟）与监控（`monitor_page`，流量 WS + 连接 REST + 日志 WS）各占一个底部 tab，二者均「连接后才有数据」。设置页（`settings_page`，p1-m3-settings-page）含外观主题 / 按需连接 / 配置查看 / 分流规则 / 关于(app+内核版本+许可+日志)。缺少调节 mihomo 内核运行参数与执行内核维护的入口。

参照 clashmi「核心设置 vs 应用设置」分层重构。

## 2. 目标 / 非目标

**目标**
- 底部导航精简为 3 tab；节点/监控收进连接首页（顶部 TabBar），三页逻辑零改动复用。
- 新增内核设置页：连接中热改 mihomo 运行参数 + 维护动作 + 内核配置/规则/版本/日志查看。
- 应用层（主题/按需连接/app 关于）与内核层（运行参数/维护/内核配置）边界清晰。
- 软件部分本地完整可测（clash_api mock 单测 + widget 测试）。

**非目标（不做）**
- 不暴露通途强制写死的红线项（`tun.stack`/`auto-route`/`auto-detect-interface`/DNS fake-ip——iOS 沙盒 gvisor+fake-ip 铁律，见 p1-subscription-as-config）。
- 不暴露 NE 内危险动作（`POST /restart`/`POST /upgrade`——iOS 内核是 gomobile 进程内库，非独立二进制）。
- 不做高级覆写 UI（内存档位 gomemlimit / geo→mrs 转换开关——YAGNI；P0 已定内存 30MiB 最优、geo 转换 iOS 默认开）。
- 不放对 iOS NE 无意义的运行参数（find-process-mode 进程匹配 / allow-lan 局域网连入 / 各入站端口）。

## 3. 关键设计决策

### 决策 1：3 tab 导航 + 连接首页顶部 TabBar
`home_shell` 顶层去掉单一 AppBar，改为 `Scaffold(body: IndexedStack([ConnectShell, SettingsPage, KernelSettingsPage]), bottomNavigationBar: NavigationBar(连接/设置/内核设置))`；各页自带 `Scaffold + AppBar`（嵌套）。

新增 `ConnectShell`：`DefaultTabController(length: 3) + Scaffold(AppBar(title: 通途, bottom: TabBar(连接/节点/监控)), body: TabBarView([HomePage, NodesPage, MonitorPage]))`。

- 用 `IndexedStack`（底部 3 tab）保持各 tab 状态：监控 WS 订阅、节点列表不因切 tab 重建。
- 连接 tab 内 `TabBarView` 同样保持子页状态（`AutomaticKeepAliveClientMixin` 或 TabBarView 默认保留）。
- **理由**（vs 入口卡片/单页滚动）：TabBar 真正「收进首页」且保留节点/监控完整功能，三页直接塞 `TabBarView` 改动最小。

### 决策 2：内核设置内容（标准范围）与边界
KernelSettingsPage 四组（`ListView`）：
- **运行参数**（连接中热改、`PATCH /configs` 立即生效）：运行模式 `SegmentedButton`(rule/global/direct) · 日志级别下拉(info/warning/error/debug/silent) · IPv6 `Switch`。（域名嗅探经实证在无 sniffer 配置段时 PATCH 不生效、依赖订阅，移除以免开关无效——见 §7。）
- **维护**（连接中、动作按钮）：更新 GEO 数据库(`POST /configs/geo`) · 清 fake-ip 缓存(`POST /cache/fakeip/flush`) · 清 DNS 缓存(`POST /cache/dns/flush`)。
- **配置与规则**：查看订阅配置（复用 `ConfigViewerPage`）· 分流规则（复用 `RulesPage`）。
- **内核信息**：内核版本（编译期常量 `kMihomoVersion`）· unified-delay（`GET /configs` 只读）· 日志（复用 `LogViewerPage`）。

边界：应用层（主题/按需连接/app 版本·许可）留设置；内核层（内核配置/规则/版本/日志/运行参数/维护）归内核设置。按需连接是 iOS 系统级 `NEOnDemandRule`（非 mihomo 内核）→ 留设置。

### 决策 3：clash_api 扩展 + 运行参数热改数据流
`clash_api.dart` 新增（当前仅 7 个读/数据面方法，无 `/configs` 读写）：
- `Future<KernelConfig> getConfigs()` —— `GET /configs`，回填运行参数当前值 + unified-delay。
- `Future<void> patchConfigs(Map<String, dynamic> fields)` —— `PATCH /configs`，仅传改动字段（如 `{"mode":"global"}`），立即生效。
- `Future<void> updateGeo()` —— `POST /configs/geo`。
- `Future<void> flushFakeIP()` / `flushDNS()` —— `POST /cache/fakeip/flush` / `POST /cache/dns/flush`。
- `KernelConfig` 模型：mode/logLevel/ipv6/unifiedDelay（已实证 GET /configs 字段，见 §7）。

数据流：进内核设置页且连接中 → `getConfigs` 回填；用户改某项 → `patchConfigs({字段:值})` → 成功后乐观更新本地状态（失败回滚 + 提示）。`PATCH` 字段名用 mihomo `configSchema` 的 json tag（`mode`/`log-level`/`ipv6`）。

### 决策 4：未连接态处理
运行参数与维护动作依赖 external-controller（`currentEndpoint`），未连接时无 controller：这些项**灰置 + 提示「连接后可调」**；监听 `stateStream`，连接建立后启用并 `getConfigs` 回填。配置查看/分流规则/内核版本/日志不依赖实时连接（配置查看读订阅原文、规则页自处理未连接空态、版本是常量、日志读落盘文件），照常可用。

## 4. 内核可调项依据（mihomo v1.19.27 源码调研）

- `PATCH /configs`（`hub/route/configs.go:316-385`，`configSchema` :36-60）**运行时热改立即生效**：mode/log-level/ipv6/sniffing/tcp-concurrent/find-process-mode/interface-name/allow-lan/各端口/tun.*。本设计仅取对 iOS 有意义、安全且实证可靠的 **mode/log-level/ipv6**（sniffing 见 §7 实证移除）。
- `GET /configs`（`getConfigs`→`executor.GetGeneral`）可读全集含 **unified-delay**（只读，PATCH 不支持）、geo 更新间隔等。
- 维护 endpoint：`POST /configs/geo`（更新 GEO）、`POST /cache/fakeip/flush`、`POST /cache/dns/flush`。
- 不可暴露：`tun.stack`/`auto-route`/`dns.*`（通途 buildRawConfig 强制写死，core.go:206-259）、`POST /restart`/`POST /upgrade`（NE 内进程内库，危险）。

## 5. Risks / Trade-offs

- **[嵌套 Scaffold 双 AppBar]** → home_shell 顶层须去 AppBar，否则连接 tab 出现双标题栏。Mitigation：home_shell 仅 body+bottomNav，各子页自带 AppBar；widget 测试验证无双 AppBar。
- **[PATCH 字段/响应格式与实证不符]** → mock 测试假绿、真机改无效。Mitigation：实施 TDD 前 curl 真机 controller 坐实 GET/PATCH JSON 格式（同 getRules 经验）。
- **[切 tab 状态丢失]** → 监控 WS 重订阅、节点重拉。Mitigation：IndexedStack（底部）+ TabBarView keepAlive（连接内）。
- **[运行参数改了但订阅重连被覆盖]** → PATCH 改的是运行时，重连加载订阅原配置会回到订阅值。Mitigation：这是预期语义（运行时临时调节）；UI 不持久化运行参数，文档说明「重连恢复订阅配置」。

## 6. 测试

- **本地完整**：① clash_api `getConfigs`/`patchConfigs`/`updateGeo`/`flushFakeIP`/`flushDNS` mock HTTP 单测（按实证格式、含鉴权头）；② KernelSettingsPage widget 测试（连接中回填 + 改参数调 patch + 未连接灰置 + 维护按钮）；③ 导航重构 widget 测试（3 tab 切换 + 连接内 TabBar 切换 + 设置瘦身后项）；④ ConnectShell widget 测试（三子页存在、切换保留状态）。
- **真机 gate**：运行参数热改实际生效（mode 切 global 全量代理、log-level 改 debug 日志变多）；更新 GEO/清缓存成功；切 tab 监控/节点不断流。

## 7. Open Questions

- 已实证（任务 1.1，本地起 controller curl）：`GET /configs` 返回 200 完整 General JSON（`mode`/`log-level`/`ipv6`/`unified-delay`/`sniffing` 等 kebab 字段）；`PATCH /configs` 返回 204 无 body，`mode`(rule→global)、`log-level`(silent→debug) 实证生效；`POST /cache/fakeip/flush` 返回 204。**`sniffing` 在无 sniffer 配置段时 `SetSniffing` 不生效（实证 PATCH 后仍 false），依赖订阅、开关可能无效，故运行参数移除域名嗅探。**
- 日志级别下拉的可选值是否全展示（info/warning/error/debug/silent）或精简——倾向全展示（与 mihomo 一致）。
