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
| 测试机型 | （待填：iPhone 17 / iPhone 14 Pro 等，iOS 版本）|

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

## 4. 数据（待填充）

### 4.1 GOMEMLIMIT 档位扫描（任务 5.3，design 开放问题 3）

| GOMEMLIMIT | 启动后常驻 | 30min 常驻 | 运行峰值 | 冷启动瞬时峰值 | jetsam 终止 | 备注 |
|-----------|-----------|-----------|---------|--------------|-----------|------|
| 25 MiB | — | — | — | — | — | |
| 30 MiB | — | — | — | — | — | |
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

## 6. 结论（待数据后填写）

- [ ] **go**：≥1 个 GOMEMLIMIT 档位满足全部门槛 → 推进 P1，记录推荐默认档位。
- [ ] **no-go**：全部档位 + 缓解手段仍超限 → 按 spec 触发 P1 重审 change，记录失败数据与已尝试手段。
