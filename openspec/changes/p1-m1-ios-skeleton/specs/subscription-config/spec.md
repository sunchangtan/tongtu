## ADDED Requirements

### Requirement: 订阅链接导入
主应用应当（SHALL）支持以订阅链接导入代理配置，消费 mihomo 原生 proxy-providers，不发明私有订阅格式。

#### Scenario: 导入有效订阅链接
- **当** 用户粘贴有效的订阅链接并确认导入
- **则** 应用保存该订阅并据其生成可用的运行时配置

#### Scenario: 导入无效链接
- **当** 订阅链接无法访问或内容非法
- **则** 应用给出可读的中文错误提示，不写入损坏的配置

### Requirement: 运行时配置生成
应用应当（SHALL）以 metacubex 推荐模板为基础，合并用户 override 与订阅 proxy-providers，生成 mihomo 原生 YAML 运行时配置，与官方 wiki 推荐配置兼容，不做私有格式转换。

#### Scenario: 模板与订阅合并
- **当** 已存在订阅且触发连接
- **则** 应用生成包含 proxy-providers、DNS/TUN/内存防护等推荐项的运行时 YAML，并经 App Group 提供给扩展

### Requirement: 控制接口凭据随机化
应用应当（SHALL）为每次运行随机生成 external-controller 的监听端口与 secret，经 Platform Channel 与 App Group 注入扩展；不得（MUST NOT）使用硬编码的固定端口或写死的 secret。

#### Scenario: 生成并注入随机端口与 secret
- **当** 应用准备启动隧道
- **则** 生成随机端口与 secret 并注入扩展，内核 external-controller 以该端口与 secret 启动
