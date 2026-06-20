## Why

当前运行参数（运行模式 / 日志级别 / IPv6 等）只有**连接后**才能调（未连接灰置「连接后可调」、仅经 external-controller `PATCH /configs` 热改）。用户指出这是错的：参数应像 **clashmi** 那样**随时可设**（作为偏好持久化、连接时写入配置生效、改后提示「需重连生效」），而非只在连接后才亮。经核实 clashmi「核心设置」正是此模型（其文案 `coreSettingTips` = 「修改配置后需重连生效」）。本次照 clashmi 核心设置内容重构运行参数。

> 复盘：曾误判 `allow-lan`「iOS NE 是死开关」要排除，被「clashmi 为何有此开关」证伪——NE 进程可开监听 socket 接受局域网入站（iPhone 当局域网代理网关，Shadowrocket/Stash/clashmi 皆有），allow-lan 与 mixed-port 成对即「局域网代理共享」。教训沉淀于 `docs/guidelines/code-review-checklist.md` 第 7 类陷阱。

## What Changes

- **运行参数模型重构**：从「连接后热改、未连接灰置」改为「**预设偏好（随时可设）→ 连接时写入配置生效 → 重连生效**」。
- **新增 `RunParamsStore`**：运行参数偏好持久化（shared_prefs，ChangeNotifier），与订阅正交（换订阅不丢）。
- **连接时注入**：连接前用 `yaml_edit` 把偏好合并进当前订阅配置 YAML 顶层键（mode/log-level/ipv6/unified-delay/tcp-concurrent/sniffer/allow-lan/mixed-port），再交内核。纯 Dart 一层，不改 Swift/Go、不重建 xcframework。
- **参数集对齐 clashmi 核心设置**（iOS NE 适用项）：运行模式、日志级别、IPv6、统一延迟、TCP 并发、域名嗅探、延迟测试 URL/超时（app 侧）、**局域网代理共享（allow-lan + mixed-port）**。
- **UI 去灰置常亮**：内核设置页运行参数未连接也可设；显示「需重连生效」提示；运行模式在连接首页仍可连接中热切。
- **升级不回归**：首次从当前订阅配置**种子化**偏好（读其 mode 等存入 store），避免默认值悄改老用户配置。

## Capabilities

### New Capabilities

- `run-params`: 运行参数偏好——随时可设、持久化、连接时合并进配置生效、重连生效；参数集对齐 clashmi 核心设置（含运行模式预设 + 局域网代理共享 allow-lan+mixed-port）；升级从订阅配置种子化。

### Modified Capabilities

- `kernel-settings`: 运行参数由「连接后热改、未连接灰置」改为**承载预设偏好（去灰置常亮、重连生效提示）**；扩充参数集（统一延迟改可设、新增 TCP 并发/域名嗅探/延迟测试/局域网共享）。

## Impact

- **代码**：
  - 新增 `lib/config/run_params_store.dart`（`RunParams` 模型 + `RunParamsStore` 持久化 + `applyToConfig(yaml)` 注入 + 种子化）。
  - 改 `lib/ui/run_mode_selector.dart`（mode 改 store 驱动、未连接可设、连接中热切）、`lib/ui/kernel_settings_page.dart`（运行参数改 store 驱动常亮、去 getConfigs/PATCH 回填、加重连提示 + 新参数项）、`lib/ui/home_page.dart`（连接前 `applyToConfig` 合并）、`lib/ui/home_shell.dart` + `connect_shell.dart`（共享注入 `RunParamsStore`）、节点页延迟测试用 store 的 url/超时。
- **测试**：RunParamsStore 持久化/种子化/applyToConfig（含/不含已有键、sniffer 段、allow-lan+mixed-port）单测；run_mode_selector 与 kernel_settings 去灰置常亮 widget；连接合并 widget。
- **依赖**：新增 `yaml_edit`（精准改写 YAML，保留其余内容）。
- **关联**：修订 `p1-m3-kernel-settings`（0a07574）与 `p1-m4-multi-subscription-nav` 的运行参数行为；archive 顺序在两者之后。
- **真机 gate**：局域网代理共享（allow-lan+mixed-port）需真机验证 NE 监听可被局域网连到；各参数预设后重连生效正确。
- **YAGNI**：不纳入 TUN/DNS/external-controller/核心覆写/NTP/TLS指纹/进程匹配等（NE 红线由 Go/Swift 覆写控制、或不适用 iOS、或高级项暂缓）。
