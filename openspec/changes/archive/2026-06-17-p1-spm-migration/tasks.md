## 1. SPM 集成

- [x] 1.1 查依赖 SPM 支持（`shared_preferences` / `share_plus` 均支持；移除多余 `path_provider`）
- [x] 1.2 `flutter config --enable-swift-package-manager` + `pub get` 生成 `FlutterGeneratedPluginSwiftPackage`
- [x] 1.3 build 验证 SPM 集成（pbxproj 注入 17 处 SPM 引用、Xcode resolve、编译通过）

## 2. 移除 CocoaPods

- [x] 2.1 `pod deintegrate`（用 `LANG=en_US.UTF-8` 解决 ASCII-8BIT 编码报错）
- [x] 2.2 删 `Podfile`/`Podfile.lock` + 清理 `Debug/Release.xcconfig` 的 Pods include
- [x] 2.3 验证 MihomoCore(4)/PacketTunnel(27)/SPM(17) 保留、Pods 引用归 0

## 3. 验证（构建期，SPM 不依赖真机）

- [x] 3.1 纯 SPM build 成功（device 目标 `--no-codesign`，无 `pod install`、无 `frameworks.sh`、更快 13.9s）
- [x] 3.2 Dart 门禁：`flutter analyze` 0 + `flutter test` 25 个通过
- [x] 3.3 确认 `MihomoCore.xcframework` + PacketTunnel target 保留、CocoaPods 完全移除（`No traces of CocoaPods left`）
