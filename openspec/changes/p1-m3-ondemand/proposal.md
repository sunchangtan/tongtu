## Why

当前通途仅支持手动连接/断开：用户每次切换网络环境（回家连可信 WiFi、出门转蜂窝）都要手动开关隧道。iOS 提供系统级按需连接（`NEOnDemandRule`），可按网络条件自动启停隧道，是主流代理客户端标配，能显著降低日常操作成本。P1-M3 设置页基座已就绪，正适合在其下接入按需连接。

## What Changes

- 新增 Dart 统一语义模型 `OnDemandConfig`（总开关 + 触发范围 `all/wifiOnly/cellularOnly` + 信任 WiFi 列表），`shared_preferences` 持久化。
- 新增设置页「按需连接」入口 → `OnDemandPage` 子页：总开关、触发范围 `SegmentedButton`、信任 WiFi 列表（增删 + 手动输入 + 「添加当前 WiFi」）。
- Swift 新增 `OnDemandRuleBuilder`：语义配置 → `[NEOnDemandRule]` **纯函数**翻译（有序首匹配，信任 SSID 优先 `Disconnect`、再按触发范围 `Connect`/`Disconnect`）。
- `TunnelController` 注入 `onDemandRules` + `isOnDemandEnabled`：配置改动即时 `saveToPreferences` 生效，`start()` 时一并下发。
- MethodChannel 新增 `updateOnDemand` / `currentSSID`。
- 读取当前 WiFi 自动填充：补 `com.apple.developer.networking.wifi-info` entitlement + `NSLocationWhenInUseUsageDescription` + `CLLocationManager` 授权 + `NEHotspotNetwork.fetchCurrent`。
- Runner 主 App `IPHONEOS_DEPLOYMENT_TARGET` 对齐 15.0（消除「主 App 13.0 < 扩展 15.0」既有矛盾，使 iOS 14+ API 直用、避免无意义 `@available`）。

## Capabilities

### New Capabilities
- `ondemand-connection`: iOS 系统级按需连接——统一语义规则模型与持久化、语义→`NEOnDemandRule` 映射、主 App 经 `NETunnelProviderManager` 注入按需规则、读取当前 WiFi SSID、设置页配置 UI。

### Modified Capabilities
<!-- 无：按需连接对 NE 隧道的注入作为本新能力的需求承载，不改 apple-packet-tunnel 已确认需求 -->

## Impact

- **新增代码**：`lib/ondemand/`（语义模型 + 持久化）、`lib/ui/ondemand_page.dart`、`ios/Runner/OnDemandRuleBuilder.swift` + 对应 `RunnerTests` XCTest。
- **修改代码**：`lib/ui/settings_page.dart`（加入口）、`ios/Runner/AppDelegate.swift`（`TunnelController` 注入 + `currentSSID` 通道）、`ios/Runner/Runner.entitlements`、`ios/Runner/Info.plist`、`ios/Runner.xcodeproj/project.pbxproj`（deployment target）。
- **依赖**：无新增第三方（`CoreLocation`/`NetworkExtension` 系统框架；复用 `shared_preferences`）。
- **权限**：定位 When-In-Use + Access WiFi Information entitlement。
- **真机 gate**：on-demand 实际触发（连 WiFi 自动起/信任 SSID 断/蜂窝行为）、读取当前 WiFi（需 location 授权后 ssid 非 nil）。
