## Why

通途当前把订阅 URL 包装成**单一 proxy-provider**（`runtime_config.dart`），假设订阅返回纯 `proxies` 列表；但实际订阅（subconverter `target=clash` 及多数机场/自建订阅）返回的是**完整 clash 主配置**——无顶层 `proxies` 字段，节点在其内部嵌套的 `proxy-providers` 里。mihomo 的 proxy-provider 解析该文件时报错 `file must have a 'proxies' field`，解析出 **0 节点** → PROXY 组只剩 COMPATIBLE → 流量无处可走，即用户反馈的「连上了但没走 vpn」。

已用 mihomo 内核**双向实跑坐实**（与真机无关，纯配置层）：当前「订阅当 proxy-provider」= 0 节点（内核报上述错误）；改为「订阅当完整主配置」= 内核运行时下载嵌套 provider，解析出 143 个真实节点。

## What Changes

- **BREAKING**（修订 m1 尚未 archive 的需求）：订阅消费模型从「订阅 URL = 单一 proxy-provider 源」改为「订阅 URL = 完整 clash 主配置」，与主流 clash 客户端（FlClash / clashmi）一致。
- 订阅获取保留**完整响应正文**（不再只取 `subscription-userinfo` 头丢弃 body），作为内核主配置来源。
- 废弃 `runtime_config` 的 proxy-provider 包装；改为以订阅完整配置为基础，由内核侧覆写注入运行参数。
- 订阅自带的 `proxy-providers` / `proxy-groups` / `rules` / `rule-providers` **原样保留**，交内核运行时下载解析。
- 内核侧（`core.go`）在 TUN 模式下**覆写注入 DNS fake-ip 增强模式与 `tun.dns-hijack`**，保证 TUN 捕获的 DNS 查询正常解析（FlClash / clashmi 一致做法：TUN 必须 fake-ip）。
- `external-controller` / `secret` / `tun-fd` 覆写沿用现有 `coreOverrides` 机制（随机端口、强制覆盖订阅自带的 controller）。

## Capabilities

### New Capabilities

（无）

### Modified Capabilities

- `subscription-config`: 修订「订阅链接导入」与「运行时配置生成」——订阅作为**完整 clash 主配置**消费：下载保留完整正文、原样保留嵌套 providers、交内核覆写注入后启动；不再包装为单一 proxy-provider，不再以模板合并方式生成配置。
- `core-bridge`: 扩展「控制接口注入」——在 TUN 模式（`tun-fd > 0`）下，覆写注入 DNS（`enhanced-mode: fake-ip` + `fake-ip-range` + nameserver）与 `tun.dns-hijack`，与订阅自带 DNS/TUN 配置协调，保证 TUN 数据通路的域名解析可用。

## Impact

- **代码**：`lib/config/subscription.dart`（`fetch` 保留 body）、`lib/ui/home_page.dart`（以完整配置正文作为 `configYAML`）、`lib/config/runtime_config.dart`（废弃 proxy-provider 包装）、`core-bridge/mihomocore/core.go`（DNS / dns-hijack 覆写）。
- **测试**：订阅完整配置消费（Dart）、`core.go` DNS 覆写单测（Go）、真机数据面验证（节点出现、实际走代理、DNS 正常）。
- **依赖**：无新增。
- **关联与 archive 顺序**：本 change 修订 `p1-m1-ios-skeleton`（未 archive）的 `subscription-config` 需求；archive 顺序须在 m1 之后（详见 design.md「与 m1 的关系」）。
