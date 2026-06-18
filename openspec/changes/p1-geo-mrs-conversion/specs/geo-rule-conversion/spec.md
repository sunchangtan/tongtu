## ADDED Requirements

### Requirement: GEOSITE/GEOIP 规则转换为 mrs rule-set
内核桥在解析订阅配置后、应用到内核前，必须（MUST）把 `rules` 段的 `GEOSITE,<类别>,<目标>` 与 `GEOIP,<国家码>,<目标>` 规则原位改写为引用 mrs rule-provider 的 `RULE-SET,<provider>,<目标>` 规则，并向 `rule-providers` 注入对应 provider（`type: http`、`format: mrs`，GEOSITE→`behavior: domain`、GEOIP→`behavior: ipcidr`）。`ASN`/`IP-ASN`/`GEODATA` 类规则在 iOS 下应当（SHALL）跳过（不转换为 mrs，按内核默认或移除处理）。

#### Scenario: GEOSITE 规则转换
- **当** rules 段含 `GEOSITE,google,PROXY`
- **则** 该规则原位变为 `RULE-SET,geosite-google,PROXY`，且 rule-providers 注入名为 `geosite-google` 的 provider（`behavior: domain`、`format: mrs`）

#### Scenario: GEOIP 规则转换
- **当** rules 段含 `GEOIP,cn,DIRECT,no-resolve`
- **则** 该规则原位变为 `RULE-SET,geoip-cn,DIRECT,no-resolve`，且注入名为 `geoip-cn` 的 provider（`behavior: ipcidr`、`format: mrs`）

#### Scenario: ASN 类跳过
- **当** rules 段含 `IP-ASN` 或 `GEODATA` 类规则
- **则** 该规则不被转换为 mrs rule-set（iOS 下跳过）

### Requirement: 转换保持顺序、参数与去重
转换必须（MUST）在规则列表中原索引替换，保持有序首匹配语义不变；规则尾部参数（如 `no-resolve`、`src` 变体）必须（MUST）原样保留到 `RULE-SET`；同一 geo 类别被多条规则引用时，应当（SHALL）只注入一个 provider（按类别去重）。类别名必须（MUST）先 trim 首尾空白并校验：仅含合法字符 `[a-zA-Z0-9-@!._]` 时按**原名**用于 provider name / `path` / `url` / `path-in-bundle`（保留 `@`/`!` 等，以避免不同类别因替换为 `_` 而碰撞同名 provider 致分流错配）；为空或含非法字符（逗号/斜杠/空格等）时不得（MUST NOT）转换该规则——保留原规则、不注入 provider，以防 URL/路径注入与 bundle 路径穿越。

#### Scenario: 首匹配顺序不变
- **当** 一条 GEOSITE 规则位于 rules 列表第 N 条
- **则** 转换后对应的 RULE-SET 规则仍在第 N 条

#### Scenario: 规则参数保留
- **当** GEOIP 规则带 `no-resolve` 参数
- **则** 转换后的 RULE-SET 规则保留 `no-resolve`

#### Scenario: 同类别去重
- **当** 两条规则均引用类别 `google`
- **则** rule-providers 中只注入一个 `geosite-google` provider

#### Scenario: 合法特殊字符原样保留（防碰撞）
- **当** 类别为 `category-social-media-!cn`（含合法字符 `!`）
- **则** provider name 为 `geosite-category-social-media-!cn`（原样），`url`/`path`/`path-in-bundle` 一致用原名

#### Scenario: 畸形类别跳过转换
- **当** 类别为空、或含非法字符（逗号/斜杠/内部空格）
- **则** 该规则不被转换、保留原样，且不注入对应 provider

### Requirement: 转换后避免整库 geo 数据加载
转换后的配置经内核 `ParseRawConfig` 解析时，不得（MUST NOT）触发整库 `geosite.dat` 的 eager 加载；解析后的 Go 堆增量应当（SHALL）显著低于未转换配置（实测未转换 +16.5MB），接近零。

#### Scenario: 转换消除 geosite.dat 堆占用
- **当** 含 35 条 GEOSITE 的配置经转换后再 `ParseRawConfig`
- **则** Go 堆增量接近零（对照未转换的 +16.5MB）

### Requirement: mrs 三级回退与首连零网络必达
注入的每个 rule-provider 必须（MUST）同时配置 `path`（本地缓存路径）、`path-in-bundle`（`BundleMRS.7z` 内条目名）、`url`（远程更新源）与 `interval`（自动更新周期）。内核应当（SHALL）按「本地 `path` → `BundleMRS.7z` bundle → 远程 `url`」三级回退加载。当本地缓存缺失但预置 bundle 存在时，首连必须（MUST）从 bundle 取得规则集、不发起网络请求。

#### Scenario: 首连命中预置 bundle
- **当** home-dir 无 `path` 本地缓存但存在 `BundleMRS.7z`
- **则** provider 初始化从 bundle 取得 mrs，不发起任何网络请求

#### Scenario: 到期自动更新
- **当** rule-provider 的 `interval` 到期
- **则** 内核从 `url` 拉取更新并写入 `path` 本地缓存，后续加载走本地

### Requirement: mrs 全集随包预置与首启就位
iOS app 必须（MUST）随包预置一个含 geosite + geoip mrs 全集的 `BundleMRS.7z`（按 `geosite/<类别>.mrs`、`geoip/<国家码>.mrs` 组织）。app 首启必须（MUST）确保该文件就位于 App Group 容器（内核 home-dir）根目录，使扩展启动时内核可经 bundle 回退命中。

#### Scenario: 首启拷入预置包
- **当** App Group 容器根目录无 `BundleMRS.7z`
- **则** app 从应用 bundle 拷入

#### Scenario: 已就位不重复拷贝
- **当** App Group 容器已存在 `BundleMRS.7z`
- **则** app 不重复拷贝（按版本判断是否更新）

### Requirement: provider 加载失败降级不影响连接
当注入的 rule-provider 初始化失败（预置未覆盖且远程不可达）时，内核应当（SHALL）以非致命方式降级（记录错误但继续启动），对应 geo 规则失效、其流量交由后续规则/`MATCH` 处理，隧道连接必须（MUST）仍能成功建立。

#### Scenario: 单个 geo provider 失败不阻断启动
- **当** 某 geo rule-provider 初始化失败（既无预置又无法远程拉取）
- **则** 内核记录错误并继续完成启动，隧道连接成功，该规则流量走后续规则或 MATCH
