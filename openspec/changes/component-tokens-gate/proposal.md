## Why

A2 核对发现 Button 组件**未全绑变量**：`itemSpacing`、组件结构尺寸（container-height 40 / icon-size 18 / outline-width 1 / 垂直内距）硬编码。要让组件库 token 纪律可靠，须**严格全绑** + **审计门禁**防复发。结构尺寸 sys 层无对应档，需建 **comp 层 token**（M3 component tokens）。disabled 态的 `on-surface` opacity 因 Figma「paint 绑 color 变量 + opacity」冲突无法绑，是平台硬限制，门禁豁免。

## What Changes

- **建 comp 层 token**：`comp/button/container-height=40`、`icon-size=18`、`outline-width=1`（Figma 新集合 + 纳入同步管线，生成 Flutter/CSS/TS）。
- **Button 全绑重绑**：Figma（height→comp、icon→comp、stroke→comp、itemSpacing→`sys/ui/space/sm`、去冗余垂直内距改用 height+居中）；Flutter / Web 组件改用 comp token。
- **审计门禁**：Figma token 绑定审计脚本（扫组件，报未绑的可 token 化属性；仅 disabled opacity 豁免），A3 每组件跑。

## Capabilities

### Modified Capabilities
- `design-tokens`: 增加 **comp 层**（组件级 token），随管线生成三端产物。
- `design-components`: 增加「组件可 token 化属性必须绑变量（审计门禁）」与「结构尺寸绑 comp token」。

## Impact

- **Figma**：新增 comp token 集合；Button 重绑。
- **tokens/**：新增 `comp.json`。
- **管线**：`build.mjs` 生成 comp 产物（Flutter `TongtuComp` / CSS / TS）。
- **Flutter/Web**：组件改用 comp token（app_theme component theme、TongtuButton、MUI theme）。
- **门禁**：`tools/` 下 Figma 审计脚本（agent 跑）。
- **豁免**：disabled 态 opacity 色（Figma paint 限制，已查证）。
