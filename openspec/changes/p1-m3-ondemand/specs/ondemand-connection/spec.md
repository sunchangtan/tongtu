## ADDED Requirements

### Requirement: 按需连接语义配置与持久化
按需连接能力应当（SHALL）提供统一语义配置：总开关、触发范围（全部 / 仅 WiFi / 仅蜂窝）、信任 WiFi 列表；配置应当（SHALL）持久化，应用重启后保持。缺省为总开关关闭、触发范围「全部」、信任列表为空。

#### Scenario: 首次进入的缺省配置
- **当** 用户首次进入按需连接且无历史配置
- **则** 总开关关闭、触发范围为「全部」、信任列表为空

#### Scenario: 配置持久化往返
- **当** 用户修改按需配置并重启应用
- **则** 读回的配置与保存前一致

### Requirement: 信任 WiFi 优先断开
生成按需规则时，命中信任 WiFi 必须（MUST）断开隧道（直连），且信任规则必须（MUST）排在触发范围规则之前（有序首匹配语义下优先生效）。

#### Scenario: 信任 SSID 命中断开
- **当** 信任列表非空并生成规则
- **则** 规则数组首条为 Disconnect，且其 ssidMatch 含全部信任 SSID

#### Scenario: 信任优先于范围
- **当** 触发范围为「全部」且信任列表非空
- **则** 信任 Disconnect 规则排在范围 Connect 规则之前

### Requirement: 触发范围映射
能力应当（SHALL）按触发范围生成对应连接/断开规则：放行目标接口的 Connect，其余接口由末条 Disconnect(.any) 兜底断开。全部→任意接口连接；仅 WiFi→WiFi 连接、其余（含蜂窝）断开；仅蜂窝→蜂窝连接、其余（含 WiFi）断开。

#### Scenario: 仅 WiFi 范围
- **当** 触发范围为「仅 WiFi」
- **则** 生成首条 Connect(.wiFi) 与末条 Disconnect(.any)，使蜂窝等其他接口断开

#### Scenario: 仅蜂窝范围
- **当** 触发范围为「仅蜂窝」
- **则** 生成首条 Connect(.cellular) 与末条 Disconnect(.any)，使 WiFi 等其他接口断开

#### Scenario: 全部范围
- **当** 触发范围为「全部」
- **则** 生成 Connect(.any)

### Requirement: 按需规则注入与即时生效
主 App 应当（SHALL）将语义配置翻译为 NEOnDemandRule，经 NETunnelProviderManager 注入（onDemandRules + isOnDemandEnabled），配置改动应当（SHALL）即时保存生效、无需重启隧道。

#### Scenario: 开启即时生效
- **当** 用户开启按需连接并保存配置
- **则** manager.isOnDemandEnabled 为真、onDemandRules 已写入，且 saveToPreferences 成功

#### Scenario: 关闭按需连接
- **当** 用户关闭总开关并保存
- **则** manager.isOnDemandEnabled 为假，隧道回到纯手动控制

### Requirement: 读取当前 WiFi 自动填充
能力应当（SHALL）提供「添加当前 WiFi」：获得定位授权后读取当前 SSID 并加入信任列表；未获授权时应当（SHALL）给出可操作提示，且不得（MUST NOT）影响手动输入信任 SSID。

#### Scenario: 已授权读取
- **当** 已授予定位权限、设备连接 WiFi，用户点击「添加当前 WiFi」
- **则** 当前 SSID 被加入信任列表

#### Scenario: 未授权降级
- **当** 定位权限被拒，用户点击「添加当前 WiFi」
- **则** 提示前往系统设置开启权限，且手动输入信任 SSID 仍可用

### Requirement: 设置页按需连接入口与 UI
应用应当（SHALL）在设置页提供按需连接入口，子页含总开关、触发范围选择、信任 WiFi 列表（增删）；总开关关闭时，下方触发范围与信任列表应当（SHALL）禁用。

#### Scenario: 入口与渲染
- **当** 用户在设置页点击「按需连接」
- **则** 子页展示总开关、触发范围选择与信任 WiFi 列表

#### Scenario: 关闭时禁用下方选项
- **当** 按需连接总开关关闭
- **则** 触发范围与信任列表不可编辑
