# 任务拆解：增强「添加订阅」（对齐 clashmi）

纯 Flutter（Dart）+ 少量 iOS 原生（相机权限）。遵循 TDD。顺序：模型/Store → fetch UA → 添加页 → 扫码 → 自动更新接线 → 门禁 → 真机。

## 1. 模型 + Store 扩展（TDD，基础）

- [x] 1.1 先写 `test/config/subscriptions_store_test.dart` 增量：`Subscription` 新字段持久化往返；`addContent`（合法入库 url 空 / 非法不入库）；`add` 带 userAgent 透传 fetcher + interval/lastUpdated 落库；`update` 用存储 UA 重拉并置 lastUpdated；`dueForAutoUpdate`（关/未到期/到期/url 空跳过）
- [x] 1.2 `lib/config/subscriptions_store.dart`：`Subscription` 加 `userAgent`/`updateIntervalMinutes`/`lastUpdatedMs`（toJson/fromJson 默认回退）；fetcher 签名加 userAgent；`add(name,url,{userAgent,intervalMinutes})`、`addContent(name,content)`、`dueForAutoUpdate(nowMs)`、`update` 置 lastUpdated；`nowMs` 可注入

## 2. fetch 加 User-Agent + 内容校验暴露（TDD）

- [x] 2.1 `test/config/subscription_store_test.dart` 增量：`fetch(url, userAgent: x)` 发出的请求头 UA=x；`validateContent` 合法/非法
- [x] 2.2 `lib/config/subscription.dart`：`fetch` 加 `userAgent` 参数（默认 clash.meta）；暴露 `static String? validateContent(content)`（复用 `_validateClashConfig`）

## 3. 全屏添加页（TDD）

- [x] 3.1 `lib/ui/add_subscription_page.dart`：名称 + 输入框(多行 URL/内容) + 导入按钮(剪贴板/扫码) + 更新间隔下拉 + User-Agent + 添加；注入 `clipboardReader`/`scanner`；URL→`add`、内容→`addContent`；空输入禁用、失败显示原因
- [x] 3.2 `lib/ui/subscriptions_page.dart`：FAB 由弹窗改 `push(AddSubscriptionPage)`
- [x] 3.3 widget 测试：剪贴板填入（mock）、URL 添加、内容添加、扫码注入结果填入、间隔/UA 设置、添加成功回订阅页

## 4. 扫码二维码（TDD + 真机）

- [x] 4.1 加依赖 `mobile_scanner`；iOS `Runner/Info.plist` 加 `NSCameraUsageDescription`（中文）
- [x] 4.2 `lib/ui/scan_page.dart`：`MobileScanner`，首个非空条码 `Navigator.pop(text)`；结果处理可单测（注入/抽函数，不碰相机）
- [x] 4.3 测试：扫到条码 → 返回文本

## 5. 自动更新接线（TDD）

- [x] 5.1 `lib/ui/home_shell.dart`：`_init` 加载后 `for id in store.dueForAutoUpdate(now): await store.update(id)`（尽力、串行、失败不阻塞）
- [x] 5.2 测试：到期订阅启动被 update、未到期不动（可经 store 单测覆盖 due 逻辑 + home_shell 注入验证调用）

## 6. 质量门禁

- [x] 6.1 `flutter analyze` 第一方 0 + `dart format` + `flutter test` 全过
- [x] 6.2 `flutter build ios --no-codesign` 编译通过（含相机权限 plist）
- [x] 6.3 `openspec validate p1-m6-add-subscription --strict` 通过

## 7. 真机验证与归档（gate）

- [ ] 7.1 真机：扫码二维码导入订阅（相机权限弹窗 + 扫码成功）
- [ ] 7.2 真机：从剪贴板导入、直接内容导入、URL 导入均入库可连接
- [ ] 7.3 真机：设更新间隔后，到期重启自动更新生效
- [ ] 7.4 实施完成且真机通过后，按 archive 顺序（`p1-m4-multi-subscription-nav` 之后）`openspec archive p1-m6-add-subscription`
