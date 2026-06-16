## 1. external-controller 端口/secret 上移 CoreController（M1 衔接）

- [x] 1.1 CoreController 加 ControllerEndpoint(host/port/secret) 与 currentEndpoint；start 改为内部生成端口/secret 并持有
- [x] 1.2 apple_core_controller：start 内部生成端口/secret、注入扩展、暴露 currentEndpoint
- [x] 1.3 home_page 适配（不再自行生成端口/secret）；回归 M1 既有测试通过
- [x] 1.4 Dart 单测：CoreController endpoint 持有与暴露

## 2. clash-api 客户端

- [ ] 2.1 REST 客户端（http + Bearer secret）：proxies 查询、proxy 切换、延迟测试、connections 快照
- [ ] 2.2 WebSocket 客户端（web_socket_channel）：traffic、logs 订阅（含基础重连）
- [ ] 2.3 数据模型与解析：ProxyGroup/Proxy、Traffic、Connection、LogEntry
- [ ] 2.4 Dart 单测：REST 解析与鉴权（mock http）、WS 帧解析、错误 secret 处理

## 3. 节点管理

- [ ] 3.1 节点页：select 组节点列表 + 当前选中 + 切换
- [ ] 3.2 节点延迟测试与结果展示
- [ ] 3.3 未连接空态提示
- [ ] 3.4 widget 测试（mock clash-api）

## 4. 运行监控

- [ ] 4.1 流量页：实时上/下行速率（traffic WS）
- [ ] 4.2 连接列表（目标/规则/代理/流量）
- [ ] 4.3 日志流（logs WS）
- [ ] 4.4 widget 测试（mock 数据）

## 5. 导航与集成

- [ ] 5.1 底部导航多页（连接 / 节点 / 监控）
- [ ] 5.2 各页与 clash-api / CoreController 集成、连接态联动

## 6. 退出 gate 与收尾

- [ ] 6.1 真机：连接后节点切换生效、延迟测试、流量/连接/日志实时（需真机）
- [ ] 6.2 质量门禁：swiftlint --strict + dart analyze + go vet 全绿，第一方 0 警告
- [ ] 6.3 更新进度文档与报告，openspec validate p1-m2-nodes-monitor 通过，准备 archive（与 M1 真机 gate 一并）
