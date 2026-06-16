## Context

M1 提供可连接闭环（CoreController + 隧道 + 订阅导入）。M2 接入 mihomo external-controller API 做节点管理与运行监控。当前 M1 在 `_connect` 即时生成 external-controller 端口/secret 传扩展、app 未保存，无法连 controller。M2 需让 app 持有当前 controller 地址。约束：只用官方 external-controller API、WS 用 web_socket_channel、遵循 architecture.md v1.3。

## Goals / Non-Goals

**Goals:**
- clash-api：REST（proxies/切换/延迟/connections）+ WebSocket（traffic/logs）客户端，Bearer secret 鉴权。
- 节点列表展示、select 组切换、延迟测试。
- 流量速率、连接列表、日志流实时监控。
- 底部导航多页（连接 / 节点 / 监控）。
- external-controller 端口/secret 上移 CoreController 持有，app 侧可获取 controller 地址。

**Non-Goals:**
- zashboard 面板、按需连接 NEOnDemandRule（M3）。
- 配置/规则编辑、多订阅管理（M3+）。
- App Store 上架（M4）。

## Decisions

- **端口/secret 持有**：从 app 即时生成改为 CoreController 内部生成并持有——`start({required String configYAML})` 内部生成端口/secret、注入扩展、并以 `currentEndpoint`（host/port/secret）暴露；home_page 不再自行生成。clash-api 从 `CoreController.currentEndpoint` 读 controller 地址。理由：端口/secret 是内核控制细节，归 CoreController 内聚，避免 app 与扩展各持一份。
- **clash-api 实现**：`http`（REST）+ `web_socket_channel`（WS）；base `http://127.0.0.1:<port>`；请求头 `Authorization: Bearer <secret>`。
- **节点模型**：`GET /proxies` 返回代理组与节点（select 组含 `now` 当前 / `all` 候选）；`PUT /proxies/{group}` 切换；`GET /proxies/{name}/delay` 延迟测试。
- **监控**：`/traffic` WS 推 `{up, down}`；`/logs` WS 推 `{type, payload}`；连接经 `/connections` WS 快照流。
- **UI**：`Scaffold` + `NavigationBar` 底部 3 页；未连接时节点/监控页显示空态提示。

## Risks / Trade-offs

- [M1 `start` 签名改动] → home_page 与 M1 测试随改 → M2 一并更新并回归 M1 既有测试。
- [controller 仅连接后可达] → 未连接时节点/监控页空态提示，不报错。
- [WS 断线] → M2 做基础重连（断开后定时重试）；复杂退避策略留后续。
- [无真机端到端验证] → clash-api 的解析/鉴权以 mock 单测覆盖；端到端真机验证与 M1 一并挂起。

## Open Questions

- `/connections` 用 WS 流还是定期 REST 快照——实施时按 mihomo 实际接口确定（倾向 WS）。
- 延迟测试 URL 与超时默认值（倾向 `http://www.gstatic.com/generate_204` / 5s）。
