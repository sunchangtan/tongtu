## 1. Flutter 工程脚手架

- [x] 1.1 仓库根创建 Flutter 工程（保留现有 core-bridge/ios-poc/openspec/docs），配置 pubspec 基础依赖
- [x] 1.2 建立 lib/ 目录结构（core/config/ui，对齐 architecture.md §7）
- [x] 1.3 配置 Dart analyzer 关键项升 error（质量门禁），可跑 dart analyze 零问题

## 2. NE 扩展迁入与生产化

- [x] 2.1 在 Flutter ios/ 工程加入 PacketTunnel 扩展 target + App Group + NE entitlement（脚本化 scripts/add-packet-tunnel-target.rb，xcodeproj gem）
- [x] 2.2 迁入 ios-poc 扩展 Swift 代码（PacketTunnelProvider/TunFD/InterfaceMonitor/SharedStore/ProcessMemory）至 ios/PacketTunnel、ios/Shared
- [x] 2.3 扩展链接复用 core-bridge 的 MihomoCore.xcframework（不改 Go 代码）
- [x] 2.4 去除 PoC 包袱：移除固定 9090/写死 secret，改为读取 App Group 注入的端口/secret（运行时 configYAML 由主 App 写）
- [ ] 2.5 真机复测数据通路（直连打开网页），确认 4 个沙盒坑修复随迁移无回归（依赖 3-5 app 可连接，随任务 6 真机一并验证）

## 3. 统一内核控制抽象与 Platform Channel

- [x] 3.1 定义 CoreController(Dart) 抽象接口与状态枚举（stopped/connecting/connected/error），含状态流
- [x] 3.2 实现 apple_core_controller：MethodChannel 启停 + EventChannel 状态回流
- [x] 3.3 原生 Swift 侧：MethodChannel handler 经 NETunnelProviderManager 启停隧道、隧道状态经 EventChannel 上报
- [x] 3.4 Dart 单元测试：CoreController 状态机与 Channel 协议（mock channel），覆盖 flutter-app-shell 场景

## 4. 订阅导入与运行时配置生成

- [ ] 4.1 订阅链接导入与存储（M1 最小：单订阅），无效链接给可读中文错误
- [ ] 4.2 运行时 YAML 生成：metacubex 推荐模板 + 用户 override + 订阅 proxy-providers 合并，写入 App Group
- [ ] 4.3 external-controller 随机端口/secret 生成并注入扩展（App Group / providerConfiguration）
- [ ] 4.4 Dart 单元测试：配置合并/订阅解析/端口与 secret 生成，覆盖 subscription-config 场景

## 5. 最小连接界面

- [ ] 5.1 UI：导入订阅、连接/断开按钮、隧道状态中文显示
- [ ] 5.2 状态流绑定：CoreController 状态 → UI 实时反映

## 6. 退出 gate 与收尾

- [ ] 6.1 真机：导入真实订阅 → 连接 → 经代理节点出站连通（浏览器打开需代理的站点）
- [ ] 6.2 真机：满负载内存复测，确认仍满足常驻 < 40MiB / 峰值 < 50MiB（沿用 P0 方法与 phys_footprint 自报）
- [ ] 6.3 质量门禁：swiftlint --strict + dart analyze + go vet 全绿，第一方 0 警告
- [ ] 6.4 更新进度文档与报告，openspec validate p1-m1-ios-skeleton 通过，准备 archive
