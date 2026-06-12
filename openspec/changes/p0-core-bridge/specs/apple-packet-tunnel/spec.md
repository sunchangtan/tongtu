# apple-packet-tunnel 能力规格（变更增量）

## ADDED Requirements

### Requirement: 扩展内内核启动
Packet Tunnel Provider 扩展 SHALL 在 `startTunnel` 时加载主 App 传入（或 App Group 共享）的 mihomo YAML 配置，通过 core-bridge 在扩展进程内启动内核，并依据配置完成系统虚拟接口设置（地址、路由、DNS）。

#### Scenario: 从主 App 启动隧道
- **WHEN** 主 App 通过 NETunnelProviderManager 触发连接
- **THEN** 扩展进入 connected 状态，系统 VPN 图标出现，内核 external-controller 在扩展进程内可达

#### Scenario: 配置非法时启动失败
- **WHEN** 传入的 YAML 配置非法
- **THEN** 扩展以可识别的错误结束 startTunnel，主 App 能读取到错误描述（含定位信息）

### Requirement: TUN 数据通路
扩展 SHALL 将 NEPacketTunnelProvider 的虚拟接口与 mihomo 的 TUN 栈对接，使设备真实流量经内核规则分流转发。

#### Scenario: 流量经隧道代理
- **WHEN** 隧道处于 connected 状态且配置包含可用代理节点
- **THEN** 设备发起的 DNS 查询与 TCP/UDP 连接经内核处理，规则命中代理的流量经代理节点出站

### Requirement: 内存指标上报
扩展 SHALL 周期性采集自身内存占用（当前值与峰值），通过 App Group 共享存储暴露给主 App 读取。

#### Scenario: 主 App 读取扩展内存
- **WHEN** 隧道运行中，主 App 查询内存指标
- **THEN** 返回扩展进程的当前内存占用与本次会话峰值，数据新鲜度不超过 10 秒

### Requirement: 停止与资源回收
扩展 SHALL 在 `stopTunnel` 时停止内核并释放资源，保证下次冷启动从干净状态开始。

#### Scenario: 正常停止
- **WHEN** 用户从主 App 或系统设置断开 VPN
- **THEN** 扩展在系统限定时间内完成内核停止并退出，无端口或文件句柄泄漏

### Requirement: iOS 内存可行性验证
P0 MUST 产出真机内存压测报告：在典型订阅场景（≥50 个代理节点 + metacubex 推荐规则集）下，扩展常驻内存 SHALL < 40MiB、运行峰值 SHALL < 50MiB（连续运行 ≥30 分钟不被 jetsam 终止）；报告 MUST 给出 P1 的 go/no-go 结论。

#### Scenario: 典型订阅压测通过
- **WHEN** 在真机（iOS 16+）以典型订阅配置连续运行 30 分钟并施加持续浏览级流量
- **THEN** 内存指标满足常驻 < 40MiB、峰值 < 50MiB，扩展未被系统终止

#### Scenario: 压测不达标的处置
- **WHEN** 任一内存指标不达标且通过配置裁剪仍无法满足
- **THEN** 压测报告记录失败数据与已尝试的缓解手段，标记 no-go 并触发另立 change 重新评审 P1 方案
