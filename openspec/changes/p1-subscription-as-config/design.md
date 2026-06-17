# 设计：订阅作为完整 clash 主配置

## 1. 背景与根因（已用内核实跑坐实）

通途现状（`lib/config/runtime_config.dart`）：把订阅 URL 塞进一个名为 `subscription` 的 **proxy-provider**，PROXY 组 `use: [subscription]`，期望 mihomo 下载该 URL 解析出 `proxies` 列表。

但真实订阅（subconverter `target=clash`，以及多数机场/自建 clash 订阅）返回的是**完整 clash 主配置**：顶层为 `port`/`dns`/`proxy-providers`/`proxy-groups`/`rules`，**没有顶层 `proxies` 字段**，节点在其内部嵌套的 `proxy-providers` 里。

用 mihomo `v1.19.27` 内核对通途等价配置双向实跑（与真机无关，纯配置层）：

| 消费方式 | 结果 |
|---------|------|
| 订阅当 proxy-provider（现状） | `provider.Initial()` 报 `file must have a 'proxies' field`，`Proxies()` = **0** |
| 订阅当完整主配置（修复） | 内核运行时下载嵌套 `Provider_*`，解析出 **143** 个真实节点 |

0 节点 → PROXY 组只剩 mihomo 的 COMPATIBLE 占位 → 流量无可用出站 → 用户反馈的「连上但没走 vpn」。

## 2. 目标 / 非目标

**目标**
- 完整 clash 配置订阅可正常导入、连接后真实走代理、DNS 正常解析。
- 订阅自带的 `proxy-providers`/`proxy-groups`/`rules`/`rule-providers` 原样保留，由内核运行时下载。
- 复用既有 `coreOverrides` 注入机制（external-controller/secret/tun-fd），补齐 TUN 模式 DNS。

**非目标（本 change 不做，留后续）**
- 纯节点列表 / base64 订阅的格式探测与转换（当前以「订阅=完整 clash 配置」为前提；subconverter 已覆盖该形态）。
- 在 App UI 内编辑 DNS/TUN/规则等底层字段（通途定位「原生 YAML 直消费」，不做可视化编排）。

## 3. 关键设计决策

### 决策 1：订阅 = 完整 clash 主配置，不再包装为单一 proxy-provider
下载订阅的**完整响应正文**直接作为内核主配置。这是主流 clash 客户端（FlClash/clashmi）的一致模型，也符合「消费 mihomo 原生 YAML、不发明私有格式」红线。

### 决策 2：运行参数覆写保持在 Go 层（`core.go` coreOverrides），不照搬参照实现的 Dart 层覆写
FlClash/clashmi 在 Dart 层把订阅解析成 map、覆写字段、再编码回 YAML。通途**不照搬**，理由：
- `core.go` 已具备 Go 层覆写（`applyConfig` 用 `config.ParseRawConfig`，已强制覆盖 external-controller/secret，已注入 tun-fd），复用即可；
- Dart 不解析/重编码 YAML，订阅正文**原样**经现有 `configYAML` 通道传入，避免 YAML 往返导致的注释丢失、字段重排、类型失真；
- 职责清晰：Dart 只「下载完整正文 + 传入」，Go 负责「注入运行参数」。
- 代价：DNS 覆写逻辑需用 Go 操作 mihomo `RawConfig.DNS` 结构（可接受，见决策 3）。

### 决策 3：TUN 模式下注入 fake-ip DNS（强制并集 filter + 沿用订阅上游）+ dns-hijack + 映射持久化

iOS NE 的 TUN 通路必须 fake-ip 才能按域名分流（机制见 §9）。`core.go` 现状不处理 DNS，本次必补。仅当 `tun-fd > 0`：

- **强制**：`enable=true`、`enhanced-mode=fake-ip`、`fake-ip-range=198.18.0.1/16`、`fake-ip-filter` **并集合并**（保留订阅/上游已有 + 补必需项 `requiredFakeIPFilter`）、`tun.dns-hijack=["any:53"]`、`profile.store-fake-ip`（持久化映射，防 NE 重启后 `tunnel.go:304` 的 `fake DNS record missing` 断连）；
- **沿用**：`nameserver`/`fallback`/`proxy-server-nameserver` 等上游由订阅或上游默认提供（`UnmarshalRawConfig` 已填），不补充、不覆盖。

> **⚠️ Review 修正（关键）**：初版用 `len(FakeIPFilter)==0`/`len(NameServer)==0` 判断「订阅是否自带」。但 `config.UnmarshalRawConfig` 以 `DefaultRawConfig()` 为基底，DNS 各字段已预置上游默认（非空），守卫**永不成立**——`fake-ip-filter` 停留在上游默认（仅 msftnsci 几条，**缺 `*.push.apple.com`**），TUN 下 APNs 推送域名拿 fake IP 走代理致推送/连通性断裂。故改为：`fake-ip-range` 强制设、`fake-ip-filter` **并集合并**（必需项始终在）、`nameserver` 沿用不补。

**fake-ip-filter 必需项 `requiredFakeIPFilter`**（不走 fake-ip、直连真解析）：局域网 `*.lan`/`*.local`、`localhost.ptlogin2.qq.com`、网络探测 `+.msftconnecttest.com`/`+.msftncsi.com`/`captive.apple.com`/`connectivity-check.ubuntu.com`、Apple 推送 `*.push.apple.com`、厂商探测 `+.market.xiaomi.com`/`connect.rom.miui.com`、NTP `time.*.com`/`+.pool.ntp.org`、STUN `stun.*.*`。

## 9. fake-ip 工作原理（mihomo 实现，决策 3 依据）

1. **分配**（`dns/middleware.go:165` + `component/fakeip/pool.go:43`）：应用查 `example.com`，内核 DNS **不真解析**，从 `fake-ip-range` 顺序分配虚拟 IP（如 198.18.0.5），存 `198.18.0.5 ↔ example.com` 映射（offset 递增、满则 cycle 回绕 LRU 淘汰）。
2. **连接**：应用连虚拟 IP，经 NE TUN(fd) 进内核。
3. **反查分流**（`tunnel/tunnel.go:290-297`）：内核见 `DstIP` 在 fake-range 内 → `FindHostByIP` 反查回域名 → 设 `metadata.Host`、清空 `DstIP` → 按**域名**规则匹配选节点；真实 IP 由选定节点远端解析（防污染 / 泄漏）。

配套硬需求：`dns-hijack`（劫持 53 端口，否则应用直连公共 DNS 绕过）、`fake-ip-filter`（特殊域名不参与）、映射持久化（重启不丢映射，否则 `fake DNS record missing`）。

### 决策 4：嵌套 providers/groups/rules 原样保留，外网容灾依赖内核默认缓存（不自行注入 path）
不展开、不改写订阅里的 `proxy-providers`/`proxy-groups`/`rules`/`rule-providers`（已实跑验证内核能据此下载出节点）。**不自行注入缓存 path**——`home-dir` 由 coreOverrides 指向 App Group 容器即可。

**外网容灾仍然有效（关键，已实测）**：缓存来自两条内核默认路径——① 订阅 provider **自带 `path`**（如 subconverter 生成的 `./providers/Provider_*.yaml`）时落盘到该 path；② provider 无 path 时上游**自动**按 `md5(url)` 落盘到 `home-dir/proxies/`（`adapter/provider/parser.go:87-89` `GetPathByHash`）。两种情况 `Fetcher.Initial()` 回退顺序均为「**本地缓存 → bundle → 远程**」（`component/resource/fetcher.go:57-70`）。于是「曾在内网成功拉取过一次」后，外网启动先用本地缓存节点、远程下载转后台重试。已用真实订阅端到端实测坐实：移除注入后**尊重订阅自带 path**落盘 `providers/`、远程黑洞下回退 **143 节点**（与可达时一致）。

> **⚠️ Review 修正（关键）**：初版在 `buildRawConfig` 为 http provider 注入 `providers/<fnv32(url)>.yaml`。经查证这是**重复造轮子且有害**：① 上游本就用更强的 `md5(url)` 自动缓存；② 注入**覆盖订阅显式 path**（违本决策「原样保留」）；③ fnv32(32 位) 弱于 md5、有碰撞串档风险；④ 与上游一样未解决 `url` 含 `_dc`/token 易变致缓存 miss 的根因。故**移除注入**，依赖上游默认缓存。

**限制 / `_dc` 易变**：若 provider url 含每次刷新就变的 query（`_dc`/token），缓存 key 变、回退失效。通途「**获取配置存正文 / 连接用存正文**」设计天然规避——连接复用同一份存储正文（url 固定），缓存 key 稳定命中；仅「重新获取配置」才可能变，而那时正在联网。首次无缓存且远程不可达仍为 0 节点。

### 决策 5：订阅完整正文经现有 `configYAML` 通道传入
`Start(configYAML, overridesJSON)` 的 `configYAML` 由「`runtime_config` 生成的极简包装」改为「订阅下载的完整正文」。`overridesJSON` 不变（external-controller/secret/tun-fd/home-dir/log-dir/内存参数）。

## 4. 参照实现交叉验证

来源与许可证边界（遵 CLAUDE.md）：**FlClash**（GPL-3.0，可参考代码）、**clashmi**（GPLv3，按项目规约**仅学实现思路、不复制代码**）。本次仅取其架构做法做交叉印证，落地用通途自有代码。

| 维度 | FlClash | clashmi | 通途决策 |
|------|---------|---------|---------|
| 订阅消费 | 下载完整正文存文件，内核 `UnmarshalRawConfig` 验证 | 同（追加 `#url:` 注释行） | 决策 1：完整正文 |
| 覆写位置 | Dart 层改 map 再编码 | Dart 层三层补丁合并 | 决策 2：**Go 层**（复用既有，改动更小） |
| DNS | 条件覆写（overrideDns 开关）| 强制 fake-ip，range 从 tun IP 算 | 决策 3：**保留订阅上游 + 强制 fake-ip + filter + 持久化**（对齐 FlClash 条件合并） |
| tun.dns-hijack | `any:53` | `0.0.0.0:53` | 决策 3：`any:53` |
| external-controller | Dart 覆写 | 固定 127.0.0.1:9090 | 既有 coreOverrides（**随机端口**更优） |
| 嵌套 providers | 原样保留+注入 path | 原样保留 | 决策 4：原样保留 **+ Go 层注入缓存 path**（采 FlClash，外网容灾） |

两参照在「订阅=完整配置」「proxy-providers 原样保留」「TUN 强制 fake-ip」三点**完全一致**，构成对本方案的独立交叉验证。

## 5. 数据流（修复前 / 后）

```
修复前：订阅URL → runtime_config 包装成 proxy-provider(subscription)
        → Start(极简YAML) → 内核下载订阅URL取 proxies字段 → 完整配置无proxies → 0节点 ✗

修复后：订阅URL → subscription.fetch 保留完整正文
        → Start(完整配置YAML, overrides) → 内核 ParseRawConfig 解析完整配置
        → coreOverrides 覆写 external-controller/secret/tun-fd/DNS(fake-ip)/dns-hijack
        → 内核运行时下载嵌套 proxy-providers(订阅源) → 143节点 → 走代理 ✓
```

## 6. 与 p1-m1-ios-skeleton 的关系（archive 顺序）

被修订的 `subscription-config`（「订阅链接导入」「运行时配置生成」）当前定义在**尚未 archive** 的 `p1-m1-ios-skeleton`。本 change 的 `specs/subscription-config/` 为 MODIFIED delta，其基线即 m1 的该 capability。因此：
- **archive 顺序**：先 archive `p1-m1-ios-skeleton`（待其真机 gate 通过），再 archive 本 change；否则本 change 的 MODIFIED 找不到基线。
- 若届时 m1 仍未具备 archive 条件，可将本 change 的 spec 修订**合并回 m1** 后由 m1 统一 archive（二选一，实施完成时按实际状态定）。

## 7. 风险与开放问题

- **真机网络前提**：手机须能访问订阅源（本例 subconverter `10.0.8.4:25500` 与 NAS `:5000`，均在局域网）。外网无法访问内网源时，凭决策 4 注入的本地缓存 path **回退使用上次缓存节点**（须曾在内网联通一次）；**首次**无缓存且外网不可达仍为 0 节点，此为网络限制非本 bug。
- **订阅源在外网（公网订阅）**：若订阅源为公网地址，则无此局域网限制，缓存仅作离线兜底。
- **订阅为纯节点列表/base64 时**：`config.ParseRawConfig` 对「只有 proxies、无 proxy-groups/rules」的配置是否需补全最小 groups/rules，待真机或样本验证；当前非目标，发现再立项。
- **订阅自带 `external-controller`**：已验证 `applyConfig` 强制覆盖（`core.go:226`），订阅里的 `127.0.0.1:9090` 会被换成协商端口，无虞。

## 8. 测试策略（TDD）

- **Go（core.go）**：单测覆盖「TUN 模式下覆写后 RawConfig.DNS 为 fake-ip 且 tun.dns-hijack 已设」「非 TUN 模式不覆写 DNS」「订阅自带 external-controller 被覆盖」。
- **Dart（subscription）**：单测覆盖「fetch 返回完整 body」「完整配置正文作为 configYAML 传入」。
- **真机（gate）**：导入真实订阅 → 节点页出现真实节点（非 COMPATIBLE）→ 实际流量走代理 → DNS 解析正常 → 内存仍在红线内。
