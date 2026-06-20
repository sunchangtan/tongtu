## MODIFIED Requirements

### Requirement: 运行参数热改
内核设置必须（MUST）在连接中允许经 external-controller（`PATCH /configs`）热改日志级别、IPv6，改动立即生效（无需重连）；进入页面应当（SHALL）经 `GET /configs` 回填当前值。运行模式（rule/global/direct）不再位于内核设置，已移至连接首页（连接中同样经 `PATCH /configs` 改 mode）。

#### Scenario: 改日志级别立即生效
- **当** 连接中在内核设置把日志级别改为 debug
- **则** 客户端发出 `PATCH /configs`（含 `{"log-level":"debug"}`），内核立即生效

#### Scenario: 进页回填当前值
- **当** 连接中进入内核设置页
- **则** 经 `GET /configs` 回填日志级别 / IPv6 的当前值

#### Scenario: 运行模式不在内核设置
- **当** 查看内核设置的运行参数
- **则** 不含运行模式（运行模式在连接首页调节）
