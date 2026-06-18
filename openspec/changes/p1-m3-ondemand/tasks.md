## 1. Dart 语义模型与持久化（TDD）

- [x] 1.1 `lib/ondemand/ondemand_config.dart`：`OnDemandConfig`（enabled / scope / trustedSSIDs）+ `OnDemandScope{all,wifiOnly,cellularOnly}` + JSON 序列化 + `copyWith`
- [x] 1.2 `lib/ondemand/ondemand_store.dart`：`shared_preferences` 持久化（load/save，缺省=关闭/全部/空）
- [x] 1.3 单测：序列化往返、缺省值、scope 枚举映射、trustedSSIDs 增删边界

## 2. Swift 规则映射纯函数（XCTest）

- [x] 2.1 确认 `RunnerTests` 可 `@testable import Runner`（已确认 TEST_HOST/BUNDLE_LOADER 配置）；builder 逻辑另经 iOS Simulator `simctl spawn` 本地运行验证
- [x] 2.2 `ios/Runner/OnDemandRuleBuilder.swift`：`build(config) -> [NEOnDemandRule]`（信任 `Disconnect` 置顶 + 范围映射 + 兜底 `Disconnect(.any)`）
- [x] 2.3 XCTest：信任置顶且 `ssidMatch` 含全部 SSID；各范围生成的子类与 `interfaceTypeMatch` 断言；空/关闭配置（11 断言 simctl 运行通过）

## 3. NE 注入与生效（Swift）

- [x] 3.1 `TunnelController.applyOnDemand(config)`：设 `onDemandRules` + `isOnDemandEnabled` → `saveToPreferences`（即时生效，manager 不存在则 `makeManager`）
- [x] 3.2 `start()` 与 on-demand 解耦：复用 manager 持久化的 `onDemandRules`（`start` 的 `saveToPreferences` 不覆盖未改属性，代码 review 确认）
- [x] 3.3 MethodChannel `updateOnDemand`（解析 args → `applyOnDemand`）

## 4. 读取当前 WiFi（Swift + 权限）

- [x] 4.1 `Runner.entitlements` 加 `com.apple.developer.networking.wifi-info`；`Info.plist` 加 `NSLocationWhenInUseUsageDescription`（中文文案）
- [x] 4.2 MethodChannel `currentSSID` + `WiFiSSIDReader`：`CLLocationManager` 授权 + `NEHotspotNetwork.fetchCurrent`；未授权返回错误码（iOS typecheck 通过）。新文件 `OnDemandRuleBuilder.swift`/`WiFiSSIDReader.swift` 注册进 Runner target（plutil + xcodebuild -list 验证）
- [x] 4.3 Runner 主 App `IPHONEOS_DEPLOYMENT_TARGET` 对齐 15.0（project-level 13.0→15.0，残留 0）

## 5. 设置页 UI（Dart，TDD）

- [x] 5.1 `lib/ui/ondemand_page.dart`：总开关 + 触发范围 `SegmentedButton` + 信任列表增删 + 「添加当前 WiFi」+ 关闭时禁用下方 + 自动重连文案提示
- [x] 5.2 `lib/ui/settings_page.dart` 加「按需连接」入口（push `OnDemandPage`）
- [x] 5.3 Dart 侧通道封装 `updateOnDemand` / `currentSSID`（`OnDemandController`）
- [x] 5.4 widget 测试：开关/范围切换/列表增删/mock channel `currentSSID`（成功 + 拒绝降级）/关闭禁用

## 6. 质量门禁

- [x] 6.1 `flutter analyze` 0 警告 0 错误 + `dart format` + `flutter test` 全过（83 测试）
- [x] 6.2 `swiftlint --strict`（4 文件 0）+ 完整 `flutter build ios` 编译通过（新文件入编译、AppDelegate NE 调用链接验证）+ `RunnerTests` XCTest（逻辑经 `simctl spawn` 等价验证；`xcodebuild test` 执行归真机/CI gate）
- [x] 6.3 `openspec validate p1-m3-ondemand --strict` 通过

## 7. 真机验证与归档（gate）

- [ ] 7.1 真机：开启按需连接，连信任 WiFi 自动断开（直连）、其他网络按触发范围自动连接
- [ ] 7.2 真机：「添加当前 WiFi」授权后读到 SSID；拒绝授权时降级提示，手动输入仍可用
- [ ] 7.3 实施完成且真机通过后，按 archive 顺序（`p1-m3-settings-page` 之后）`openspec archive p1-m3-ondemand`
