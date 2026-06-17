## Why

Flutter 3.44 默认启用 Swift Package Manager（SPM），CocoaPods 是逐步被取代的旧依赖管理方式。趁 iOS 工程在改、在用插件都支持 SPM 时一次迁移到位，避免后续被迫迁移；并消除 CocoaPods 的 `Pods-Runner-frameworks.sh` 在处理大型 `MihomoCore.xcframework` 时的内存峰值（OOM）问题。

## What Changes

- 启用 SPM，iOS 原生插件（`shared_preferences`、`share_plus`）改由 SPM 管理。
- **BREAKING（构建层）**：`pod deintegrate` 移除 CocoaPods——删除 `Podfile`/`Podfile.lock`、清理 Flutter `Debug/Release.xcconfig` 的 Pods include。
- `MihomoCore.xcframework`（手动 Embed Frameworks）+ PacketTunnel NE target 保持不变（本就不依赖 CocoaPods）。
- 移除未实际使用的 `path_provider` 依赖。

## Capabilities

### New Capabilities
- `ios-dependency-management`: iOS 原生依赖经 Swift Package Manager 管理（取代 CocoaPods），自定义 xcframework 与 NE 扩展 target 不受影响、构建保持成功。

### Modified Capabilities
<!-- 无：纯构建/依赖管理方式变更，不改变 apple-packet-tunnel / core-bridge 既有对外需求。 -->

## Impact

- **iOS 工程**：Flutter SPM 集成（`FlutterGeneratedPluginSwiftPackage`）；pbxproj 加 SPM package reference、移除 CocoaPods 引用；xcconfig 清理；删 `Podfile`。
- **依赖**：`pubspec.yaml` 移除 `path_provider`。
- **构建**：纯 SPM build（更快）；`Pods-Runner-frameworks.sh` 移除（消除之前 OOM）。
- **不影响**：`MihomoCore.xcframework`、PacketTunnel target、Dart/Go 业务代码。
