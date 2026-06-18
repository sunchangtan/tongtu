# 设计：geo 规则 app 侧自动转换为 mrs rule-set

## 1. 背景与根因（三源闭合 + 本地实测坐实）

P1 真机连接失败：点连接 → PacketTunnel 扩展启动 → 0.45 秒内 phys 冲到 ~50MB → 超 NE 扩展 50MB 硬限（kernel `memorystatus: exceeded mem limit: ActiveHard 50 MB (fatal)`）→ jetsam 杀进程 → 连接失败。

根因定位（三源闭合）：

| 来源 | 证据 |
|------|------|
| 设备实测 | 扩展启动 goHeap 峰值 34MB（存活数据，> GOMEMLIMIT 30MB，GC 收不掉） |
| 内核源码 | `config.ParseRawConfig` → `parseRules` → `NewGEOSITE`（geosite.go:65 `InitGeoSite`、:76 立即 `GetDomainMatcher`）**eager 全量加载** `geosite.dat` 进堆并永久缓存；`memconservative` 的 `defer runtime.GC()` 只释放解码临时缓冲、不释放已缓存规则（cache.go:48），是假象 |
| 配置溯源 | 订阅（subconverter，Aethersailor 模板）rules 段含 **35 条 GEOSITE + 7 条 GEOIP**，源自模板的 `[]GEOSITE,xxx` 内联规则 |

本地 fresh 进程对照实测（`core-bridge` `ParseRawConfig`，geo 文件预置）：

| 配置 | 解析后堆 | 增量 |
|------|------|------|
| 完整（35 GEOSITE + 7 GEOIP） | 17.3MB | **+16.5MB** |
| 只剥 GEOIP（留 GEOSITE） | 17.3MB | +16.5MB |
| 只剥 GEOSITE（留 GEOIP） | 0.9MB | **+0.1MB** |

结论：**16.5MB Go 堆几乎全是 GEOSITE**（geosite.dat 整库 protobuf 入堆）；**GEOIP≈0 Go 堆**（`geoip.metadb` 走 mmdb mmap，不进 HeapAlloc，但 9.6MB 文件 mmap 占少量 phys）。geosite.dat 解析的瞬时分配（heapSys 飙到 115MB+）是把 phys 推过 50MB 的元凶。

参照 clashmi（KaringX，仅思路参照不复制代码）官方 FAQ：iOS VPN 扩展 50MB 硬限，`geosite/geoip` 会被强制转换成对应的 geo ruleset；ip-asn 在 iOS 不支持；geo ruleset 支持自动更新。本设计引入同类机制。

## 2. 目标 / 非目标

**目标**
- 含 GEOSITE/GEOIP 规则的订阅在 iOS NE 50MB 限制下可正常启动、连接成功、分流语义不变。
- 转换对所有宿主统一生效（落点 Go 内核桥），消费 mihomo 原生 YAML、不发明私有格式、不 fork 内核。
- 首连零网络必达（预置）；联网后自动更新（保持 geo 数据新鲜）。
- 转换核心逻辑本地完整可测（纯函数 + 内存实测）。

**非目标（本 change 不做）**
- DNS 段的 geo 引用（`nameserver-policy`/`fake-ip-filter` 里的 `geosite:`/`geoip:`）转换——本订阅未用、且经 DNS 而非 rule-provider 路径，声明为已知边界，留后续。
- geo 数据的可视化管理/手动选择类别（YAGNI）。
- 非 iOS 宿主的内存红线适配（转换逻辑统一生效，但预置/拷贝是 iOS 宿主侧；其他宿主走远程 url 即可，本 change 不展开）。

## 3. 关键设计决策

### 决策 1：转换落点 = Go 内核桥 `buildRawConfig`（不在 Dart 层）

在 `core-bridge/mihomocore/buildRawConfig`（已做 TUN fd 注入、fake-ip DNS 注入处）新增 geo 转换步骤。

**理由（vs Dart 层下发前转换）**：
- 配置改写逻辑**内聚一处**：fake-ip/TUN 注入已在 Go 层操作 `config.RawConfig`，geo 转换是同类操作，避免「geo 在 Dart、fake-ip 在 Go」逻辑分裂。
- **跨宿主统一**：iOS/未来 Android/macOS 走同一内核桥，一次实现处处生效。
- **语义零漂移**：直接操作 `RawConfig.Rule []string` 与 `RawConfig.RuleProvider map[string]map[string]any`（已确认字段类型 config.go:441/444），无需 Dart 重实现规则解析、无 YAML 往返丢注释/锚点。
- **测试基建现成**：Go 单测 + 已验证的内存实测路径。
- 与 clashmi（内核封装层转换）做法一致。
- 代价：改 `core-bridge` 需重建 xcframework 才能上设备验证（接受）。

### 决策 2：转换范围 = GEOSITE + GEOIP 都转，ASN 类跳过

GEOSITE 是 16.5MB 真凶（必转）。**GEOIP 经实测不占 Go 堆**（`geoip.metadb` 走 mmdb mmap，不进 HeapAlloc），故转 GEOIP 对解决 jetsam 无直接贡献——仍选择转它的**唯一实质理由是统一机制**：一个 `BundleMRS.7z` + 一套「path→bundle→url」三级回退同时覆盖 geosite/geoip，无需为 geoip.metadb 单独搞预置与首连必达（geoip mmdb 走 geodata `Init` 而非 rule-provider，是另一套代码路径）。

`ASN`/`IP-ASN`/`GEODATA` 类：iOS 跳过/移除（clashmi FAQ 明示 iOS 不支持 ip-asn；本订阅未用）。

**与 clashmi 的关系（诚实标注，勿夸大）**：clashmi FAQ 明文「geosite/geoip 会被强制转换成对应的 geo ruleset」，**方向一致（两个都转）**；但其内核封装层闭源，FAQ 未公开 geoip 转成的具体 behavior/format，故「geoip→`ipcidr` mrs」是本项目基于「mihomo 原生支持 + 统一机制」的**设计选择，非 clashmi 细节级验证**。

**技术可行性（实测坐实）**：mihomo v1.19.27 `ipcidr_strategy` 有对称的 `FromMrs`/`WriteMrs`（ipcidr_strategy.go:58/68）；meta-rules-dat 的 geoip mrs 头 behavior 字节实测 = 1(ipcidr)、geosite = 0(domain)，magic `MRS\x01`；注入配 `behavior: ipcidr` 与文件头校验（mrs_reader.go:39 `_behavior[0] != strategy.Behavior().Byte()`）匹配，不会报 invalid behavior。

**理由（vs 只转 GEOSITE）**：GEOIP 转换逻辑与 GEOSITE 几乎一致（仅 `behavior: ipcidr` 与 URL 路径不同），增量复杂度低；统一机制省去对 geoip.metadb 的单独预置/加载路径。

### 决策 3：mrs 预置用 mihomo 官方 `path-in-bundle` + `BundleMRS.7z` 机制 + jsdelivr 自动更新

注入的 rule-provider 三字段协同，复用内核 `Fetcher.Initial` 三级回退（fetcher.go:56）：

```yaml
geosite-google:
  type: http
  behavior: domain          # geoip → ipcidr
  format: mrs
  url: https://testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@meta/geo/geosite/google.mrs
  path: ./ruleset/geosite-google.mrs        # ① 本地缓存（interval 更新写此）
  path-in-bundle: geosite/google.mrs        # ② BundleMRS.7z 内条目（首连回退源）
  interval: 86400                           # 24h 自动更新
```

回退链：① `os.Stat(path)` 命中读本地 → ② 未命中从 `home-dir/BundleMRS.7z` 取 `path-in-bundle` 条目（`MakeBundleFile`，bundle.go:15/25）→ ③ 远程 `url`。

**app 侧预置**：构建脚本把 metacubex `meta-rules-dat` 的 geosite+geoip mrs 全集打成一个 `BundleMRS.7z`（按 `geosite/<cat>.mrs`、`geoip/<cc>.mrs` 组织）随 iOS app bundle；主 app 首启检测 App Group `home-dir/BundleMRS.7z` 缺失则从 app bundle 拷入。`home-dir` = App Group 容器（`PacketTunnelProvider` 经 `coreOverrides.home-dir` 设 `container.path`）。

**理由（vs 主动拷 N 个散 mrs / 纯远程）**：
- `path-in-bundle` + `BundleMRS.7z` 是 mihomo **官方为预置场景设计**的机制（constant/path.go:166-182），最接近 clashmi 实际做法；只需预置**一个** 7z 文件（拷贝逻辑最简），内核自动从包内取。
- 首连命中 bundle → **零网络必达**（解决「jsdelivr 之前 curl 失败过」的首连风险）。
- `interval` + `url` 提供自动更新与「预置未覆盖类别」远程回退，geo 数据保持新鲜。
- 全集预置（约 +10-20MB app 体积，构建脚本实测）覆盖任意订阅、零维护列表。

### 决策 4：转换映射细节

- **原位改写**：`GEOSITE,<cat>,<target>[,<params>]` → `RULE-SET,geosite-<cat>,<target>[,<params>]`；`GEOIP,<cc>,<target>[,no-resolve]` → `RULE-SET,geoip-<cc>,<target>[,<params>]`（`<cat>`/`<cc>` 为校验后的原类别名）。在 `Rule` 切片中**原索引替换**，保持首匹配顺序不变。
- **参数保留**：规则尾部参数（GEOIP 的 `no-resolve`、`src` 变体等）原样透传到 RULE-SET。
- **同类别去重**：多条规则引用同一类别 → 只注入一个 provider（按类别名去重）。
- **类别名校验（不替换，防碰撞）**：先 `TrimSpace` 首尾空白；仅含合法字符 `[a-zA-Z0-9-@!._]` 时**按原名**统一用于 provider name / `path` / `url` / `path-in-bundle`（保留 `@`/`!` 等——若如旧设计替换为 `_`，则 `a@b` 与 `a!b` 会碰撞同名 provider、第二个被去重跳过而复用第一个的 url，导致**分流静默错配**，这是 code-review 发现并修正的缺陷）；为空或含非法字符（逗号/斜杠/空格等）时**跳过转换、保留原规则、不注入 provider**（防 URL/路径注入与 bundle 路径穿越）。`@`/`!` 在 provider name（map key + RULE-SET 引用，非逗号分隔符）、iOS 文件名、URL path 均合法，已验证可达。

### 决策 5：失败降级复用内核既有「非致命降级」语义

provider Initial 失败（预置未覆盖 + 公网不可达，理论边缘场景）→ 内核 `loadProvider` 仅 `log.Errorln` 不 return（executor.go:315，已坐实）→ 该 geo 规则失效、流量走后续规则/MATCH。**不影响「能连」**，仅边缘类别首连分流不准。有全集预置兜底，此场景极罕见。

### 决策 6：仅转 rules 段

本订阅 geo 仅出现在 rules 段（已 grep 确认 DNS 段未用 `geosite:`/`geoip:`）。DNS 段 geo 经不同内核路径（非 rule-provider），转换方式不同，作为已知边界留后续。

## 4. 机制说明（决策依据）

### 4.1 geo eager 加载（决策 1/2 依据）
`ParseRawConfig`（config.go:692 `parseRules`）→ 每条 GEOSITE 规则 `NewGEOSITE` → `InitGeoSite`（首次触发，文件缺失则下载）→ 立即 `GetDomainMatcher` 全量加载该类别进堆。`executor.ApplyConfig` 顺序：`updateRules`（触发 geo）→ `updateTun`（gvisor 栈）→ `loadProvider`，末尾 `runtime.GC()`（此时已达峰值）。

### 4.2 rule-provider 三级回退 + 预置机制（决策 3 依据）
- `RawConfig.RuleProvider map[string]map[string]any`（config.go:441）→ `parseRuleProviders` → `ParseRuleProvider(name, mapping, ParseRule, MakeBundleFile)`（config.go:1007）。
- schema 字段（parse.go:16-25）：`behavior`/`path`/`url`/`format`/`path-in-bundle`。HTTPVehicle 用 `url`+`path`（parse.go:59），bundle 用 `makeBundleFile(schema.PathInBundle)`（parse.go:68）。
- `Fetcher.Initial`（fetcher.go:56）：`os.Stat(path)` → `bundleFile()`（从 `BundleMRS.7z` 取，bundle.go:25 `sevenzip.OpenReader(C.Path.BundleMRS())`）→ 远程。`C.Path.BundleMRS()` = `home-dir/BundleMRS.7z`（constant/path.go:166-182，大小写不敏感）。

### 4.3 mrs 格式（决策 2/3 依据）
mrs 是 mihomo 1.18+ 原生支持的二进制 rule-set 格式（zstd 压缩，外层 magic `28b5 2ffd`；解压后头部 = `MRS\x01`(4B) + behavior(1B) + count(8B BE)），`domain` 与 `ipcidr` behavior **均支持** mrs（domain_strategy/ipcidr_strategy 各有 `FromMrs`），`classical` 不支持。domain 编译为紧凑 DomainSet、ipcidr 为 IpCidrSet（比 geosite.dat 全量 protobuf 省 90%+）。已验证 meta-rules-dat 覆盖配置全部 42 类别（含特殊字符）、`google.mrs` 仅 8.8KB、单订阅 mrs 总量 832KB；解压实测 geoip mrs behavior 字节 = 1(ipcidr)、geosite = 0(domain)，故注入 provider 时 geosite 配 `behavior: domain`、geoip 配 `behavior: ipcidr`。

## 5. Risks / Trade-offs

- **[全集 mrs 体积]** → app +10-20MB。Mitigation：mrs 极紧凑（zstd），现代 app 可接受；7z 二次压缩；后续若需可降级为常用集 + 远程回退。
- **[`path-in-bundle`/`BundleMRS.7z` 行为与真机实测有出入]** → 首连可能走远程而非 bundle。Mitigation：tasks 阶段先用本地内核（macOS）跑通 bundle 回退；真机 gate 验证断网首连命中。
- **[meta-rules-dat 类别名/URL 变动或某类别无 mrs]** → 个别 provider Initial 失败。Mitigation：失败降级（决策 5）；构建脚本拉取时校验覆盖与 mrs magic。
- **[geosite 与 mrs domain-set 匹配语义差异]** → 分流结果与原 GEOSITE 不完全一致。Mitigation：mrs 由 metacubex 官方从同源 geosite 数据生成，语义等价；真机 gate 抽样验证关键分流（国内直连、Google/ChatGPT 走代理）。
- **[ASN 跳过改变分流]** → 原 ASN 规则失效。Mitigation：本订阅未用 ASN；与 clashmi 一致；如未来订阅用 ASN，声明 iOS 不支持。

## 6. 实施与回滚

**实施顺序**：① Go `rewriteGeoRules` 纯函数 + 单测 + 内存实测（本地完整，不需设备）→ ② 构建脚本拉全集 mrs 打 `BundleMRS.7z` + 校验 → ③ 主 app 首启拷贝（Swift）+ 测试 → ④ 重建 xcframework + app → ⑤ 真机 gate（内存 <50MB + 连接 + 分流 + 断网首连）。

**回滚**：转换是 `buildRawConfig` 内新增步骤，加开关（如 `coreOverrides` 标志或编译期常量）即可关闭回退到原行为；不改内核、不改订阅消费契约，回滚无残留。

## 7. Open Questions

- `BundleMRS.7z` 是用 metacubex 现成发布物，还是构建脚本自打包全集 mrs？（tasks 阶段先查 meta-rules-dat 是否有现成 bundle；无则用 7z 打包已验证的 mrs 全集。）
- 首启拷贝落点：主 app（AppDelegate，扩展启动前就位）vs 扩展启动时（更稳但扩展内存敏感）。倾向主 app，tasks 阶段定。
- `interval` 默认 24h（86400）暂定，真机验证后可调。
