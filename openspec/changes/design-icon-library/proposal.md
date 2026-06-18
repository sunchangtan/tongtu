## Why

项目图标现状：Flutter app 用 **28 种 Material 字体图标**（`Icons.*`），web 组件库几无图标，无自定义 / 统一图标资产——三端图标各行其是、无同源。设计系统已有 token / 组件 / logo 三端同步，唯独图标缺位。

经 brainstorming 确认五项决策：① **三端同步**图标库；② **统一 SVG 源 + pipeline**（single source，同 token 思路）；③ 图标集用 **Lucide**（ISC 许可，stroke 圆角风格契合双 T）；④ 范围**现用 28 + 常用扩展 ~60-80**（YAGNI）；⑤ Flutter 端生成 **IconFont**（用法接近现有 `Icons.*`、字体渲染内存友好）。

## What Changes

- 新建图标库**单一真相源**：`tools/icons/source/*.svg`（Lucide）+ `icons.json` 清单（`name` / `category` / `lucide` / `material` / `codepoint`）。
- 新建 `tools/icons/build.mjs` pipeline → 三端生成物：
  - **Flutter**：`TongtuIcons.ttf` + `tongtu_icons.g.dart`（`TongtuIcons` IconData）；替换现有 28 处 `Icons.*`。
  - **Web**：新 workspace 包 `@tongtu/icons`（`web/packages/icons`），生成 React 图标组件。
  - **Figma**：「Icons」组件库（SVG 导入建 component set）。
- 加图标 = 加 SVG + 清单条目 → 跑 build，三端联动。

## Capabilities

### Added Capabilities
- `design-icons`: 三端同步图标库——Lucide 单一 SVG 源经 pipeline 生成 Flutter IconFont / Web 组件 / Figma 组件库。

## Impact

- **tools/icons/**（新）：SVG 源、`icons.json`、`build.mjs`。
- **lib/ui/icons/**（新生成）：`TongtuIcons.ttf` + `tongtu_icons.g.dart`；`pubspec.yaml` 注册字体；28 处 `Icons.*` → `TongtuIcons.*`。
- **web/packages/icons/**（新）：`@tongtu/icons` 包；playground 加图标总览页。
- **Figma**：Tongtu Brand 文件新增「Icons」组件库。
- 许可证：Lucide ISC，兼容项目 GPL-3.0。
