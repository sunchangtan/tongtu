## 1. 共享只读文本查看组件（Dart，TDD）

- [x] 1.1 抽 `lib/ui/text_viewer_page.dart`：标题 + 文本加载器（`Future<String?> Function()`）+ 搜索 + SelectionArea 复制 + share_plus 导出 + loading/空态
- [x] 1.2 `log_viewer_page` 重构为复用 `text_viewer_page`（行为不变，原测试仍过）
- [x] 1.3 widget 测试：text_viewer 加载/搜索/空态

## 2. 主题持久化 + 应用设置

- [ ] 2.1 `lib/core/theme_controller.dart`：`ValueNotifier<ThemeMode>` + shared_preferences 持久化（key `theme_mode`，缺省 system）
- [ ] 2.2 `main.dart`：`ValueListenableBuilder` 包 `MaterialApp`，启动读取持久值、切换即时重建
- [ ] 2.3 `lib/core/kernel_version.dart`：内核版本静态常量（`v1.19.27`，注释「与 core-bridge/go.mod 同步」）
- [ ] 2.4 `lib/ui/settings_page.dart`：分组（外观主题切换 / 配置入口 / 规则入口 / 关于=app版本+内核版本+GPL+日志入口）
- [ ] 2.5 widget 测试：主题切换持久化（SharedPreferences mock）、关于信息展示

## 3. 配置查看子页

- [ ] 3.1 `lib/ui/config_viewer_page.dart`：复用 `text_viewer_page`，加载器 = `SubscriptionStore.loadContent`（订阅原文只读）
- [ ] 3.2 widget 测试：mock content 展示 + 未获取空态

## 4. 规则查看（clash-api + UI）

- [ ] 4.1 `clash_api`：新增 `getRules()`（GET `/rules` + Bearer）+ `RuleItem` 模型（type/payload/proxy，按实证格式 `{"rules":[...]}`）
- [ ] 4.2 `lib/ui/rules_page.dart`：列表（type/payload/proxy）+ 搜索 + 空态（未连接/无数据）
- [ ] 4.3 测试：`getRules` mock HTTP **按实证格式** + 鉴权失败抛异常；rules_page 空态 + mock rules widget 测试

## 5. 导航集成

- [ ] 5.1 `home_shell`：底部导航加第 4 tab「设置」（连接/节点/监控/设置），`IndexedStack` 加一项
- [ ] 5.2 widget 测试：4 tab 渲染、切到设置 tab

## 6. 质量门禁

- [ ] 6.1 `flutter analyze` 0 警告 0 错误 + `dart format` + `flutter test` 全过
- [ ] 6.2 `go vet` + `golangci-lint`（若动 core-bridge）+ `swiftlint --strict`（若动 Swift）通过
- [ ] 6.3 `openspec validate p1-m3-settings-page --strict` 通过

## 7. 真机验证与归档（gate）

- [ ] 7.1 真机：规则查看展示内核运行时的真实生效规则（连接后非空、可搜索）
- [ ] 7.2 真机：主题切换、配置原文查看、关于信息在真机正常
- [ ] 7.3 实施完成且真机通过后，按 archive 顺序（`p1-m2-nodes-monitor` 在前）`openspec archive p1-m3-settings-page`
