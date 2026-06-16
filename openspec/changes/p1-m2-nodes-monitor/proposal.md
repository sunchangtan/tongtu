# 变更提案：p1-m2-nodes-monitor

## Why

M1 打通了 iOS 最小可连接闭环（订阅 → 连接 → 隧道），但用户连接后无法管理节点、看不到运行状态。M2 接入 mihomo external-controller API，提供节点列表/切换/延迟测试 + 实时流量/连接/日志监控，让 app 从「能连」进化到「可用」，是 iOS MVP 的核心功能层。

## What Changes

- 新增 `clash-api`(Dart)：external-controller REST + WebSocket 客户端，用 M1 注入的随机端口/secret 连 127.0.0.1 控制器（Bearer secret 鉴权）。
- 节点管理：`proxies` 列表展示、`select` 组切换、延迟测试。
- 实时监控：流量速率（`/traffic` WS）、连接列表（`/connections`）、日志流（`/logs` WS）。
- UI：底部导航多页（连接页 + 节点页 + 监控页）。
- M1 衔接调整：external-controller 端口/secret 的生成与持有上移到 CoreController（M1 即时生成未保存），使 app 侧可获取当前 controller 地址供 clash-api 使用。

## Capabilities

### New Capabilities
- `clash-api`: external-controller REST + WebSocket 客户端——连接与 Bearer 鉴权、proxies/delay/traffic/connections/logs 接口封装。
- `node-management`: 节点列表展示、select 组切换、延迟测试。
- `traffic-monitor`: 实时流量速率、连接列表、日志流监控。

### Modified Capabilities
（无——M1 能力尚未 archive 到主 specs，M2 仅新增能力；对 M1 代码的端口/secret 持有调整属实现细节，不改 M1 spec 需求。）

## Impact

- 新增 `lib/core/clash_api.dart`（API 客户端）；`lib/ui` 节点页/监控页 + 底部导航。
- M1 代码调整：CoreController 持有当前 external-controller 端口/secret（生成上移），暴露 controller 地址；不改注入扩展的逻辑（M1 已验证部分不动）。
- 新增依赖：`web_socket_channel`（流量/日志 WS）；`http` 已有。
- 真机 gate：M2 端到端（节点切换/监控）需内核运行 = 需真机/连接验证，与 M1 真机 gate 一并挂起；软件部分以 mock 单测验证。
- M3（面板/按需连接）、M4（上架）不在本 change 范围。
