## ADDED Requirements

### Requirement: iOS 依赖经 Swift Package Manager 管理
iOS 原生插件依赖应当（SHALL）经 Swift Package Manager 管理；项目不得（MUST NOT）保留 CocoaPods 集成（`Podfile`、`Pods/` 目录、pbxproj 的 Pods 引用）。

#### Scenario: 插件经 SPM 解析
- **当** 执行 iOS 构建
- **则** `shared_preferences` / `share_plus` 等插件经 `FlutterGeneratedPluginSwiftPackage` 由 SPM 解析，不经 CocoaPods

#### Scenario: 无 CocoaPods 残留
- **当** 检查 iOS 工程
- **则** 无 `Podfile`、无 `Pods/` 目录、pbxproj 无 Pods 引用，构建不执行 `pod install`

### Requirement: 自定义 xcframework 与 NE target 不受 SPM 迁移影响
SPM 迁移后，手动集成的 `MihomoCore.xcframework` 与 PacketTunnel 扩展 target 必须（MUST）完整保留并正常构建。

#### Scenario: MihomoCore 与 PacketTunnel 保留
- **当** SPM 迁移完成后执行构建
- **则** `MihomoCore.xcframework` 经手动 Embed Frameworks 嵌入、`PacketTunnel.appex` 经 Embed App Extensions 嵌入，构建成功
