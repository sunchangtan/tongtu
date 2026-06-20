# 设计：运行参数预设化（对齐 clashmi 核心设置）

## 1. 背景与现状

运行参数当前是「连接后热改」模型：`RunModeSelector`（连接首页，p1-m4）与 `KernelSettingsPage`（p1-m3）的运行模式/日志级别/IPv6 仅在连接后亮（`getConfigs` 回填 + `PATCH /configs` 热改 + 乐观回滚），未连接灰置「连接后可调」。用户指出此模型错误，要求照 **clashmi 核心设置**：参数随时可设、连接时写入配置、改后「需重连生效」。

配置消费链路（已核实）：Dart `start(configYAML)` → 原生 `SharedStore.configYAML` → Swift `makeOverridesJSON`（home-dir/tun-fd/log-dir/convert-geo-rules 等）→ Go `Start(config, overrides)` → `buildRawConfig`。`buildRawConfig` 不动 mode/log-level/ipv6/mixed-port/allow-lan——**YAML 里有什么内核就用什么**，故在 Dart 侧把偏好写进 YAML 即可生效。

## 2. clashmi 核心设置核实结论

clashmi 是开源 Flutter（KaringX/clashmi）；其 i18n `settingCore` 分组含：日志等级、TCP并发、TLS全局指纹、局域网设备接入(allow-lan)、混合代理端口(mixed-port)、进程匹配模式、TCP保活、延迟测试URL/超时、TUN、NTP、TLS、GEO、嗅探(sniffer)、DNS、外部控制(external-controller)、核心覆写；提示文案 `coreSettingTips`=「修改配置后需重连生效」。**模型 = 预设偏好 + 重连生效**（非连接后热改）。

iOS NE 适用性筛选：
- **纳入**（配置级偏好，iOS NE 安全且有意义）：运行模式 mode、日志等级 log-level、IPv6、统一延迟 unified-delay、TCP并发 tcp-concurrent、域名嗅探 sniffer、延迟测试 URL/超时（app 侧）、**局域网代理共享 allow-lan + mixed-port**。
- **排除**（逐项有因）：TUN/DNS/dnsHijack/strictRoute（NE 由 Go/Swift 覆写控制，进程内红线）；external-controller（内部随机端口）；GEO（已自动 geo→mrs）；核心覆写/进程匹配/NTP/TLS/TLS指纹/TCP保活（YAGNI / iOS 不适用 / 高级项暂缓）。

## 3. 目标 / 非目标

**目标**
- 运行参数随时可设（未连接也能改）、持久化、连接时写入配置生效、改后提示重连。
- 参数集对齐 clashmi 核心设置（iOS NE 适用项）。
- 软件本地完整可测（Store + 注入 + UI widget）。

**非目标（YAGNI）**
- 不做 TUN/DNS/外部控制/核心覆写等 NE 红线或高级项。
- 不做连接中对所有参数的实时热改（仅 mode 保留连接中热切；其余统一「重连生效」，对齐 clashmi）。

## 4. 关键设计决策

### 决策 1：偏好模型 `RunParamsStore`（核心）
- `RunParams { String mode; String logLevel; bool ipv6; bool unifiedDelay; bool tcpConcurrent; bool sniff; bool allowLan; int mixedPort; String delayTestUrl; int delayTestTimeoutMs; }`（值类型 + copyWith）。
- `RunParamsStore extends ChangeNotifier`：`load()` / 各字段 setter（持久化 shared_prefs JSON，key `run_params`）/ `applyToConfig(String yaml) → String`。与订阅正交（换订阅不丢偏好）。
- 默认值取 mihomo/clashmi 常用：mode=rule、log-level=info、ipv6=false、unified-delay=true、tcp-concurrent=true、sniff=false、allow-lan=false、mixed-port=7890、delay-test url=`http://www.gstatic.com/generate_204`、timeout=5000。

### 决策 2：连接时注入（`yaml_edit`）
- `applyToConfig(yaml)`：用 `yaml_edit` 精准改写顶层键 `mode`/`log-level`/`ipv6`/`unified-delay`/`tcp-concurrent`/`allow-lan`/`mixed-port`（存在则改、不存在则加，保留其余内容与注释）；`sniff=true` 时写入最小 `sniffer` 段（enable + sniff TLS/HTTP + 合理 default ports），`false` 时设 `sniffer.enable=false`。
- 落点：连接前在 `HomePage._connect` 用 `runParams.applyToConfig(currentContent)` 得到合并配置再 `controller.start`。纯 Dart，可单测；不改 Swift/Go、不重建 xcframework。
- 延迟测试 URL/超时**不进 YAML**（非内核配置键）：作为 app 侧参数，节点页 `testDelay(url,timeout)` 直接读 store。

### 决策 3：UI 去灰置常亮 + 重连提示
- 内核设置页运行参数组：控件**常亮**（未连接也可改，改即存盘）；顶部提示「修改后需重连生效」（连接中改时尤显）。移除 `getConfigs`/`_loadConfigs`/PATCH 乐观回滚复杂度。
- 运行模式（连接首页 `RunModeSelector`）：store 驱动；未连接可预设；**连接中保留热切**（`PATCH /configs` 即时生效 + 同步 store），符合 clash 客户端仪表盘惯例。
- 维护动作（更新 GEO/清缓存）保持连接后可用（作用于运行中内核，非参数）。

### 决策 4：升级种子化（不回归）
- 首次 `load()` 若无 `run_params` 持久化，则从**当前订阅配置**读取 mode/log-level/ipv6/… 顶层键作为初值存入 store（缺失键取默认）。避免「默认 mode=rule」悄改老用户 global 配置。一次性、幂等。

### 决策 5：局域网代理共享（allow-lan + mixed-port）
- 二者成对：`allow-lan=true` 使 mihomo 入站监听绑 `0.0.0.0`，配合 `mixed-port` 即「其它设备把本机当代理网关」。
- UI 一组：开关 allow-lan + 端口输入 mixed-port + 说明（局域网内用 `本机IP:端口` 接入）。
- **真机 gate**：NE 进程监听是否可被同网段设备连到（clashmi/Shadowrocket 已证可行，通途自身 TUN 设置下需真机实测）。

## 5. 数据流

- 设置：内核设置/连接页改参数 → `RunParamsStore` setter → 存盘 + notifyListeners（UI 刷新）。
- 连接：`HomePage._connect` → `currentContent()` 取订阅正文 → `runParams.applyToConfig()` 合并偏好 → `controller.start(merged)`。
- 连接中改 mode：`RunModeSelector` → `PATCH /configs` 即时 + 同步 store。
- 连接中改其它参数：仅存盘 + 提示「重连生效」（下次 start 经 applyToConfig 生效）。
- 升级：首次 load 从当前订阅配置种子化。

## 6. Risks / Trade-offs

- **[YAML 往返]** `applyToConfig` 改写大配置 → Mitigation：用 `yaml_edit` surgical 改写（仅动目标键，保留其余）；单测覆盖「键存在/不存在/sniffer 段/含注释」。
- **[局域网共享真机不通]** NE 监听可能不可被局域网连到 → Mitigation：clashmi 佐证可行；列真机 gate 实测；不通则降级为仅本机（文档说明），不阻塞其余参数。
- **[种子化误读]** 订阅配置无 mode 等键时 → Mitigation：缺失取默认；幂等只跑首次。
- **[与 m3/m4 行为冲突]** 覆盖原「连接后热改」→ Mitigation：MODIFIED kernel-settings 显式改写该需求；archive 顺序 m3→m4→m5。

## 7. 测试

- **RunParamsStore 单测**：持久化往返、各 setter、种子化（有/无订阅键）、`applyToConfig`（顶层键存在改写 / 不存在新增 / sniffer 段生成 / allow-lan+mixed-port / 保留其余键）。
- **RunModeSelector widget**：未连接可预设改 mode（存盘，不灰置）；连接中改 mode 发 PATCH。
- **KernelSettingsPage widget**：运行参数未连接常亮可改、重连提示存在、改即存盘；维护动作仍连接后可用。
- **连接合并 widget**：`_connect` 用合并后配置（断言 start 入参含偏好键）。
- **真机 gate**：局域网代理共享可达；各参数重连生效正确。

## 8. Open Questions

- mixed-port 默认值与冲突处理（7890 被占？）——iOS NE 进程内监听，端口冲突概率低，先用 7890，真机如遇问题再加占用校验。
- sniffer 段的精确默认（sniff 协议/端口/override-destination）——实施时取 mihomo 推荐最小集，真机验证分流。
