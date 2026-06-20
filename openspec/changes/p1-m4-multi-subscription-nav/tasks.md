# 任务拆解：导航 IA 重构 + 多订阅管理

纯 Flutter（Dart）。遵循 TDD。顺序：多订阅 Store（基础）→ 订阅 tab → 连接页重构+运行模式 → 内核设置降级 → 导航 IA → 门禁 → 真机。

## 1. 多订阅 Store（TDD，基础）

- [x] 1.1 先写 `test/config/subscriptions_store_test.dart`：add/remove/setCurrent/update/current/currentContent、JSON 往返、content 按 id 落盘、删除清落盘文件、空态
- [x] 1.2 `lib/config/subscriptions_store.dart`：`Subscription{id,name,url,info}` + `SubscriptionsStore`（list + currentId 持久化 shared_prefs JSON；content 落盘 `configs/<id>.yaml`；id 生成可注入）；复用现有 `fetch`/`SubscriptionInfo`/`_validateClashConfig`（从 subscription.dart 提取或复用）
- [x] 1.3 迁移：首次 `load` 把旧单订阅（`subscription_url` + 旧落盘 content）迁为列表首项设当前、清旧 key、幂等；单测覆盖「有旧数据→首项 current」「已迁移不重复」

## 2. 订阅 tab（TDD）

- [x] 2.1 `lib/ui/subscriptions_page.dart`：订阅卡列表（名称/流量·到期/当前标记/更新/删除）+ 右下 FAB「添加订阅」（url+名称，fetch 校验入库）+ 切换当前（已连接提示重连）+ 空态
- [x] 2.2 widget 测试：列表渲染、添加（mock fetch）、切换选中、删除（含删当前转移）、更新、空态

## 3. 连接页重构 + 运行模式（TDD）

- [ ] 3.1 `lib/ui/home_page.dart`：移除订阅链接输入/获取/流量信息（移订阅 tab）；连接用 `currentContent()`；无当前订阅禁用连接 + 提示去订阅页；保留状态/内存/诊断
- [ ] 3.2 `lib/ui/run_mode_selector.dart`：运行模式 `SegmentedButton`（连接中 `getConfigs` 回填 + `patchConfigs({mode})` 乐观+回滚，未知值防御、on Exception，沿用 kernel_settings 写法）；未连接灰置；HomePage 集成
- [ ] 3.3 widget 测试：无 current 禁用+提示、有 current 可连接、RunModeSelector 回填+改模式 PATCH+未连接灰置

## 4. 内核设置降级（TDD）

- [x] 4.1 `lib/ui/kernel_settings_page.dart`：移除运行模式组（移连接页）、保留日志级别/IPv6/维护/配置规则/内核信息、恢复 `AppBar('内核设置')`
- [x] 4.2 `lib/ui/settings_page.dart`：加「内核设置」`ListTile` push KernelSettingsPage（传 controller）
- [x] 4.3 测试更新：kernel_settings_page_test 去运行模式断言+加 AppBar、settings_page_test 加内核设置入口断言

## 5. 导航 IA（TDD）

- [x] 5.1 `lib/ui/home_shell.dart`：底部三 tab 改 连接 / 订阅 / 设置（`IndexedStack` 保状态）；ConnectShell 接收并转发共享 store
- [x] 5.2 widget 测试：连接/订阅/设置三 tab、无内核设置底部 tab、切换可达

## 6. 质量门禁

- [x] 6.1 `flutter analyze` 第一方 0 + `dart format` + `flutter test` 全过（128 测试）
- [x] 6.2 `flutter build ios --no-codesign` 编译通过（Runner.app 78.1MB）
- [x] 6.3 `openspec validate p1-m4-multi-subscription-nav --strict` 通过

## 7. 真机验证与归档（gate）

- [ ] 7.1 真机：多订阅 添加/切换/删除/更新；连接使用当前订阅；切换提示重连
- [ ] 7.2 真机：运行模式在连接页热改生效；内核设置二级页（日志级别/IPv6/维护）正常
- [ ] 7.3 真机：升级后旧单订阅迁移保留（不丢配置）
- [ ] 7.4 实施完成且真机通过后，按 archive 顺序（`p1-m3-kernel-settings` 之后）`openspec archive p1-m4-multi-subscription-nav`
