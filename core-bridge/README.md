# core-bridge —— mihomo 内核桥接层

通途（Tongtu）项目的 Go 封装模块：将官方 mihomo 内核封装为可供 Swift/Kotlin/Dart 调用的
生命周期接口，并经 gomobile 编译为 `MihomoCore.xcframework`（iOS / iOS Simulator / macOS）。

## 工具链版本固化（任务 1.1，2026-06-12 核实）

| 组件 | 版本 | 来源依据 |
|------|------|---------|
| mihomo | `v1.19.27`（官方最新 release tag，2026-06-06 发布） | github.com/MetaCubeX/mihomo releases/latest |
| Go | `1.26.0` | mihomo 上游 CI（.github/workflows/build.yml 的 go-version）|
| gomobile | 见 `go.mod` tool 依赖（任务 1.3 固化） | — |

- 本模块 `go.mod` 通过 `toolchain go1.26.0` 指令保证编译工具链与上游 CI 一致，
  本机低版本 Go 会自动下载所需工具链（GOTOOLCHAIN=auto，Go 1.21+ 默认行为）。
- `.go-version` 供 CI 与版本管理工具（如 asdf/mise）读取。

## 红线（项目 CLAUDE.md）

- 只依赖官方 `github.com/metacubex/mihomo`，锁定 release tag；不 fork、不维护长期补丁。
- 依赖来源由 `scripts/check-upstream.sh` 校验（任务 1.4）。

## 已知问题（上游）

- **mihomo route 包数据竞争**（v1.19.27，`hub/route/server.go`）：`ReCreateServer` 以
  `go start(cfg)` 异步读写全局 `httpServer`，相邻两次调用（如本包 Start→Stop 序列）之间
  无同步原语，`go test -race` 可稳定复现（162 行读 vs 179 行写）。
  缓解：本包 Start 以「鉴权 HTTP /version 返回 200」作为就绪门槛，确保上游 `Serve()` 已
  运行后才返回，真实时序上消除竞争窗口；契约测试以非 race 模式为验收门槛。
  待办：向上游提 issue/PR（为 `httpServer` 等全局变量加锁）。

## 构建

```bash
# 接口契约测试（macOS 本机即可运行）
go test ./...

# 构建 xcframework（任务 3.1，产物输出至 build/）
../scripts/build-xcframework.sh
```
