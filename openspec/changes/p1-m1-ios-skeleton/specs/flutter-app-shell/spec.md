## ADDED Requirements

### Requirement: 统一内核控制抽象
通途主应用应当（SHALL）提供平台无关的 CoreController(Dart) 抽象，定义内核的启动、停止、状态查询与状态流接口，使 UI 与上层逻辑不依赖具体平台的内核集成方式。

#### Scenario: 经抽象接口控制内核
- **当** 上层调用 CoreController 的 start 或 stop
- **则** 对应平台实现完成内核启停，并通过状态流向 UI 反映 stopped/connecting/connected/error 状态

### Requirement: 苹果平台内核控制
苹果平台实现 apple_core_controller 应当（SHALL）经 Platform Channel 与原生层通信，由原生层通过 NETunnelProviderManager 控制 Packet Tunnel 扩展的启停，并将隧道状态经事件通道回传 Dart。

#### Scenario: 连接与断开
- **当** 用户在界面触发连接或断开
- **则** apple_core_controller 经 Platform Channel 调用原生 NETunnelProviderManager 启停隧道，界面状态随之更新

#### Scenario: 系统侧状态变化回传
- **当** 隧道状态在系统侧发生变化（如被系统断开或按需触发）
- **则** 原生层经事件通道通知 Dart，CoreController 状态流更新，界面反映最新状态

### Requirement: 最小连接界面
主应用应当（SHALL）提供最小可用界面：导入订阅、连接/断开、以及隧道状态显示。

#### Scenario: 显示隧道状态
- **当** 隧道处于未连接/连接中/已连接/错误任一状态
- **则** 界面以中文文案显示对应状态
