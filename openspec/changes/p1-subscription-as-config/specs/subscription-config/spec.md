## MODIFIED Requirements

### Requirement: 订阅链接导入
主应用应当（SHALL）支持以订阅链接导入代理配置，下载并保留订阅返回的**完整 clash 配置正文**作为内核主配置来源，消费 mihomo 原生 YAML，不发明私有订阅格式。

#### Scenario: 导入有效订阅链接
- **当** 用户粘贴有效的订阅链接并确认导入
- **则** 应用下载并保留完整配置正文、解析 `subscription-userinfo` 流量信息，并保存订阅

#### Scenario: 导入无效链接
- **当** 订阅链接无法访问，或返回内容非合法 clash 配置（既无 `proxies` 也无 `proxy-providers`）
- **则** 应用给出可读的中文错误提示，不写入损坏的配置

### Requirement: 运行时配置生成
应用应当（SHALL）以订阅下载的**完整 clash 配置正文**作为内核主配置，原样保留其 `proxy-providers`/`proxy-groups`/`rules`/`rule-providers`，由内核侧覆写注入运行参数后启动；不得（MUST NOT）将订阅包装为单一 proxy-provider，也不得以模板合并方式重新生成配置。

#### Scenario: 以订阅完整配置启动
- **当** 已存在订阅且触发连接
- **则** 应用将订阅完整配置正文作为 `configYAML` 传入内核，内核解析并运行时下载其中的 `proxy-providers`，代理组获得真实节点（非仅 COMPATIBLE）

#### Scenario: 订阅含嵌套 proxy-providers
- **当** 订阅配置内含指向远程的 `proxy-providers`
- **则** 应用原样保留并交内核运行时下载，不展开、不改写其结构
