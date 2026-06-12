# 通途（Tongtu）总体架构设计文档

- 版本：v1.0
- 日期：2026-06-12
- 状态：已确认（方案经用户评审通过）
- 项目名称：通途（Tongtu）——「一桥飞架南北，天堑变通途」；国际化名用拼音 Tongtu（已验证代理/VPN 领域无撞名，2026-06-12）

## 1. 项目概述

基于 Flutter + Mihomo(Clash.Meta) 内核的跨平台代理工具，对齐 clashmi 公开功能集，且**全栈可从源码构建**（clashmi 的内核封装层闭源，这是本项目的核心差异化）。

| 项目 | 决策 |
|------|------|
| 平台范围 | iOS/iPadOS、macOS、Windows、Linux、Android（iOS 优先交付） |
| 内核 | 官方仓库 `MetaCubeX/mihomo`（不 fork、不打私有补丁） |
| 配置 | mihomo 原生 YAML，兼容 metacubex 推荐配置（wiki.metacubex.one） |
| 面板 | zashboard（内嵌 WebView 为主，Linux 降级外部浏览器） |
| 按需连接 | iOS/iPadOS/macOS 系统级（NEOnDemandRule）；Windows/Linux 应用层模拟 |
| 发布 | 公开发布，iOS/macOS 上架 App Store（海外区） |
| 许可 | GPL-3.0 开源（与 mihomo/FlClash 一致） |
| UI 参照 | KaringX/clashmi（仅设计参照，不复制其代码） |

## 2. 调研核实的关键事实（2026-06-12）

1. **clashmi 不可 fork 二开**：Flutter UI 开源（GPL-3.0），但内核封装层 `libclash-vpn-service`、`board-service` 为私有仓库，公开源码不可完整构建。
2. **iOS 集成路径唯一**：VPN 必须在 NetworkExtension Packet Tunnel Provider 扩展进程内运行；mihomo 以 gomobile/cgo `c-archive` 编译为 xcframework 静态链接进扩展。iOS 禁止子进程，主 App 的 dart:ffi 无法跨进程调用扩展内内核。
3. **iOS 16+ 扩展内存上限 50 MiB**（Apple 官方论坛 Quinn 确认，thread/73148），超限被 jetsam 杀进程；历史上限额变过（iOS 15 前为 15 MiB），不可硬编码。全项目最大技术风险。
4. **按需连接**：`NETunnelProviderManager` 继承 `NEVPNManager` 的 `isOnDemandEnabled`/`onDemandRules`，第三方 Packet Tunnel 完全支持；规则类型 Connect/Disconnect/Ignore/EvaluateConnection，匹配维度含 SSID、DNS 搜索域、DNS 服务器、接口类型、探测 URL。iOS 8+/macOS 10.11+。
5. **Linux 无系统级按需连接**：NEOnDemandRule 为苹果独有；Windows 的 Name-based AutoTrigger 仅限系统内置 VPN 栈（Wintun 类工具用不上）。两平台均为应用层模拟。
6. **macOS App Store 分发 → NE app extension 形态**（TN3134）：无需 system extension、无需用户在安全设置批准，与 iOS 代码高度复用。
7. **zashboard**：Vue 3 静态面板，走 mihomo `external-controller` RESTful API + WebSocket；可由内核 `external-ui` 自托管。
8. **TN3120 合规**：Packet Tunnel 的认可用途为真实 VPN 隧道，上架描述需规范撰写。

## 3. 总体架构

```
┌─────────────────────────────────────────────────────┐
│              Flutter 主应用（Dart，五平台共享）          │
│  UI层(参照clashmi) · 配置/订阅管理 · zashboard WebView  │
│         统一内核控制抽象层 CoreController(Dart)         │
└──────────┬──────────────────────────┬───────────────┘
           │ Platform Channel          │ RESTful API + WS
┌──────────▼──────────┐    ┌──────────▼──────────────┐
│ 苹果/Android 原生层    │    │ mihomo external-controller│
│ NEVPNManager(Swift)  │    │ (127.0.0.1, 全平台统一)    │
│ VpnService(Kotlin)   │    └──────────▲──────────────┘
└──────────┬──────────┘               │
┌──────────▼───────────────────────────┴───────────────┐
│                    mihomo 内核层                       │
│ iOS/macOS: xcframework 静态链接进 NE 扩展 (gomobile)    │
│ Android:   cgo .so + VpnService fd 传递               │
│ Win/Linux: 官方二进制子进程 + 提权服务(TUN)              │
└──────────────────────────────────────────────────────┘
```

运行时交互五平台统一走 `external-controller`（127.0.0.1 + 随机端口 + 随机 secret）：节点切换、延迟测试、流量/日志/连接监控复用同一套 Dart API 客户端，zashboard 直接使用同一接口。

## 4. 各平台内核生命周期

| 平台 | 内核形态 | TUN/VPN | 提权 | 按需连接 |
|------|---------|---------|------|---------|
| iOS/iPadOS | xcframework 静态链接进 NE 扩展 | NEPacketTunnelProvider | 无需 | 系统级 NEOnDemandRule |
| macOS（App Store） | 同上，app extension 形态 | 同上 | 无需 | 系统级 NEOnDemandRule |
| Windows | 官方二进制子进程 | wintun（经提权服务） | 一次性安装 Windows 服务（SYSTEM） | 应用层：服务自启 + 网络事件监听 |
| Linux | 官方二进制子进程 | TUN（经 systemd 服务） | pkexec 一次性安装 systemd 单元 | 应用层：systemd 自启 + dispatcher/netlink 联动 |
| Android（二期） | cgo .so（CMFA 模式） | VpnService + fd 传递 | 无需 | Always-on VPN（系统设置） |

## 5. 内核来源与更新策略（用户明确要求）

- `core-bridge` 的 `go.mod` 直接依赖官方 module `github.com/metacubex/mihomo`，跟踪官方 release tag。
- 桌面端子进程二进制直接使用官方 GitHub Releases 产物；App 内一键热更新内核，下载后校验哈希。
- 如确需补丁：`go.mod replace` + 补丁文件管理，优先提交上游，不维护长期 fork。
- CI 定期检查上游新 tag，自动构建 xcframework/aar 并跑回归。

## 6. 配置与订阅设计

- 原生消费 mihomo YAML；订阅 = `proxy-providers`，规则 = `rule-providers`（`.mrs` 优先）。
- 内置「metacubex 推荐配置」模板（DNS fake-ip、geodata、TUN、嗅探等按官方 wiki 推荐值）；用户配置 = 模板 + 用户覆写（override）合并生成运行时 YAML，不做私有格式转换，保证与上游 100% 兼容。
- iOS 模板内置内存保护参数：`GOMEMLIMIT`≈30MiB、`GOGC` 调低、`geodata-loader: memconservative`、定期 `FreeOSMemory()`；导入超大规则集时警告。

## 7. 模块划分

```
tongtu/
├── lib/
│   ├── core/                   # 统一内核控制抽象 CoreController
│   │   ├── core_controller.dart        # 接口：start/stop/reload/状态流
│   │   ├── apple_core_controller.dart  # NEVPNManager 经 Platform Channel
│   │   ├── desktop_core_controller.dart# 子进程管理 + 提权服务 IPC
│   │   └── clash_api.dart              # external-controller REST/WS 客户端
│   ├── config/                 # YAML 配置/订阅/override 管理
│   ├── ondemand/               # 按需连接规则模型（统一 UI 模型，分平台落地）
│   ├── ui/                     # 页面（参照 clashmi）
│   └── dashboard/              # zashboard WebView 封装 + Linux 降级
├── ios/ macos/                 # Runner + PacketTunnel 扩展（Swift）
├── core-bridge/                # Go 模块：mihomo 封装，gomobile 构建 xcframework/aar
├── android/                    # VpnService（二期）
├── windows/ linux/             # 子进程 + 提权服务
├── openspec/                   # OpenSpec 规格与变更（开发流程主导）
└── docs/                       # 设计/进度文档
```

## 8. 错误处理与可观测性

- 内核启动失败：YAML 校验错误定位到行；端口冲突自动重试随机端口；扩展被 jetsam 杀死时主 App 收到状态回调并提示「配置过大」。
- 桌面子进程崩溃：指数退避自动重启，3 次后停止并提示；提权服务不可用时降级「系统代理模式」（不开 TUN）。
- 日志：内核日志经 WebSocket 流入 App 日志页 + 滚动文件。

## 9. 测试策略

- Dart 单元测试：配置合并/override、订阅解析、API 客户端（mock HTTP）。
- Go 侧：core-bridge 接口测试。
- 集成测试：每平台真机冒烟清单（连接建立、节点切换、按需触发、面板可达）。
- iOS 专项：Xcode Instruments 内存压测，验证典型订阅场景扩展常驻 < 40MiB。

## 10. 风险清单

| 风险 | 等级 | 缓解 |
|------|------|------|
| iOS NE 50MiB 内存 | 🔴 高 | P0 第一周端到端内存验证，先验证再铺开 |
| App Store 审核（区域限制、TN3120） | 🟡 中 | 海外区账号；描述按规范撰写 |
| GPL-3.0 与 App Store 兼容争议 | 🟡 中 | 全项目 GPL-3.0 开源，接受先例性风险 |
| gomobile 与新 Go 版本兼容 | 🟡 中 | 锁定 Go 版本随 mihomo 上游 CI 对齐 |
| Linux WebView 不成熟 | 🟢 低 | 已决策降级外部浏览器 |

## 11. 阶段路线图（每阶段一个 OpenSpec change，独立走完整流程）

| 阶段 | 内容 | 预估 |
|------|------|------|
| **P0** | core-bridge：mihomo xcframework 构建管线 + 最小 NE Demo 验证 iOS 内存可行性 | 2-3 周 |
| **P1** | iOS/iPadOS MVP：Flutter 主 App + NE + 按需连接 + zashboard | 4-6 周 |
| **P2** | macOS（App Store appex）+ UI 完善（clashmi 参照全量页面） | 3-4 周 |
| **P3** | Windows：子进程 + 服务模式 TUN + 内核热更新 | 3-4 周 |
| **P4** | Linux：子进程 + systemd/pkexec + 按需模拟 + 面板降级 | 2-3 周 |
| **P5** | Android：VpnService + cgo .so | 3-4 周 |

## 12. 开发流程约定

- **OpenSpec** 主导规格管理：每阶段一个 change（proposal → specs → design → tasks → apply → archive），`openspec/specs/` 为系统能力的当前事实。
- **Superpowers** 主导执行纪律：brainstorming（已完成）→ writing-plans/tasks → TDD 实施 → verification-before-completion → code review。
- 全程中文交流与注释；每个任务完成更新进度文档（CLAUDE.md v6.0 流程）。
- **文档语言约定**：OpenSpec/Superpowers 生成的全部文档（proposal/design/specs/tasks/报告）一律使用中文。唯一例外是 OpenSpec CLI 的硬解析关键字必须保留英文：specs 增量文件的 `## ADDED/MODIFIED/REMOVED/RENAMED Requirements`、`### Requirement:`、`#### Scenario:` 标头，以及每条需求正文须含字面量 `SHALL`/`MUST`（写法：中文规范词后括注，如「必须（MUST）」「应当（SHALL）」）；tasks.md 的 `- [ ] X.Y` 复选框格式同为解析约定。

## 13. 文档版本记录

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0 | 2026-06-12 | 初版：完整架构方案（经用户评审确认，含「官方仓库内核」补充决策） |
| v1.1 | 2026-06-12 | 新增文档语言约定（§12）；项目定名「通途（Tongtu）」并全文统一 |
