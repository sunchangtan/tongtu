# 任务拆解：运行参数预设化（对齐 clashmi 核心设置）

纯 Flutter（Dart），遵循 TDD。顺序：RunParamsStore（基础）→ 连接注入 → 运行模式 store 化 → 内核设置去灰置+新参数 → 节点延迟测试参数 → 接线 → 门禁 → 真机。

## 1. RunParamsStore（TDD，基础）

- [x] 1.1 加依赖 `yaml_edit`（pubspec）；先写 `test/config/run_params_store_test.dart`：持久化往返、各 setter、种子化（有/无订阅顶层键、幂等）、`applyToConfig`（顶层键存在改写 / 不存在新增 / 保留其余 proxies/rules / `sniff=true` 生成 sniffer 段 / allow-lan+mixed-port）
- [x] 1.2 `lib/config/run_params_store.dart`：`RunParams{mode,logLevel,ipv6,unifiedDelay,tcpConcurrent,sniff,allowLan,mixedPort,delayTestUrl,delayTestTimeoutMs}`(+copyWith) + `RunParamsStore extends ChangeNotifier`（load/save 持久化 shared_prefs JSON key `run_params`；`applyToConfig(yaml)` 用 yaml_edit 合并；`seedFromConfig(yaml)` 种子化）；默认值见 design §决策1

## 2. 连接注入（TDD）

- [x] 2.1 `lib/ui/home_page.dart`：注入 `RunParamsStore`；`_connect` 用 `runParams.applyToConfig(currentContent)` 合并后再 `controller.start`
- [x] 2.2 widget 测试：有当前订阅连接时，`start` 入参配置正文含偏好键（mode/tcp-concurrent 等）

## 3. 运行模式 store 驱动（TDD）

- [x] 3.1 `lib/ui/run_mode_selector.dart`：改 store 驱动——未连接显示并可改偏好（存盘、不灰置）；连接中保留热切（`PATCH /configs` 即时 + 同步 store）
- [x] 3.2 widget 测试：未连接改 mode 存盘且不灰置；连接中改 mode 发 PATCH + 同步 store

## 4. 内核设置去灰置常亮 + 新参数（TDD）

- [x] 4.1 `lib/ui/kernel_settings_page.dart`：运行参数改 store 驱动**常亮**（去 getConfigs/_loadConfigs/PATCH 乐观回滚）；顶部「修改后需重连生效」提示；项：日志级别/IPv6/统一延迟（改为可设）/TCP 并发/域名嗅探/延迟测试 URL·超时/局域网代理共享（allow-lan+mixed-port 成对）；维护动作保持连接后可用
- [x] 4.2 widget 测试：未连接运行参数常亮可改、改即存盘、重连提示存在；维护动作未连接灰置

## 5. 节点延迟测试用 store 参数（TDD）

- [x] 5.1 `lib/ui/nodes_page.dart`：测延迟用 `runParams` 的 delayTestUrl/delayTestTimeoutMs（替换硬编码）
- [x] 5.2 测试：测延迟使用注入的 url/timeout

## 6. 导航接线

- [x] 6.1 `lib/ui/home_shell.dart` 创建并共享 `RunParamsStore`、首次 load 后从当前订阅 `seedFromConfig` 种子化；`connect_shell.dart` 转发给 home_page/run_mode_selector；kernel_settings/settings 传递

## 7. 质量门禁

- [x] 7.1 `flutter analyze` 第一方 0 + `dart format` + `flutter test` 全过
- [x] 7.2 `flutter build ios --no-codesign` 编译通过
- [x] 7.3 `openspec validate p1-m5-core-settings --strict` 通过

## 8. 真机验证与归档（gate）

- [ ] 8.1 真机：各参数（日志级别/IPv6/统一延迟/TCP并发/嗅探）未连接预设、重连后生效正确
- [ ] 8.2 真机：运行模式连接首页预设 + 连接中热切；延迟测试用自定义 URL/超时
- [ ] 8.3 真机：局域网代理共享（allow-lan+mixed-port）——同网段设备经「本机IP:端口」可代理（**附真机可达数据**）；不通则降级文档说明
- [ ] 8.4 真机：升级后从旧订阅配置种子化偏好（不回归 mode 等）
- [ ] 8.5 实施完成且真机通过后，按 archive 顺序（`p1-m3-kernel-settings`、`p1-m4-multi-subscription-nav` 之后）`openspec archive p1-m5-core-settings`
