# P0 iOS 内存可行性报告

- 状态：⏳ 待真机数据填充（方法学已就绪）
- 关联：openspec/changes/p0-core-bridge（specs/apple-packet-tunnel「iOS 内存可行性验证」）
- 验收门槛：扩展常驻 < 40MiB、运行峰值 < 50MiB、连续 30 分钟不被 jetsam 终止

## 1. 背景

iOS 16+ NE 扩展受 jetsam 50MiB 硬限额（Apple 官方确认，超限即杀进程）。本报告用真机数据回答：
官方 mihomo 内核在该限额内能否以典型订阅配置稳定运行——这是 P1 iOS MVP 的 go/no-go 前提。

## 2. 被测对象

| 项目 | 值 |
|------|-----|
| 内核 | 官方 mihomo v1.19.27（gomobile c-archive，静态链接进 NE 扩展）|
| 内存防护 | GOMEMLIMIT（扫描档）、GOGC=30、geodata-loader=memconservative、FreeOSMemory 30s 定时器 |
| 压测配置 | core-bridge/testdata/stress-config.yaml（60 节点 + metacubex 推荐 .mrs 规则集）|
| 验证 App | ios-poc（TongtuPoc + PacketTunnel 扩展）|
| 测试机型 | iPhone 17（iPhone18,3），iOS 26.4.1 |

## 3. 测试方法

按 docs/runbooks/p0-device-test.md 执行，三项数据交叉验证：
1. **扩展自报指标**：扩展每 5s 写入 App Group，主 App 读 totalSys（MihomocoreMemoryStats）。
2. **Xcode Instruments**：Allocations / VM Tracker 附加到扩展进程，读 Persistent Bytes 与 Footprint。
3. **系统日志**：Console.app 过滤 jetsam，确认无 `memorystatus` 终止事件。

## 3.5 模拟器预验证（2026-06-12，iPhone 16 Pro / iOS 18）

在投入真机前，先用模拟器把"软件链路正确性"与"真机硬件特性"分离验证。结论：

| 验证项 | 结果 | 证据 |
|--------|------|------|
| 工程构建（链接真实 mihomo xcframework）| ✅ | 模拟器 SDK `BUILD SUCCEEDED` |
| 扩展打包进 .app | ✅ | `TongtuPoc.app/PlugIns/PacketTunnel.appex` |
| App 启动 + UI 渲染（中文）| ✅ | 截图：标题/状态/内存读数/按钮正常 |
| TunnelManager NE 设置代码正确性 | ✅ | 自动连接走到 `saveToPreferences`，收到结构化 `NEVPNErrorDomain Code=5` |
| 隧道建立 + 内核在扩展进程内启动 | ⛔ 模拟器不支持 | `Failed to save configuration: NEVPNErrorDomain Code=5 "IPC failed"`（模拟器无 NE 守护进程，Apple 已知限制）|
| 扩展无 entitlement（免签名构建）| ⚠️ 真机须配齐 | `PacketTunnel.appex ... had no entitlements` |

**含义**：软件链路在 OS 边界前全部正确；隧道建立、内核启动、内存数值、packetFlow fd KVC 这些**只能在真机验证**（NEVPNErrorDomain Code=5 是模拟器的硬限制，非代码缺陷）。这把真机验证收窄到纯硬件相关项。

## 4. 数据

### 4.0 真机空载基线（2026-06-12，iPhone 17 / iOS 26.4.1）✅

| 验证项 | 结果 | 证据 |
|--------|------|------|
| 内核在 NE 扩展进程内启动 | ✅ | app 内核启动行：「✅ 内核已启动 tunFD=<有效> 状态=running」|
| TUN fd KVC 注入（iOS 26）| ✅ | tunFD 取得且非 -1，内核以该 fd 启动 running（D3 的 KVC 路径在 iOS 26 可用）|
| 空载常驻内存（仅内核 + demoConfig，无真实节点/流量/大规则集，GOMEMLIMIT=30）| **< 25 MiB** | app 扩展内存读数 |
| jetsam 终止 | 未发生 | 状态保持 running |

**解读**：在 50MiB jetsam 限额下，空载基线 < 25 MiB，常驻门槛（40MiB）有 ≥15 MiB 余量、峰值门槛（50MiB）有 ≥25 MiB 余量。这是强 go 信号——但**完整结论须叠加真实订阅负载**（60+ 节点 + 推荐 .mrs 规则集 + 30 分钟流量）后的常驻/峰值数据，见下。

### 4.0b 数据通路真机验证（2026-06-13，iPhone 17 / iOS 26，直连配置）✅

修复 demo 实战暴露的 4 个 iOS 沙盒坑后，TUN 数据通路端到端打通：

| 问题 | 根因 | 修复 | 真机结果 |
|------|------|------|---------|
| 6 无法获取 tun fd | iOS 26 私有 KVC `socket.fileDescriptor` 返回 nil | 扫描 fd + `getsockopt(SYSPROTO_CONTROL,UTUN_OPT_IFNAME)` 找 utun（PacketTunnel/TunFD.swift）| ✅ tunFD=正数 |
| 7 连上打不开网页 | `stack: system` 在沙盒无法 bind tun 地址 | 注入 fd 时强制 gvisor 用户态栈（core.go buildRawConfig）| ✅ |
| 8 gvisor not included | gomobile bind 默认不带 gvisor | 构建加 `-tags with_gvisor`（build-xcframework.sh）| ✅ 内核启动无报错 |
| 9 WiFi 下走蜂窝 | `auto-detect-interface` 沙盒探测误判 pdp_ip0 | 关闭它，NWPathMonitor 取 WiFi 接口经 UpdateDefaultInterface 注入（InterfaceMonitor.swift）| ✅ |

**验收**：直连（DIRECT）配置下，Safari 可正常打开网页——证明 TUN→内核→出站 全链路工作。这是比代理配置更纯的数据通路验证（不依赖订阅节点）。任务 4.6 的数据通路部分由此达成；代理节点变体仅多一跳代理出站，待负载压测时一并覆盖。

### 4.1 GOMEMLIMIT 档位扫描（任务 5.3，design 开放问题 3）⏳ 待真实节点压测

| GOMEMLIMIT | 启动后常驻 | 30min 常驻 | 运行峰值 | 冷启动瞬时峰值 | jetsam 终止 | 备注 |
|-----------|-----------|-----------|---------|--------------|-----------|------|
| 25 MiB | — | — | — | — | — | |
| 30 MiB | <25（空载）/ 25–35（直连+fakeip轻负载）| — | — | — | 否 | 基线与轻负载已测；大规则集/代理节点负载待补 |
| 35 MiB | — | — | — | — | — | |

### 4.2 启停稳定性（任务 4.5）

- 反复启停 20 次：句柄/端口泄漏（待填）、冷启动状态是否干净（待填）。

### 4.3 端到端冒烟（任务 4.6）

- packetFlow KVC 取 fd 在 iOS __ 上：可用 / 不可用（待填）。
- 浏览器流量是否经代理出站（待填）。
- 若 KVC 路径不可用，pipe 桥接备选的吞吐/内存差异（待填）。

## 5. 缓解手段记录（按需启用）

执行顺序（spec 风险缓解阶梯）：
1. 调低 GOMEMLIMIT 档位；
2. 规则集 .mrs 化并裁剪类别、geoip 用 mmdb（mmap）；
3. 关闭嗅探/统计类功能；
4. 降低并发连接表上限。

## 6. 结论

**初步结论：倾向 go（待负载压测最终确认）**

已确凿验证（真机 iPhone 17 / iOS 26.4.1）：
1. 官方 mihomo v1.19.27 内核能在 iOS NE Packet Tunnel 扩展进程内启动并稳定 running；
2. gomobile xcframework → 静态链接进扩展 → 内核启动 全链路在真机打通；
3. D3 的 packetFlow KVC 取 fd 路径在 iOS 26 可用，tun-fd 注入生效；
4. 空载常驻 < 25 MiB，距 40/50 MiB 门槛有充足余量。

**最终 go/no-go 待补的负载数据**（需真实订阅节点）：
- [ ] 60+ 节点 + 推荐 .mrs 规则集 + 30 分钟浏览级流量下的常驻/峰值（任务 5.2）；
- [ ] GOMEMLIMIT 25/30/35 档位扫描确定默认值（任务 5.3）；
- [ ] 真实流量经代理出站冒烟（任务 4.6）。

若负载数据仍满足门槛 → 正式 go，归档 P0、进入 P1；若超限 → 启用 §5 缓解阶梯，仍不达标则触发 P1 重审。

> 空载基线如此宽裕（<25/50），负载压测翻车概率较低，但 geodata/规则集全量加载是已知内存压力源，必须实测确认，不能外推。
