## Why

当前 Button 的 token 从**三处**取：颜色靠 M3 `ColorScheme`（`app_theme` 的 `fromSeed` + copyWith）由框架自动取、尺寸分散在 `TongtuDimens`（padding / shape）与 `TongtuComp`（容器高 / 图标 / 描边宽）、字体走 `tongtuTextTheme`。用户痛点「尺寸从两个地方读取」即此碎片化的表征。

按组件库标准（M3 官方 comp 层 + MUI / Spectrum 等成熟库共识），最优是 **comp 层作为组件的单一入口**：组件只读 `comp/<组件>/*`，comp 内部经 alias 引 sys（语义透传）+ 承载组件固有值。据此重构 Button——收敛 token 入口、消除碎片化，并获得**组件级定制 / 换肤**能力（改 `comp/button/*` 只影响 Button，不动全局 sys）。

## What Changes

- 建完整 `comp/button/*` token：**颜色按变体**（filled / tonal / outlined / text / elevated，各引 `sys/color`）+ **disabled**（引 `sys/color/disabled-*`）+ **尺寸**（padding / shape 引 `sys/ui`，container-height / icon-size / outline-width 为固有字面值）。
- 管线 format（flutter / ts / css）支持 comp 下**多类型 token**：颜色（明暗两套）+ 尺寸（单套）。多级别名（comp→sys→ref）由 SD v4 原生解析、现有 source 已齐备，**无需改解析器**。
- Flutter `app_theme`：Button 各变体 `ButtonStyle` 显式从 comp 取色（明暗各一套，参数化生成）、尺寸取 comp；不再依赖 `ColorScheme` 自动取色与 `TongtuDimens` 混读。
- Web `theme.ts` / `Button.tsx`：从 `comp/button/*` 取色，替换硬引 `colorsLight`。
- Figma：Component collection 建 `comp/button/*` 变量（颜色 alias 引 sys.color 明暗、尺寸 alias 引 UI Dimension + 固有值）；Button 20 变体重绑到 comp（替换原绑 sys）。
- 审计门禁沿用（Button 全绑 comp / sys，0 未绑）。
- A3 其他组件沿此模板——本 change **不实施 A3**，仅立模板 + 管线支撑。

## Capabilities

### Modified Capabilities
- `design-tokens`: comp 层从「仅组件固有尺寸」升级为「组件单一入口」（引 sys + 固有值，颜色随明暗）；明确多级别名（comp→sys→ref）解析。
- `design-components`: Button 从「分散绑 sys/*」升级为「只读 `comp/button/*` 单一入口」；确立通用「组件 token 单一入口（comp）」需求。

## Impact

- **tokens/**：`comp.json` 大扩展（颜色按变体 + disabled + 尺寸）。
- **管线**：`format/{flutter,ts,css}.mjs` 支持 comp 多类型（颜色明暗 + 尺寸）；`build.mjs` 不变。
- **Flutter**：`lib/ui/tokens/tokens.g.dart`（生成物，新增 comp 颜色明暗类）、`lib/ui/app_theme.dart`（Button 显式设色，明暗各套）。
- **Web**：`web/src/theme.ts`、`web/src/Button.tsx`（取 comp 色）。
- **Figma**：`comp/button/*` 变量 + Button 20 变体重绑。
- **门禁**：`tools/figma-audit`（审计 Button 绑 comp）。
- **文档**：`docs/design/component-contract.md`（comp 单一入口契约 + 范围）。
