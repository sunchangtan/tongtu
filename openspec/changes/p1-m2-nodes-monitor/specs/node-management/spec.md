## ADDED Requirements

### Requirement: 节点列表与切换
应当（SHALL）展示 select 代理组的节点列表与当前选中节点，并支持切换。

#### Scenario: 展示节点
- **当** 隧道已连接且查询到代理组
- **则** UI 列出 select 组的候选节点并标注当前选中

#### Scenario: 切换节点
- **当** 用户在 select 组选择某节点
- **则** 经 clash-api 切换，内核当前出站改为该节点，UI 更新选中状态

### Requirement: 节点延迟测试
应当（SHALL）支持对节点发起延迟测试并展示结果。

#### Scenario: 测试延迟
- **当** 用户触发某节点的延迟测试
- **则** UI 显示该节点的延迟毫秒值；测试超时则显示超时

### Requirement: 未连接空态
节点页在未连接时应当（SHALL）显示空态提示而非报错。

#### Scenario: 未连接访问节点页
- **当** 隧道未连接、controller 不可达
- **则** 节点页显示「请先连接」类提示，不抛出未处理异常
