# core-bridge Specification

## Purpose
TBD - created by archiving change p0-core-bridge. Update Purpose after archive.
## Requirements
### Requirement: 基于官方仓库的内核依赖
core-bridge 的 Go 模块必须直接依赖官方模块 `github.com/metacubex/mihomo` 并锁定到官方 release tag；不得 依赖任何 fork 仓库或维护长期私有补丁。如确需临时补丁，MUST 以 `go.mod replace` + 仓库内补丁文件的形式显式可见。

#### Scenario: 依赖来源校验
- **当** 检查 `core-bridge/go.mod` 与 `go.sum`
- **则** mihomo 依赖路径为 `github.com/metacubex/mihomo`，版本为官方 release tag，且不存在指向 fork 的 replace（临时补丁型 replace 除外，需附带补丁文件与说明）

### Requirement: 内核生命周期接口
core-bridge应当（SHALL）导出可供 Swift/Kotlin 调用的生命周期接口：以 YAML 配置启动内核、停止内核、热重载配置、查询运行状态；接口语义在所有宿主平台保持一致。

#### Scenario: 合法配置启动
- **当** 以合法的 mihomo YAML 配置调用 Start
- **则** 内核进入运行状态，external-controller 在配置指定的回环地址可达，状态查询返回 running

#### Scenario: 非法配置启动
- **当** 以语法或语义非法的 YAML 调用 Start
- **则** 接口返回包含错误定位信息（字段/行号）的错误，内核不残留任何运行资源

#### Scenario: 停止与资源回收
- **当** 对运行中的内核调用 Stop
- **则** 所有监听端口关闭、TUN 栈停止，状态查询返回 stopped

#### Scenario: 热重载配置
- **当** 对运行中的内核调用 Reload 并传入新 YAML
- **则** 新配置生效且现有隧道进程不退出

### Requirement: 控制接口注入
core-bridge应当（SHALL）允许调用方在启动时覆写 external-controller 监听地址与 secret，以便宿主 App 注入随机端口与随机凭据。

#### Scenario: 注入随机端口与 secret
- **当** 调用方以指定的回环端口与 secret 启动内核
- **则** RESTful API 仅在该端口可达，且无凭据请求被拒绝（HTTP 401）

### Requirement: 内存防护参数
core-bridge应当在内核启动前应用内存防护参数：设置 `GOMEMLIMIT`（默认约 30MiB，可由调用方覆写）、调低 `GOGC`、注入 `geodata-loader: memconservative` 默认值，并周期性触发 `debug.FreeOSMemory()`；SHALL 提供查询当前 Go 运行时内存占用的接口。

#### Scenario: 默认内存防护生效
- **当** 调用方未指定内存参数启动内核
- **则** Go 运行时的 GOMEMLIMIT 为默认值（约 30MiB），内存占用查询接口返回当前 heap/总占用数据

### Requirement: xcframework 构建管线
项目应当（SHALL）提供一键构建脚本，将 core-bridge 编译为包含 iOS（arm64）、iOS Simulator（arm64/x86_64）、macOS（arm64/x86_64）切片的 `MihomoCore.xcframework`（静态库形态）；构建必须（MUST）可在干净检出后复现。LC_UUID 由最终链接生成，其校验在链接产物（ios-poc 扩展可执行文件）上执行——静态库归档本身不含 LC_UUID（实施中核实修正，2026-06-12）。

#### Scenario: 干净环境一键构建
- **当** 在干净检出的仓库上运行构建脚本（已安装脚本声明的 Go/gomobile/Xcode 版本）
- **则** 产出包含上述切片的 xcframework，`lipo -archs` 确认各切片架构完整且为静态库归档格式

