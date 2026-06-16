## ADDED Requirements

### Requirement: external-controller 客户端连接与鉴权
clash-api 应当（SHALL）使用当前 controller 地址（127.0.0.1 + 随机端口）与 secret，以 `Authorization: Bearer <secret>` 访问 external-controller 的 REST 与 WebSocket 接口；端口/secret 由 CoreController 持有并提供。

#### Scenario: 鉴权访问成功
- **当** 隧道已连接且 clash-api 取得 controller 端口与 secret
- **则** 以 Bearer secret 访问 REST 接口返回成功响应

#### Scenario: 缺少或错误 secret
- **当** 未提供 secret 或 secret 错误
- **则** 请求返回鉴权失败（HTTP 401），clash-api 不得（MUST NOT）将其当作正常数据处理

### Requirement: 接口封装
clash-api 应当（SHALL）封装 proxies 查询、proxy 切换、延迟测试，以及 traffic/connections/logs 的实时订阅。

#### Scenario: 查询代理
- **当** 调用 proxies 查询
- **则** 返回内核当前代理组与节点信息（含 select 组的 now 与 all）

#### Scenario: 订阅实时流
- **当** 订阅 traffic 或 logs WebSocket
- **则** 持续收到内核推送的数据帧，连接断开时可被重新订阅
