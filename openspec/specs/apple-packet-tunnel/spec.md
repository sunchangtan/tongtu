# apple-packet-tunnel Specification

## Purpose
TBD - created by archiving change p0-core-bridge. Update Purpose after archive.
## Requirements
### Requirement: 扩展内内核启动
Packet Tunnel Provider 扩展应当（SHALL）在 `startTunnel` 时加载主 App 传入（或 App Group 共享）的 mihomo YAML 配置，通过 core-bridge 在扩展进程内启动内核，并依据配置完成系统虚拟接口设置（地址、路由、DNS）。

#### Scenario: 从主 App 启动隧道
- **当** 主 App 通过 NETunnelProviderManager 触发连接
- **则** 扩展进入 connected 状态，系统 VPN 图标出现，内核 external-controller 在扩展进程内可达

#### Scenario: 配置非法时启动失败
- **当** 传入的 YAML 配置非法
- **则** 扩展以可识别的错误结束 startTunnel，主 App 能读取到错误描述（含定位信息）

### Requirement: TUN 数据通路
扩展应当（SHALL）将 NEPacketTunnelProvider 的虚拟接口与 mihomo 的 TUN 栈对接，使设备真实流量经内核规则分流转发。受 iOS 沙盒约束，须满足以下实战修复（来自 demo 经验，2026-06-12）：
- **TUN fd 获取**：私有 KVC `socket.fileDescriptor` 在 iOS 26 返回 nil，必须（MUST）改用扫描进程 fd、以 `getsockopt(SYSPROTO_CONTROL, UTUN_OPT_IFNAME)` 命中 `utun*` 控制 socket 的方式获取 fd（sing-box 同法）。
- **TUN 栈**：iOS 沙盒不允许 `system` 栈 bind tun 地址（`bind: can't assign requested address`），注入外部 fd 时必须（MUST）强制 `gvisor` 用户态栈；xcframework 构建必须（MUST）带 `-tags with_gvisor`，否则报 `gvisor not included in this build`。
- **出站接口**：`auto-detect-interface` 在 NE 沙盒用 socket 探测总命中蜂窝（`pdp_ip0`），必须（MUST）关闭它，由宿主用 `NWPathMonitor` 取真实接口（WiFi 优先）经 `UpdateDefaultInterface` 喂给内核。

#### Scenario: 直连配置下流量经隧道出站
- **当** 隧道处于 connected 状态且使用直连（DIRECT）配置
- **则** 扫描得到 utun fd（非 nil）、内核以 gvisor 栈启动、出站绑定 WiFi 接口，设备可正常打开网页

#### Scenario: 代理配置下流量经代理出站
- **当** 隧道处于 connected 状态且配置包含可用代理节点
- **则** 规则命中代理的流量经代理节点出站

### Requirement: 出站默认接口注入
core-bridge 应当（SHALL）导出 `UpdateDefaultInterface` 接口，宿主可随网络变化更新内核出站绑定的网络接口名；注入外部 tun fd 时内核的 `auto-detect-interface` 必须（MUST）关闭。

#### Scenario: 更新出站接口
- **当** 宿主以 WiFi 接口名调用 UpdateDefaultInterface
- **则** 内核后续出站连接绑定该接口（而非误判的蜂窝接口）

### Requirement: 内存指标上报
扩展应当（SHALL）周期性采集自身内存占用（当前值与峰值），通过 App Group 共享存储暴露给主 App 读取。

#### Scenario: 主 App 读取扩展内存
- **当** 隧道运行中，主 App 查询内存指标
- **则** 返回扩展进程的当前内存占用与本次会话峰值，数据新鲜度不超过 10 秒

### Requirement: 停止与资源回收
扩展应当（SHALL）在 `stopTunnel` 时停止内核并释放资源，保证下次冷启动从干净状态开始。

#### Scenario: 正常停止
- **当** 用户从主 App 或系统设置断开 VPN
- **则** 扩展在系统限定时间内完成内核停止并退出，无端口或文件句柄泄漏

### Requirement: iOS 内存可行性验证
P0必须（MUST）产出真机内存压测报告：在典型订阅场景（≥50 个代理节点 + metacubex 推荐规则集）下，扩展常驻内存应当 < 40MiB、运行峰值应当 < 50MiB（连续运行 ≥30 分钟不被 jetsam 终止）；报告必须给出 P1 的 go/no-go 结论。

#### Scenario: 典型订阅压测通过
- **当** 在真机（iOS 16+）以典型订阅配置连续运行 30 分钟并施加持续浏览级流量
- **则** 内存指标满足常驻 < 40MiB、峰值 < 50MiB，扩展未被系统终止

#### Scenario: 压测不达标的处置
- **当** 任一内存指标不达标且通过配置裁剪仍无法满足
- **则** 压测报告记录失败数据与已尝试的缓解手段，标记 no-go 并触发另立 change 重新评审 P1 方案

