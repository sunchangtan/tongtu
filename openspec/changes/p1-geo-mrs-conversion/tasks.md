# 任务拆解：geo 规则 app 侧自动转换为 mrs rule-set

实施顺序遵循 TDD（specs 场景即测试用例来源）：Go 纯函数先测后写 → 内存验证 → 预置包构建 → 首启拷贝 → 质量门禁 → 真机 gate。

## 1. Go geo 转换纯函数（TDD，本地完整可测）

- [x] 1.1 先写单测 `core-bridge/mihomocore/geo_ruleset_test.go`：覆盖 spec 全场景——GEOSITE→domain/GEOIP→ipcidr 转换、provider 字段注入（type/behavior/format/url/path/path-in-bundle/interval）、同类别去重、规则参数（no-resolve 等）保留、首匹配顺序不变、ASN/GEODATA 类跳过、特殊字符 sanitize（provider name/path 替换、url/path-in-bundle 保留原名）。**7 场景测试先红后绿**
- [x] 1.2 实现 `core-bridge/mihomocore/geo_ruleset.go`：`rewriteGeoRules(rawCfg *config.RawConfig)` 纯函数，原位改写 `rawCfg.Rule []string`、向 `rawCfg.RuleProvider map[string]map[string]any` 注入 provider；mrs url 基址 `testingcf.jsdelivr.net/gh/MetaCubeX/meta-rules-dat@meta/geo/{geosite,geoip}/<原名>.mrs`
- [x] 1.3 接入 `buildRawConfig` 调用点（在 TUN/fake-ip 注入旁），并加回滚开关 `coreOverrides.ConvertGeoRules`（默认关、iOS 显式开，可回退原行为）。on/off 两测先红后绿

## 2. 转换内存验证 + 诊断代码清理

- [x] 2.1 把 `mem_probe_test.go` 改造为 `ConvertGeoRules` on/off 内存对照（`TestGeoConvertParseHeap`，gated /tmp 真实配置+geo）：**实测 off=+16.5MB（eager 加载 geosite.dat）、on=+0.1MB**，坐实转换消除整库加载
- [x] 2.2 移除临时诊断代码：`core.go` 的 `logMemGo`（5 处打点 + `os` import）、`PacketTunnelProvider.swift` 的 `logMem` + `DispatchSourceTimer` 采样器 + `swiftlint:disable` 注释（go vet + swiftlint 通过、无残留）

## 3. mrs 全集预置包构建

- [x] 3.1 确认来源：meta-rules-dat 无现成 `BundleMRS.7z`（release 无 7z 资产）→ 自打包；git sparse clone `meta` 分支可行；全集 .mrs 实测 geosite 8.3MB(1858) + geoip 4.3MB(260) = **12.6MB**（最大 us.mrs 704K/cn.mrs 536K），7z 打包后预期 ~10-12MB
- [x] 3.2 `scripts/build-geo-bundle.sh`：git sparse clone `meta` 分支 `*.mrs` → 按 `geosite/<名>.mrs`/`geoip/<名>.mrs` 组织 → 7z 打包。校验 mrs magic + 数量；产物 **4.5MB（2118 files）**；mihomo `bundle.Open` 端到端读验证通过（含 `@` 特殊字符条目）
- [x] 3.3 `BundleMRS.7z` 纳入 Runner target Copy Bundle Resources：`scripts/add-geo-bundle-resource.rb`（xcodeproj gem，幂等，real_path 校验）；gitignore 不入库（脚本生成）；plutil 校验 pbxproj 合法

## 4. 主 app 首启拷贝（Swift）

- [x] 4.1 `ios/Runner/GeoBundleInstaller.swift`：`shouldInstall`（版本感知幂等判定纯函数）+ `ensureInstalled`（bundle→App Group 容器拷贝，后台异步不阻塞启动）；`AppDelegate` 启动时调用；`PacketTunnelProvider` overrides 加 `convert-geo-rules: true` 启用转换；`scripts/add-geo-bundle-resource.rb` 注册源进 Runner target
- [x] 4.2 测试拷贝逻辑：`shouldInstall` 纯函数 XCTest 4 例（RunnerTests）+ 本地 `swiftc` 编译运行验证（typecheck + 4 断言通过）；swiftlint --strict 0；提取 `makeOverridesJSON` 降 startCore body 合规

## 5. 质量门禁

- [x] 5.1 Go：`go vet` OK + golangci-lint **0 issues** + `go test ./mihomocore/` 全过（9 转换/开关 + 1 内存自包含测试，CI 可跑）
- [x] 5.2 Swift：`swiftlint --strict` **0 错 0 警告**（Runner/PacketTunnel/Shared）。`flutter build ios` 编译链接见 6.1（需 xcframework）
- [x] 5.3 Flutter：`flutter analyze` 第一方 0（本特性无 Dart 改动；唯一 warning 在 `tools/style-dictionary/node_modules` 第三方，门禁豁免）
- [x] 5.4 `openspec validate p1-geo-mrs-conversion --strict` 通过

## 6. 重建与真机验证（gate）

- [x] 6.1 重建 `MihomoCore.xcframework`（315M，含新 geo 转换 Go 代码）+ `flutter build ios --no-codesign` **✓ Built**（新 Swift 全部编译链接 + BundleMRS.7z 4.5MB 打进 Runner.app 验证）
- [ ] 6.2 真机：点连接成功，扩展不再被 jetsam 杀（对照修复前 0.45s 崩溃）
- [ ] 6.3 真机：扩展启动内存采样 < 50MB（附真机内存数据，满足 NE 内存红线要求）
- [ ] 6.4 真机：geo 分流正确（抽样验证国内直连、Google/ChatGPT 走代理、关键规则生效）
- [ ] 6.5 真机：断网首连命中预置（清缓存 + 飞行模式/断公网下首连，验证从 `BundleMRS.7z` 零网络加载）
- [ ] 6.6 实施完成且真机通过后，按 archive 顺序（`p1-subscription-as-config` 之后）`openspec archive p1-geo-mrs-conversion`
