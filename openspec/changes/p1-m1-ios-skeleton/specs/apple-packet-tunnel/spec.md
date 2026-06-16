## MODIFIED Requirements

### Requirement: 扩展内内核启动
Packet Tunnel Provider 扩展应当（SHALL）在 `startTunnel` 时加载主 App 经 App Group 写入的运行时 mihomo YAML 配置（由订阅与 metacubex 推荐模板合并生成），通过 core-bridge 在扩展进程内启动内核，并依据配置完成系统虚拟接口设置（地址、路由、DNS）。external-controller 的监听端口与 secret 必须（MUST）由主 App 随机生成并经 Platform Channel 与 App Group 注入，扩展不得（MUST NOT）硬编码固定端口（如 9090）或写死 secret。

#### Scenario: 从主 App 启动隧道
- **当** 主 App 通过 NETunnelProviderManager 触发连接
- **则** 扩展进入 connected 状态，系统 VPN 图标出现，内核 external-controller 以注入的随机端口/secret 在扩展进程内可达

#### Scenario: 配置非法时启动失败
- **当** 传入的 YAML 配置非法
- **则** 扩展以可识别的错误结束 startTunnel，主 App 能读取到错误描述（含定位信息）

#### Scenario: 端口与 secret 经注入而非硬编码
- **当** 扩展启动内核
- **则** external-controller 使用主 App 注入的随机端口与 secret，扩展代码中不存在硬编码的固定端口或写死 secret
