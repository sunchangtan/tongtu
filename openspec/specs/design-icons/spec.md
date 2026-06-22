# design-icons Specification

## Purpose
TBD - created by archiving change design-icon-library. Update Purpose after archive.
## Requirements
### Requirement: 图标库单一 SVG 源与清单驱动
图标库必须（MUST）以一份 Lucide SVG（`tools/icons/source/*.svg`）为唯一真相源，并由 `tools/icons/icons.json` 清单（每图标含 `name` / `category` / `lucide` / `material` / `codepoint`）驱动；三端产物必须（MUST）由 `tools/icons/build.mjs` 从该源与清单生成，不得（MUST NOT）在任一端手工维护脱离源的图标。新增图标应当（SHALL）只改「源 + 清单」并重跑 build。

#### Scenario: 单一真相源
- **当** 查看图标库结构
- **则** 图标 SVG 仅存于 `tools/icons/source`，三端图标均为 `build.mjs` 生成物，无手工脱源副本

#### Scenario: 加图标只改源与清单
- **当** 新增一个图标
- **则** 只需加 SVG 与 `icons.json` 条目并重跑 build，三端联动更新，既有图标 codepoint 不变

### Requirement: Lucide 图标集与命名规范
图标库必须（MUST）采用 Lucide 图标集（24×24、2px stroke、圆角端），图标名应当（SHALL）沿用 Lucide 的 kebab-case 命名；收录范围必须（MUST）覆盖 Flutter 现用图标的 Lucide 等价，并应当（SHALL）按需扩展常用 UI 图标，不得（MUST NOT）全量纳入未使用的图标。

#### Scenario: 风格与命名统一
- **当** 查看任一图标
- **则** 为 Lucide stroke 圆角风格、名为 Lucide kebab-case，与双 T logo 直线圆角风格一致

#### Scenario: 覆盖现用图标
- **当** 查看图标清单
- **则** Flutter 原 28 个 Material 图标均有 Lucide 等价映射（`icons.json` 的 `material` 字段）

### Requirement: 三端同源落地形态
图标库必须（MUST）三端同源落地：Flutter 经生成的 IconFont（`TongtuIcons.ttf` + `tongtu_icons.g.dart` 的 `TongtuIcons` IconData）以 `Icon(TongtuIcons.<name>)` 使用；Web 经 `@tongtu/icons` 包的 React 组件使用；Figma 经「Icons」component set（`Icons/<name>`）使用。Flutter 现用 `Icons.*` 必须（MUST）替换为 `TongtuIcons.*`。

#### Scenario: Flutter IconFont
- **当** Flutter 取用图标
- **则** 用 `Icon(TongtuIcons.<name>)`（字体图标），不再用 `Icons.*` Material 图标

#### Scenario: Web 图标包
- **当** Web 取用图标
- **则** 经 `@tongtu/icons`（workspace 包）的 React 图标组件，而非内联 SVG 或第三方 package

#### Scenario: Figma 图标组件
- **当** 设计稿取用图标
- **则** 用「Icons」component set 的 `Icons/<name>` 组件

