# 设计：p0-core-bridge

## 背景

全项目总体架构见 [docs/design/architecture.md](../../../docs/design/architecture.md)（v1.0，已评审）。P0 是其中第一阶段：在投入 Flutter UI 前，先打通「官方 mihomo → Go 封装 → xcframework → iOS NE 扩展」链路，并在真机上用数据回答"50 MiB 限额内 mihomo 是否可行"。

约束：
- 内核 MUST 来自官方 `MetaCubeX/mihomo`（用户明确要求，不 fork）。
- iOS 禁止子进程，内核只能静态链接进 NE 扩展进程；扩展受 jetsam 50 MiB 限额（iOS 16+）。
- 已具备付费 Apple 开发者账号（Network Extension entitlement 可用）。

## 目标 / 非目标

**目标：**
- 可复现的 `MihomoCore.xcframework` 构建管线（iOS/iOS Sim/macOS 切片）。
- 扩展进程内内核可启动、可代理真实流量、可停止，生命周期接口跨平台语义统一。
- 内存防护参数体系 + 内存指标采集，真机压测报告与 go/no-go 结论。

**非目标：**
- Flutter 主 App、完整 UI（P1）；按需连接规则 UI（P1）；zashboard 集成（P1）。
- macOS appex 打包（P2，但 xcframework 须包含 macOS 切片为其铺路）。
- Android aar 构建（P5）；桌面子进程管理（P3/P4）。

## 关键决策

### D1：gomobile bind 而非手写 cgo c-archive
用 `gomobile bind -target=ios,iossimulator,macos` 生成 xcframework：自动处理 Objective-C 绑定、切片合并与模块映射，是 karing/sing-box 系（libbox）验证过的成熟路径。备选的手写 `go build -buildmode=c-archive` + 手工 lipo/xcodebuild 灵活但维护成本高，仅在 gomobile 遇到阻塞性 bug 时降级使用。

### D2：绑定接口走「粗粒度 JSON 字符串」而非细粒度对象映射
gomobile 的类型映射限制多（无 slice/map 直传）。导出接口收敛为少量函数：`Start(configYAML, overridesJSON) error`、`Stop()`、`Reload(configYAML) error`、`State() string`、`MemoryStats() string(JSON)`，复杂结构一律 JSON 序列化。降低绑定层脆弱性，也方便未来 Kotlin/Dart 复用同一协议。

### D3：TUN 对接采用「内核 TUN 栈 + fd 注入」
mihomo 的 sing-tun 栈支持从已打开的 tun fd 工作。扩展内通过 `NEPacketTunnelProvider` 的 packetFlow 拿不到原始 fd 的公开 API，但社区验证过的做法是从 `packetFlow.value(forKeyPath:)` 获取 fd 或用双向 pipe 桥接；P0 先用 fd 路径（性能最优），若 App Store 审核风险评估认为 KVC 取 fd 不可接受，再切换 pipe 桥接（性能损耗可测）。此项列入 Open Questions 验证。

### D4：内存防护默认值集中在 core-bridge 而非调用方
`GOMEMLIMIT`/`GOGC`/`memconservative`/`FreeOSMemory` 定时器全部在 Go 侧 Start 流程内应用（调用方可覆写）。理由：防护必须先于内核初始化生效，且五平台共用一份实现，避免每个宿主重复实现遗漏。

### D5：P0 验证 App 用纯 Xcode 工程而非 Flutter
P0 的考察对象是扩展进程（Flutter 不进扩展），主 App 只需要一个连接按钮和内存读数。纯 Swift 工程隔离变量、缩短编译链路；Flutter 主 App 留到 P1，届时此验证 App 退役为开发调试工具。

### D6：压测配置固化为仓库内 fixture
典型订阅场景（≥50 节点 + 推荐规则集）以脱敏 YAML fixture 形式入库，保证压测可重复、报告数据可对比；真实订阅仅本地临时使用，不入库。

## 风险与权衡

- [50 MiB 内存不可行] → 缓解阶梯：裁剪 geodata（.mrs/mmdb 化）→ 关闭嗅探/统计类功能 → 降低并发连接表上限；全部失败则标记 no-go，另立 change 重审 P1（产品上可能转向「精简规则模式」）。
- [gomobile 与 mihomo 依赖的新 Go 特性冲突] → Go 版本锁定为 mihomo 上游 CI 使用的版本；gomobile 失败时降级 D1 备选路径。
- [KVC 取 tun fd 被审核拒绝或系统版本失效] → D3 的 pipe 桥接备选；P0 即测两条路径的内存/吞吐差异，留下数据。
- [扩展冷启动峰值超限（按需连接场景会频繁冷启动）] → 压测项包含冷启动瞬时峰值采样；配置加载改为惰性/分段。

## 迁移计划

Greenfield，无迁移。回滚 = 丢弃 P0 产物，不影响任何现有系统。P0 结论（go/no-go）决定 P1 change 的前提。

## 待解问题

- packetFlow 取 fd 的 KVC 路径在目标 iOS 版本（16–18+）上是否全部可用？（P0 任务中实测）
- gomobile 产物的二进制体积（影响 App 包大小与审核）具体多大？（构建后记录）
- `GOMEMLIMIT` 最优默认值是 25/30/35MiB 中的哪档？（压测中扫描确定）
