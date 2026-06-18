# 任务拆解：UI 导航重构 + 内核设置页

纯 Flutter（Dart）特性，无 Go/Swift 改动。遵循 TDD（specs 场景即测试用例来源）。

## 1. clash_api 扩展（TDD，实证格式优先）

- [x] 1.1 已实证（本地起 controller curl）：`GET /configs`=200 完整 General JSON（kebab 字段 mode/log-level/ipv6/unified-delay/sniffing）；`PATCH /configs`=204、mode(rule→global)/log-level(silent→debug) 生效、**sniffing 在无 sniffer 段不生效→去域名嗅探**；`POST /cache/fakeip/flush`=204
- [x] 1.2 `clash_api` 单测（mock HTTP，按实证）：getConfigs 解析/patchConfigs 请求体+鉴权/updateGeo/flush 路径方法 + patchConfigs 失败抛错——5 测试先红后绿
- [x] 1.3 实现 `lib/core/clash_api.dart` 5 方法 + `KernelConfig` 模型（mode/logLevel/ipv6/unifiedDelay；去 sniffing）。clash_api_test 13 全过、analyze 0

## 2. 导航重构（TDD）

- [x] 2.1 `lib/ui/connect_shell.dart`：`TabController` + `TabBar`(连接/节点/监控) + `IndexedStack`（保留子页状态，监控不重订阅）；`connect_shell_test` 2 测试（三子 tab + 切换）
- [x] 2.2 `lib/ui/home_shell.dart` 4→3 tab（连接/设置/内核设置，`IndexedStack` 保状态，顶层去 AppBar、各页自带 Scaffold/AppBar）；`home_shell_test` 2 测试（3 tab + 切内核设置）
- [x] 2.3 `lib/ui/settings_page.dart` 瘦身：移出配置查看/分流规则/日志/内核版本（去 controller 依赖），保留外观/按需连接/关于(app)；`settings_page_test` 更新（断言内核项已移出）

## 3. 内核设置页（TDD）

- [x] 3.1 `lib/ui/kernel_settings_page.dart` 运行参数组：模式/日志级别/IPv6；连接中 `getConfigs` 回填 + 改调 `patchConfigs`（乐观更新+失败回滚）；未连接灰置 + 「连接后可调」；`stateStream` 订阅 dispose 取消
- [x] 3.2 维护动作组：更新 GEO/清 fake-ip/清 DNS（连接中按钮 + SnackBar 结果）；灰置随连接态
- [x] 3.3 配置与规则组 + 内核信息组：复用 `ConfigViewerPage`/`RulesPage`/`LogViewerPage` + 内核版本(常量)/unified-delay(只读)；`kernel_settings_page_test` 3 测试（未连接灰置、回填+改模式 PATCH、更新 GEO POST）

## 4. 质量门禁

- [x] 4.1 `flutter analyze` 第一方 0（仅 node_modules 第三方豁免）+ `dart format` + `flutter test` **97 全过**
- [x] 4.2 `flutter build ios --no-codesign` **✓ Built**（导航重构/新页入编译链接）
- [x] 4.3 `openspec validate p1-m3-kernel-settings --strict` 通过

## 5. 真机验证与归档（gate）

- [ ] 5.1 真机：运行参数热改实际生效（模式切「全局」全量代理、日志级别改 debug 日志变多）
- [ ] 5.2 真机：更新 GEO 数据库 / 清 fake-ip / 清 DNS 缓存成功
- [ ] 5.3 真机：切底部 tab 与连接内子页，监控/节点数据流不中断
- [ ] 5.4 实施完成且真机通过后，按 archive 顺序 `openspec archive p1-m3-kernel-settings`
