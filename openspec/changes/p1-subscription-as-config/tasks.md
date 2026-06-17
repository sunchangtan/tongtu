## 1. 内核侧 DNS 覆写（Go / core.go，TDD）

- [x] 1.1 取证：确认 mihomo `RawConfig.DNS`（Enable/EnhancedMode/FakeIPRange/NameServer 等字段名）与 `RawConfig.Tun.DNSHijack` 结构，及覆写应发生在 `buildRawConfig`（ParseRawConfig 之前，作用于 RawConfig）还是 `applyConfig`（之后，作用于 cfg.DNS）——优先 RawConfig 层以复用 fake-ip 默认推导
- [x] 1.2 先写失败测试：`TunFD > 0` 时——①订阅自带 dns 上游被保留且强制 enhanced-mode=fake-ip、fake-ip-range 已设、fake-ip-filter 非空、tun.dns-hijack 已设、store-fake-ip 已启用；②订阅无 dns 段时用默认 fake-ip DNS（国内 DoH nameserver）；`TunFD == 0` 时不改写自带 DNS
- [x] 1.3 实现：`buildRawConfig` 中 `if ov.TunFD > 0` 条件合并——订阅有 dns 则保留上游仅注入 fake-ip 必需字段（enhanced-mode/fake-ip-range 缺省 198.18.0.1/16/补全 fake-ip-filter 主流列表）；订阅无 dns 则用默认（国内 DoH nameserver）；总是设 `tun.dns-hijack=["any:53"]` 与 `profile.store-fake-ip`
- [x] 1.4 `buildRawConfig` 遍历 `RawConfig.ProxyProvider`，为 `type: http` 的 provider 注入相对 `home-dir` 的本地缓存 `path`（如 `providers/<url-hash>.yaml`），统一覆盖以集中缓存目录；依据已核实的 `component/resource/fetcher.go:57-70` 回退顺序（本地缓存→bundle→远程），保证外网不可达时回退缓存
- [x] 1.5 单测：注入后每个 http provider 均有 `path`；并构造「本地缓存文件存在 + 远程不可达 → 内核回退用缓存节点（非 0）」验证 fallback
- [x] 1.6 `go vet` + `go build` + `go test`（含 DNS 覆写、external-controller 覆盖、proxy-provider path 注入、远程不可达 fallback 回归）全绿

## 2. 订阅完整正文获取（Dart，TDD）

- [x] 2.1 `SubscriptionInfo` 增加 `content`（完整配置正文）字段；`fetch` 保留 `resp.body` 而非丢弃
- [x] 2.2 有效性校验：body 须含 `proxies` 或 `proxy-providers` 才算合法 clash 配置，否则返回中文错误、不保存
- [x] 2.3 单测：`fetch` 返回完整 body + userinfo；非法内容（HTML/空/无节点字段）报中文错误

## 3. 以完整配置启动（Dart）

- [x] 3.1 `home_page` 的「获取配置」与「连接」两处：`configYAML` 改为订阅完整正文，移除 `RuntimeConfig.generateYAML` 调用
- [x] 3.2 废弃 `runtime_config.dart` 的 proxy-provider 包装（删除该生成逻辑；如需保留覆写/校验入口则改为对完整配置的轻量校验）
- [x] 3.3 `SubscriptionStore` 保存订阅**完整配置正文**（不止 URL），供连接时读取传入内核
- [x] 3.4 widget/单测：连接路径以完整配置正文驱动；旧的「生成 proxy-provider YAML」测试相应更新或移除

## 4. 质量门禁

- [x] 4.1 `flutter analyze` 0 警告 0 错误 + `dart format` + `flutter test` 全过
- [x] 4.2 `swiftlint --strict`（若涉及 Swift 改动）+ `go vet` 通过
- [x] 4.3 `openspec validate p1-subscription-as-config --strict` 通过

## 5. 真机验证与归档（gate）

- [ ] 5.1 真机导入真实订阅 → 节点页出现**真实节点**（非仅 COMPATIBLE），代理组可切换
- [ ] 5.2 实际流量走代理（出口 IP 验证）+ 域名 DNS 解析正常（fake-ip 生效）
- [ ] 5.3 扩展内存复测仍在红线内（常驻 < 40MiB / 峰值 < 50MiB）
- [ ] 5.4 实施完成且真机通过后，按 archive 顺序（`p1-m1-ios-skeleton` 在前）`openspec archive p1-subscription-as-config`

## 6. Review 修复（2026-06-18，code-review 抓到 2 严重 + 中/cleanup，已全修）

- [x] 6.1 #1 fake-ip-filter 守卫死代码（真机 APNs blocker）：`UnmarshalRawConfig` 以 `DefaultRawConfig` 为基底致 `len==0` 永不成立 → 改并集合并 `unionStrings` + 补必需项（含 `*.push.apple.com`/captive/连通性探测）+ `fake-ip-range` 强制设；回归测试（上游默认非空时仍补必需项）
- [x] 6.2 #2 移除自注入缓存 path：上游已按订阅自带 path / `md5(url)` 自动缓存，注入覆盖订阅 path 且 fnv32 更弱 → 删 `injectProviderCachePath`/`hashProviderURL`；真实订阅端到端实测移除后缓存仍有效（远程黑洞回退 143 节点）
- [x] 6.3 #3 stale config：`saveContent` 存来源 url + `_connect` 校验当前 url 一致性，不符提示重新获取
- [x] 6.4 #4 弱校验：正则行首锚定 `^(proxies|proxy-providers):` 替代子串 `contains`，含测试
- [x] 6.5 #5 DNS only TUN：保持（iOS NE 恒 TUN 正确），design 注明非 TUN 待 P3
- [x] 6.6 cleanup：`SubscriptionInfo.copyWith` / content 存文件（path_provider）/ home_page `_lastContent` state 缓存 / `requiredFakeIPFilter`+`fakeIPRange` 提常量
- [x] 6.7 门禁：`go vet`/`go test`（5）+ `flutter analyze`（第一方 0）/`test`（40）全绿
