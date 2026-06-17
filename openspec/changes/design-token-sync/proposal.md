## Why

通途规划三端组件库（Figma 设计 / Flutter app / Web React-MUI），三端必须共享同一套设计 token，否则各自漂移、改一处要手动改三处、终将不一致。需要一套**跨栈 token 同步管线**：以 Figma 变量为单一真相源，产出标准 token 文件，自动生成各端可用 token（Flutter Dart + CSS），实现单一真相源、跨栈一致。这是组件库的**子项目 0（根基）**，须先于组件实现。参照业界主流（Material / Spectrum / Primer）：W3C DTCG 格式 + Style Dictionary 转换。完整设计见 `docs/design/token-sync-design.md`（v1.1）。

## What Changes

- 新建 `tokens/`：W3C DTCG 格式 token 源（`ref` 基础色 + `sys` 语义色明暗两套 + 维度），提交 git 作单一真相源；由 agent 半自动从 Figma 变量导出（Figma Variables REST API 仅 Enterprise 可用、当前 Organization plan，故半自动起步）。
- 引入 Style Dictionary（Node，隔离于 `tools/style-dictionary/`），显式开启 `usesDtcg`；用 `build.mjs` 以 SD Node API 编排明暗两套解析。
- 生成 Flutter `lib/ui/tokens/tokens.g.dart`（明暗两组语义色常量 + 共享维度常量）与 `web/tokens/tokens.css`（`:root` 浅 + `[data-theme=dark]` 深）。
- `lib/ui/app_theme.dart` 从硬编码颜色改为引用生成常量：`ColorScheme.fromSeed` 打底 + 生成常量 `copyWith` 覆盖品牌关键角色，`AppTheme.light/dark` 对外接口不变。
- 新增手动同步流程 + README。

## Capabilities

### New Capabilities
- `design-tokens`: 跨栈设计 token 的单一真相源与生成管线——DTCG 格式 token 源（ref/sys、明暗 token sets）、生成 Flutter 与 CSS 产物、跨栈同值、app 主题引用生成 token。

### Modified Capabilities
<!-- 无：design-tokens 为新增独立能力。app_theme 改为引用生成 token 是实现细节，AppTheme.light/dark 对外接口不变，不改 flutter-app-shell 既有需求契约。 -->

## Impact

- **新增**：`tokens/`（DTCG 源）、`tools/style-dictionary/`（Node 工具链，隔离）、`web/tokens/tokens.css`（生成物）、`lib/ui/tokens/tokens.g.dart`（生成物）。
- **修改**：`lib/ui/app_theme.dart`（颜色值来源改为生成常量，接口不变；`main.dart` 无需改）。
- **依赖**：引入 Node + style-dictionary v4（隔离 `tools/`，将来与 Web/React 子项目共享；不影响 Flutter / Go 构建路径）。
- **specs**：新增 `design-tokens`。
- **不涉及 iOS NE 内存红线**：纯构建期工具 + Flutter app 端，无扩展进程改动。
- **范围外（future）**：字体 / 阴影 / 动效 token；React 组件本身（后续子项目）；CI 自动化（Figma webhook → build → PR）；REST / Tokens Studio 全自动导出；M3 全 40+ 角色自算（现 fromSeed 打底，详见 design.md D3）。
