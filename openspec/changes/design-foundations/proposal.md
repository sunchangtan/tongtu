## Why

组件库（子项目 A）的组件文字需要完整 type scale，但子项目 0 只做了字号数值（`sys/ui/font` 6 档），缺完整 M3 type scale（display~label 语义档 + 字重/行高/字间距）。同时设计系统需要 Foundations 基础展示页（颜色/字体/间距/圆角可视化）。**A1（基础阶段）补这两块，作为 A2/A3 组件的前置**。总体设计见 `docs/design/component-library-design.md`。

## What Changes

- **补全 typography**：M3 type scale（display/headline/title/body/label × Large/Medium/Small = 15 档，每档 size/weight/lineHeight/letterSpacing）作为 Figma **Text Styles**；扩 token 同步管线：DTCG typography composite → Flutter `TextTheme` + CSS。
- **Foundations 展示页**（Figma 设计资产）：色板（tonal 色阶 + 语义色明暗对照）、字阶样板、间距/圆角标尺。
- `app_theme.dart` 接入生成的 `TextTheme`（`ThemeData.textTheme`）。

## Capabilities

### Modified Capabilities
- `design-tokens`: 扩展同步范围，新增 typography（M3 type scale）——Figma Text Styles → DTCG composite token → Flutter `TextTheme` + CSS typography，并保持跨栈同值。

## Impact

- **新增**：`tokens/typography.json`（DTCG composite type scale）；Figma Text Styles（15 档）+ Foundations 展示页。
- **修改**：`tools/style-dictionary/`（扩 `build.mjs` + 新 typography format，处理 composite → Flutter `TextTheme` + CSS）；`lib/ui/tokens/tokens.g.dart`（加 typography）；`web/tokens/tokens.css`（加 typography）；`lib/ui/app_theme.dart`（`ThemeData` 接入 `textTheme`）。
- **specs**：MODIFIED `design-tokens`（加 typography 需求）。
- **不涉及 iOS NE 内存**：构建期工具 + Flutter app 端。
- **范围外（future）**：组件本身（A2/A3）；阴影/动效 token；自定义品牌字体家族（v1 fontFamily 不锁定，由各端默认，type scale 值本身字体无关）。
