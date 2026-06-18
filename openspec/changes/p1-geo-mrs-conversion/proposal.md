## Why

iOS NetworkExtension 扩展进程有 50MB 内存硬限（jetsam `ActiveHard 50 MB fatal`），超出即被系统杀死。当前真实订阅含 35 条 `GEOSITE` 规则，mihomo 在 `config.ParseRawConfig` 的 `parseRules` 阶段会**立即（eager）全量加载整库 `geosite.dat`（4.2MB protobuf）进 Go 堆并永久缓存**——本地 fresh 进程对照实测坐实：完整配置解析堆增量 **+16.5MB**，剥掉 GEOSITE/GEOIP 仅 +0.1MB；拆分实测 **GEOSITE=16.5MB（真凶）**、GEOIP≈0 Go 堆（`geoip.metadb` 走 mmdb mmap 不进 HeapAlloc）。叠加 protobuf 解析的瞬时分配，phys 被推过 50MB → jetsam 杀进程 → **真机连接失败**。这是当前 P1 真机连接失败的根因（三源闭合：设备实测 + 内核源码 + 配置溯源）。

成熟同类产品 clashmi（KaringX，仅思路参照不复制代码）的官方 FAQ 明示同一限制并采用「`geosite/geoip` 会被强制转换成对应的 geo ruleset」的做法规避。本变更引入同类机制。

## What Changes

- 新增**内核桥层 geo 规则自动转换**：在 `core-bridge/mihomocore` 的 `buildRawConfig`（已做 TUN/fake-ip 注入处）把订阅里的 `GEOSITE,<cat>,<target>` / `GEOIP,<cc>,<target>` 规则**原位改写**为 `RULE-SET,<provider>,<target>`，并注入对应 **mrs 格式** rule-provider（`behavior: domain`/`ipcidr`，`format: mrs`），使内核不再加载整库 `geosite.dat`、改为按需紧凑加载。
- 新增 **mrs 全集预置**：构建期把 metacubex `meta-rules-dat` 的 geosite + geoip mrs 全集打进 iOS app bundle；主 app 首启拷入 App Group 容器，使转换后的 rule-provider 首连命中本地缓存、**零网络必达**。
- 注入的 rule-provider 配 `url`（公网 jsdelivr）+ `interval`，支持**自动更新**与「预置未覆盖类别」的远程回退。
- `ASN` / `IP-ASN` / `GEODATA` 类规则在 iOS 下**跳过/移除**（clashmi 同做法，FAQ 明示 iOS 不支持 ip-asn）。
- 失败降级：注入的 rule-provider 加载失败时复用内核既有「非致命降级」语义（不影响「能连」）。

## Capabilities

### New Capabilities

- `geo-rule-conversion`: 内核桥层把订阅的 geo 规则（GEOSITE/GEOIP）自动转换为 mrs rule-set，配合 app 侧 mrs 预置与首连缓存、自动更新与失败降级，使含 geo 规则的订阅在 iOS NE 50MB 内存限制下可正常启动与分流。

### Modified Capabilities

（无——转换逻辑在 `buildRawConfig` 内新增，不改变 `core-bridge` 既有契约 Start/Stop/Reload/覆写注入；mrs 预置拷贝是 `geo-rule-conversion` 能力的宿主侧实现，不改 `apple-packet-tunnel` 既有需求。）

## Impact

- **代码**：
  - `core-bridge/mihomocore/`：新增 `geo_ruleset.go`（`rewriteGeoRules` 纯函数）+ `buildRawConfig` 调用点。
  - iOS 宿主：构建脚本（拉取 mrs 全集进 bundle）+ 主 app 首启拷贝逻辑（Swift，bundle → App Group `home-dir/ruleset/`）。
- **测试**：Go 单测（规则改写 / provider 注入 / 去重 / 参数保留 / 首匹配顺序 / ASN 跳过 / 特殊字符 sanitize / 转换后解析堆增量≈0）；构建脚本校验（mrs magic）；首启拷贝逻辑测试；真机 gate（扩展启动内存 <50MB + 连接成功 + geo 分流正确 + 首连断网下命中预置）。
- **依赖**：无新增第三方依赖；mrs 数据源为 metacubex `meta-rules-dat`（官方，与「内核只用官方 mihomo」红线一致，RULE-SET mrs 是 mihomo 原生特性）。
- **app 体积**：bundle 预置全集 mrs，约 +10-20MB（构建脚本实测）。
- **关联**：本根因诊断与 `p1-subscription-as-config`（订阅作完整主配置）相关；archive 顺序在其后。
