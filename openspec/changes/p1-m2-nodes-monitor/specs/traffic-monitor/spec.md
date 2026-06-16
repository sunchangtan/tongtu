## ADDED Requirements

### Requirement: 实时流量监控
应当（SHALL）经 WebSocket 实时显示上行/下行速率。

#### Scenario: 流量推送
- **当** 隧道运行且订阅 traffic WebSocket
- **则** UI 实时更新上行与下行速率

### Requirement: 连接列表监控
应当（SHALL）展示当前活动连接（目标地址、命中规则、出站代理、上下行流量）。

#### Scenario: 查看连接
- **当** 隧道运行且有活动连接
- **则** UI 展示活动连接列表及其关键信息

### Requirement: 实时日志
应当（SHALL）经 WebSocket 实时展示内核日志流。

#### Scenario: 日志推送
- **当** 订阅 logs WebSocket
- **则** UI 实时追加内核日志行（含级别与内容）
