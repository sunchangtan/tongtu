# P0 真机测试操作手册

执行剩余的真机依赖任务（4.3 验证 / 4.5 / 4.6 / 5.2 / 5.3），数据回填至 docs/reports/p0-ios-memory.md。

## 前置准备

### 节点来源（无需真实订阅即可跑满负载内存压测）

压测配置 `core-bridge/testdata/stress-config.yaml` 已内置 60 个占位节点 + 推荐 .mrs 规则集，
撑起「配置规模」内存压力（节点对象 + url-test 健康检查）；出站策略由 PROXY 组首项决定：

| 验证任务 | PROXY 首项 | 节点来源 | 额外准备 |
|----------|-----------|----------|----------|
| 5.2 / 5.3 内存基线、档位扫描 | `DIRECT`（默认） | 直连出站 | 无，开箱即用 |
| 4.6 加密出站冒烟 | `lan-node` | 局域网 Mac 自建 ss | 起 `docs/runbooks/mac-lan-node.yaml` |
| （可选）真实网络复测 | 真实节点 | 你的订阅 | 用真实 proxies 替换占位 node-XX |

> **保真度缺口**：直连出站测不到代理协议的每连接加密缓冲（ss AEAD 约 KB 级/连接，
> 数百并发约差几 MiB）。若 5.2 实测峰值离 50 MiB 门槛仍有充足余量（≤ 45 MiB），
> 该缺口不构成风险；若贴近门槛，再用 4.6 的局域网节点或真实订阅复测峰值。

### 配置注入（环境变量开关，无需手改大字符串）

压测大配置已打包进 App（project.yml 资源引用，单一事实源在 core-bridge/testdata/）。在 Xcode：
1. Product → Scheme → Edit Scheme → Run → Arguments → Environment Variables；
2. 添加 `TONGTU_STRESS = 1`，勾选；连接隧道即加载 stress-config.yaml；
3. 取消勾选则回到内联直连小配置（4.3 数据通路验证用，行为不变）。

### 构建 + 签名

1. **构建内核 + 工程**：
   ```bash
   ./scripts/build-xcframework.sh
   cd ios-poc && xcodegen generate
   ```
2. **签名能力**（DingQi 团队 RSKBV78K2Y，在 Apple Developer 后台确认）：
   - App ID `com.dingqi.tongtu.poc` 与 `.packet-tunnel` 均启用 Network Extensions；
   - App Group `group.com.dingqi.tongtu.poc` 已创建并关联两个 App ID；
   - Xcode 自动签名生成对应 Provisioning Profile。
3. 用 Xcode 打开 `ios-poc/TongtuPoc.xcodeproj`，选 iPhone 17 真机，Run。

## 任务 4.3：TUN 数据通路验证

1. 连接隧道，看扩展日志确认 `tun-fd` 已注入（packetFlow KVC 取 fd 成功）。
2. 分别在 iOS 16 / 17 / 18 设备上重复，记录 KVC 路径是否可用。
3. 若某版本不可用：切换 pipe 桥接备选，量化吞吐/内存差异。
→ 回填报告 §4.3。

## 任务 4.6：端到端加密出站冒烟（局域网自建节点）

1. 同一局域网的 Mac 上起 ss 入站：`mihomo -f docs/runbooks/mac-lan-node.yaml`
   （`brew install mihomo` 或从 release 下载二进制；ss 协议稳定，版本无需与锁定版严格一致）。
2. 改 `stress-config.yaml`：把 `lan-node.server` 改为 Mac 局域网 IP（Mac 上 `ipconfig getifaddr en0`），
   cipher/password 与 mac-lan-node.yaml 一致；再把 PROXY 组首项从 `DIRECT` 改为 `lan-node`。
3. `cd ios-poc && xcodegen generate` 重新构建，`TONGTU_STRESS=1` 连接。
4. 手机浏览器访问网页；在 **Mac 端 mihomo 日志**确认有连接进入并出站，扩展自报指标确认内核 running。
→ 回填报告 §4.3。

## 任务 4.5：启停稳定性

1. 连接→断开，反复 20 次。
2. 每轮后看扩展是否干净退出（Console.app 无残留、主 App 内存读数归零）。
3. 检查端口/句柄泄漏（Instruments File Activity 或 lsof 思路）。
→ 回填报告 §4.2。

## 任务 5.2 + 5.3：内存压测与档位扫描

> 出站模式：用默认配置（PROXY 首项 = DIRECT），流量直连出站，60 占位节点 + url-test
> 健康检查仍驻留内存，承载的是真实「配置规模」内存压力。`TONGTU_STRESS=1` 启用。

对 GOMEMLIMIT ∈ {25, 30, 35} MiB 各跑一轮（改 PacketTunnelProvider.swift 的 `gomemlimit-mib`）：

1. 连接隧道，Instruments 附加扩展进程（Allocations + VM Tracker）。
2. 持续浏览级流量 30 分钟（多标签页轮播视频/网页）。
3. 记录：启动后常驻、30min 常驻、运行峰值、冷启动瞬时峰值。
4. Console.app 过滤 `jetsam` / `memorystatus` 确认无终止事件。
5. 扩展自报指标与 Instruments 数据交叉核对。
→ 回填报告 §4.1，确定推荐默认档位。

## 完成后

> P0 已于 2026-06-13 归档（初步 go）。本手册剩余项现为 **P1 大配置接入前的门控验证**，门槛不变（常驻 < 40 / 峰值 < 50 MiB）。

1. 把常驻/峰值/档位数据回填报告 §4.0（P1 前置验证基线），更新 §6 结论。
2. 回到会话告知结果：
   - 达标（峰值 < 50 MiB）→ 解除 P1 大配置接入门控，继续 P1；
   - 超限 → 启用报告 §5 缓解阶梯（裁 geodata→.mrs/mmdb、关嗅探/统计、降连接表）；仍不达标按 spec 另立 change 重审 P1 方案。
