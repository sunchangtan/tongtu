## ADDED Requirements

### Requirement: 规则查询
clash-api 客户端应当（SHALL）提供获取内核当前生效分流规则的接口（`GET /rules`，Bearer 鉴权），并解析为规则项列表（含类型、匹配内容、出站目标）。响应格式以内核实证为准：`{"rules":[{index, type, payload, proxy, ...}]}`。

#### Scenario: 获取生效规则
- **当** 内核 external-controller 可达且调用规则查询接口
- **则** 返回解析后的规则项列表，每项含 type / payload / proxy

#### Scenario: 鉴权失败
- **当** 以错误 secret 调用规则查询接口
- **则** 抛出 `ClashApiException`（与现有接口一致的错误语义）
