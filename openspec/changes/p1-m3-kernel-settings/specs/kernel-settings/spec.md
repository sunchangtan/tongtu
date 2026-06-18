## ADDED Requirements

### Requirement: 运行参数热改
内核设置必须（MUST）在连接中允许经 external-controller（`PATCH /configs`）热改运行模式、日志级别、IPv6，改动立即生效（无需重连）；进入页面应当（SHALL）经 `GET /configs` 回填各参数当前值。

#### Scenario: 改运行模式立即生效
- **当** 连接中在内核设置把运行模式改为「全局」
- **则** 客户端发出 `PATCH /configs`（含 `{"mode":"global"}`），内核立即切换模式

#### Scenario: 进页回填当前值
- **当** 连接中进入内核设置页
- **则** 经 `GET /configs` 读取并回填运行模式/日志级别/IPv6 的当前值

#### Scenario: 改动失败回滚
- **当** `PATCH /configs` 请求失败
- **则** UI 回滚到改动前的值并提示失败

### Requirement: 内核维护动作
内核设置应当（SHALL）提供连接中的维护动作：更新 GEO 数据库（`POST /configs/geo`）、清 fake-ip 缓存（`POST /cache/fakeip/flush`）、清 DNS 缓存（`POST /cache/dns/flush`）。

#### Scenario: 更新 GEO 数据库
- **当** 连接中点击「更新 GEO 数据库」
- **则** 客户端发出 `POST /configs/geo` 并提示结果

#### Scenario: 清理缓存
- **当** 连接中点击「清 fake-ip 缓存」或「清 DNS 缓存」
- **则** 客户端发出对应 `POST /cache/fakeip/flush` 或 `POST /cache/dns/flush` 并提示结果

### Requirement: 未连接态灰置
运行参数与维护动作依赖 external-controller，未连接时必须（MUST）灰置并提示需先连接；连接建立后应当（SHALL）自动启用并回填当前值。

#### Scenario: 未连接灰置
- **当** 未连接时进入内核设置页
- **则** 运行参数与维护动作灰置不可操作，并提示「连接后可调」

#### Scenario: 连接后自动启用
- **当** 在内核设置页期间隧道连接建立
- **则** 运行参数与维护动作启用，并经 `GET /configs` 回填当前值

### Requirement: 内核信息与配置规则查看
内核设置应当（SHALL）展示内核版本（编译期常量）、unified-delay（`GET /configs` 只读）、日志入口，并提供查看订阅配置与分流规则（复用现有页面）。不依赖实时连接的项在未连接时仍可用。

#### Scenario: 内核信息展示
- **当** 进入内核设置页
- **则** 展示内核版本；连接中额外展示 unified-delay；提供日志入口

#### Scenario: 配置与规则入口
- **当** 在内核设置页点击「查看订阅配置」或「分流规则」
- **则** 分别进入只读配置查看页与分流规则页

### Requirement: 红线项不暴露
内核设置不得（MUST NOT）暴露通途为 iOS NE 强制写死的 TUN/DNS 约束项（`tun.stack`/`auto-route`/`auto-detect-interface`/DNS fake-ip）与 NE 内危险动作（`restart`/`upgrade`）。

#### Scenario: 不含红线项
- **当** 查看内核设置全部可调项
- **则** 不含 TUN 栈/自动路由/DNS fake-ip 等强制写死项，也不含重启/升级内核动作
