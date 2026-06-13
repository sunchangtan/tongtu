# 任务清单：p0-core-bridge

## 1. 工具链与工程骨架

- [x] 1.1 确认 mihomo 最新官方 release tag 及其上游 CI 的 Go 版本，固化到 `core-bridge/README.md` 与 `.go-version`
- [x] 1.2 创建 `core-bridge/` Go 模块：`go.mod` 依赖官方 `github.com/metacubex/mihomo`（锁定 release tag）
- [x] 1.3 安装并验证 gomobile 工具链（`gomobile init`），记录版本到 README
- [x] 1.4 编写依赖来源校验脚本 `scripts/check-upstream.sh`（检测 go.mod 无 fork replace），并配置为 CI/pre-commit 步骤

## 2. core-bridge 生命周期接口（TDD：Go 测试先行）

- [x] 2.1 定义绑定接口（D2 粗粒度 JSON 协议）：`Start/Stop/Reload/State/MemoryStats`，先写接口契约测试（含非法 YAML 报错定位、停止后资源回收断言）
- [x] 2.2 实现 Start/Stop：嵌入 mihomo hub 启动流程，支持 external-controller 地址与 secret 覆写注入
- [x] 2.3 实现 Reload 与 State：热重载不中断、状态机（stopped/starting/running/error）
- [x] 2.4 实现内存防护（D4）：GOMEMLIMIT/GOGC 默认值与覆写、`geodata-loader: memconservative` 默认注入、FreeOSMemory 定时器、MemoryStats 上报
- [x] 2.5 macOS 本机以 `go test` 跑通全部契约测试（内核真实启动、回环 API 鉴权验证）

## 3. xcframework 构建管线

- [x] 3.1 编写 `scripts/build-xcframework.sh`：gomobile bind 产出 iOS/iOS Sim/macOS 切片的 `MihomoCore.xcframework`
- [x] 3.2 验证产物：切片架构与静态库格式校验（LC_UUID 转移至 4.x 链接产物校验，实施中修正）、记录二进制体积（design 开放问题 2）
- [x] 3.3 干净检出复现实验：临时目录 clone 后按 README 一键构建成功

## 4. iOS 最小验证 App（ios-poc）

- [x] 4.1 创建 Xcode 工程：主 App + Packet Tunnel 扩展 target，配置 App Group、NE entitlement、开发证书签名
- [x] 4.2 扩展集成 xcframework：startTunnel 读取 App Group 内 YAML → core-bridge Start → 配置虚拟接口（地址/路由/DNS）
- [x] 4.3 实现 TUN 数据通路（D3）：KVC 取 fd 注入 tun.file-descriptor，真机 iOS 26 验证 KVC 路径可用、内核以该 fd 启动 running（pipe 备选未触发，KVC 可用即免）
- [x] 4.4 主 App：连接/断开按钮、隧道状态显示、读取扩展内存指标（App Group，新鲜度 ≤10s）
- [x] 4.5 启停稳定性：core-bridge 20 轮启停测试通过（无 fd 泄漏/端口可复用/状态干净），iOS 扩展进程退出已真机观察
- [x] 4.6 真机端到端冒烟：直连(DIRECT)配置下 Safari 正常打开网页，TUN→内核→出站全链路打通（修复问题6/7/8/9）；代理节点变体待负载压测

## 5. 内存压测与 go/no-go 报告

- [x] 5.1 制作脱敏压测 fixture（D6）：≥50 节点 + metacubex 推荐规则集 YAML 入库 `core-bridge/testdata/`
- [x] 5.2 真机压测：空载<25MiB、直连+fakeip轻负载25-35MiB 已测；满负载（60+节点+大规则集）按归档决策转为 P1 前置验证项（见报告§6）
- [x] 5.3 GOMEMLIMIT 档位扫描：暂定 30MiB（空载/轻负载验证通过），25/35 对比扫描转为 P1 前置验证项
- [x] 5.4 撰写 `docs/reports/p0-ios-memory.md`：已定稿，结论「初步 go」（依据与转移项见报告§6）
- [x] 5.5 更新进度文档与 openspec 任务勾选状态，归档本 change（openspec archive）
