# P0 真机测试操作手册

执行剩余的真机依赖任务（4.3 验证 / 4.5 / 4.6 / 5.2 / 5.3），数据回填至 docs/reports/p0-ios-memory.md。

## 前置准备

1. **真实订阅节点**：把可用订阅的代理节点填入压测配置。
   - 复制 `core-bridge/testdata/stress-config.yaml` 为本地副本（勿入库，含真实节点）；
   - 用真实 `proxies` / `proxy-providers` 替换占位 `node-XX`，保留规则集结构。
2. **构建内核 + 工程**：
   ```bash
   ./scripts/build-xcframework.sh
   cd ios-poc && xcodegen generate
   ```
3. **签名能力**（DingQi 团队 RSKBV78K2Y，在 Apple Developer 后台确认）：
   - App ID `com.dingqi.tongtu.poc` 与 `.packet-tunnel` 均启用 Network Extensions；
   - App Group `group.com.dingqi.tongtu.poc` 已创建并关联两个 App ID；
   - Xcode 自动签名生成对应 Provisioning Profile。
4. 用 Xcode 打开 `ios-poc/TongtuPoc.xcodeproj`，选 iPhone 17 真机，Run。

> 注：PoC 的 demoConfig（TunnelManager.swift）仅启动内核不接节点。压测时把
> 本地真实订阅 YAML 写入 App Group（可临时改 TunnelManager.demoConfig 指向真实配置）。

## 任务 4.3：TUN 数据通路验证

1. 连接隧道，看扩展日志确认 `tun-fd` 已注入（packetFlow KVC 取 fd 成功）。
2. 分别在 iOS 16 / 17 / 18 设备上重复，记录 KVC 路径是否可用。
3. 若某版本不可用：切换 pipe 桥接备选，量化吞吐/内存差异。
→ 回填报告 §4.3。

## 任务 4.6：端到端冒烟

1. 用真实节点配置连接，手机浏览器访问需代理的站点。
2. 在 zashboard 或 /connections 确认流量经代理节点出站。
→ 回填报告 §4.3。

## 任务 4.5：启停稳定性

1. 连接→断开，反复 20 次。
2. 每轮后看扩展是否干净退出（Console.app 无残留、主 App 内存读数归零）。
3. 检查端口/句柄泄漏（Instruments File Activity 或 lsof 思路）。
→ 回填报告 §4.2。

## 任务 5.2 + 5.3：内存压测与档位扫描

对 GOMEMLIMIT ∈ {25, 30, 35} MiB 各跑一轮（改 PacketTunnelProvider.swift 的 `gomemlimit-mib`）：

1. 连接隧道，Instruments 附加扩展进程（Allocations + VM Tracker）。
2. 持续浏览级流量 30 分钟（多标签页轮播视频/网页）。
3. 记录：启动后常驻、30min 常驻、运行峰值、冷启动瞬时峰值。
4. Console.app 过滤 `jetsam` / `memorystatus` 确认无终止事件。
5. 扩展自报指标与 Instruments 数据交叉核对。
→ 回填报告 §4.1，确定推荐默认档位。

## 完成后

1. 填写报告 §6 的 go/no-go 结论。
2. 回到会话告知结果，我据此：
   - go → 勾选 4.3/4.5/4.6/5.2/5.3/5.4，`openspec archive p0-core-bridge`，进入 P1；
   - no-go → 按 spec 触发 P1 重审 change。
