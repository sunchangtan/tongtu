## Context

Flutter 3.44 默认开 SPM；项目此前因升级混乱临时禁用 SPM、回退 CocoaPods。现在用插件都支持 SPM。工程特殊性在于手动注入的 `MihomoCore.xcframework`（gomobile 产物）与 PacketTunnel NE target，迁移需确保两者不受影响。

## Goals / Non-Goals

**Goals:** 纯 SPM 依赖管理；移除 CocoaPods；保留 MihomoCore/PacketTunnel；消除 `frameworks.sh` OOM。

**Non-Goals:** 改业务功能；改 MihomoCore 的 gomobile 构建；把 MihomoCore 转成 SPM binaryTarget。

## Decisions

### D1：纯 SPM，移除 CocoaPods
启用 SPM + `pod deintegrate`，删 `Podfile`、清 xcconfig 的 Pods include。
- **备选**：保留 CocoaPods 空壳（混合）→ 构建仍跑多余 `pod install` + `Pods-Runner-frameworks.sh` 的 OOM 风险，否决。

### D2：MihomoCore.xcframework 保持手动 Embed
MihomoCore 经 pbxproj 的 Frameworks + Embed Frameworks phase 手动集成（不依赖 CocoaPods，也不转 SPM binaryTarget）。
- **理由**：手动 embed 已工作、改动最小；转 SPM binaryTarget 需重构、无收益。

### D3：之前 fail 的根因（取证结论）
- `Missing package product 'shared-preferences-foundation'` = Flutter 升级时的混乱状态，干净启用 SPM 后不复现。
- `pod deintegrate` 报 `Unicode Normalization ... ASCII-8BIT` = 终端 LANG 非 UTF-8，用 `LANG=en_US.UTF-8` 解决。

## Risks / Trade-offs

- **团队成员需启用 SPM**（`flutter config --enable-swift-package-manager`，全局）→ Flutter 3.44 默认开，影响小。
- **SPM 是构建期依赖**：`flutter build ios`（device 目标）成功即证明 SPM 集成与 device 编译通过；真机 run 验证的是功能（日志/数据通路），不额外验证 SPM。

## Migration Plan

已完成：启用 SPM → build 验证集成 → `pod deintegrate` → 清理 xcconfig/Podfile → 纯 SPM build 成功。

回滚：`git revert`（CocoaPods 配置与 pbxproj 旧态在 git 历史中）。
