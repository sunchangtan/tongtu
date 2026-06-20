## ADDED Requirements

### Requirement: 运行参数偏好持久化
应用必须（MUST）提供独立于订阅的运行参数偏好（运行模式 / 日志级别 / IPv6 / 统一延迟 / TCP 并发 / 域名嗅探 / 局域网接入 / 混合端口 / 延迟测试 URL·超时），随时可设（无需先连接），并持久化、重启保持；换订阅不得（MUST NOT）丢失偏好。

#### Scenario: 未连接时设置并持久化
- **当** 未连接状态下修改运行模式为 global 并重启应用
- **则** 读回的运行模式偏好仍为 global

#### Scenario: 偏好独立于订阅
- **当** 切换当前订阅
- **则** 运行参数偏好保持不变（不随订阅重置）

### Requirement: 连接时写入配置生效
连接必须（MUST）在启动内核前把运行参数偏好合并进当前订阅配置正文（顶层键，存在则改写、不存在则新增，保留其余内容），使偏好生效；参数改动应当（SHALL）在重连后生效，并提示用户需重连。

#### Scenario: 偏好合并进配置
- **当** 偏好为 mode=global、tcp-concurrent=true，发起连接
- **则** 传入内核的配置正文顶层 `mode` 为 global、`tcp-concurrent` 为 true

#### Scenario: 保留订阅其余配置
- **当** 合并偏好进含 proxies/proxy-providers/rules 的订阅配置
- **则** 这些其余内容保持不变，仅目标参数键被改写

#### Scenario: 改参数提示重连
- **当** 已连接状态下修改日志级别
- **则** 提示「需重连生效」，不要求实时热改（运行模式除外）

### Requirement: 参数集对齐 clashmi 核心设置
运行参数集必须（MUST）涵盖 clashmi 核心设置中 iOS NE 适用项：运行模式（rule/global/direct）、日志级别（silent/error/warning/info/debug）、IPv6、统一延迟、TCP 并发、域名嗅探、延迟测试 URL 与超时；不得（MUST NOT）暴露 NE 红线项（TUN/DNS/外部控制器）或 iOS 不适用项。延迟测试 URL/超时为 app 侧参数，不写入内核配置而由节点延迟测试直接使用。

#### Scenario: 暴露适用参数
- **当** 查看运行参数设置
- **则** 含运行模式/日志级别/IPv6/统一延迟/TCP 并发/域名嗅探/延迟测试 URL·超时

#### Scenario: 不暴露红线项
- **当** 查看运行参数设置
- **则** 不含 TUN 栈/DNS/外部控制器/核心覆写等项

#### Scenario: 延迟测试参数走 app 侧
- **当** 设置延迟测试 URL 与超时后对节点测延迟
- **则** 测延迟使用该 URL 与超时，且这两项不出现在内核配置正文

### Requirement: 局域网代理共享
应用应当（SHALL）支持局域网代理共享：开启局域网接入（allow-lan）须与混合端口（mixed-port）成对生效，使同网段其它设备可经「本机 IP:端口」用本机为代理网关；关闭时入站仅本机可用。

#### Scenario: 开启局域网共享
- **当** 开启 allow-lan 并设 mixed-port，连接后
- **则** 配置正文含 `allow-lan: true` 与对应 `mixed-port`，入站监听对局域网开放

#### Scenario: 关闭仅本机
- **当** 关闭 allow-lan
- **则** 配置正文 `allow-lan` 为 false，入站不对局域网开放

### Requirement: 升级从订阅配置种子化
首次加载运行参数偏好（尚无持久化偏好）时，必须（MUST）从当前订阅配置读取其顶层运行参数键作为初值，避免默认值覆盖既有用户配置；种子化一次性、幂等。

#### Scenario: 从订阅配置种子化
- **当** 无持久化偏好且当前订阅配置顶层 `mode` 为 global，首次加载
- **则** 运行模式偏好初值为 global（而非默认 rule）

#### Scenario: 种子化幂等
- **当** 已种子化并持久化后再次加载
- **则** 不再从订阅配置覆盖、沿用持久化偏好
