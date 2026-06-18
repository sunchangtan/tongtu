# design-components Specification

## Purpose
TBD - created by archiving change component-button. Update Purpose after archive.
## Requirements
### Requirement: 组件契约规范（框架中性 + 跨端映射）
组件库必须（MUST）定义一套框架中性的组件契约：variant properties（`variant` / `size` / `state` / `icon`）命名与状态枚举全库统一，不得（MUST NOT）绑定某一端框架的结构。每个组件应当（SHALL）标注 Flutter 与 Web(MUI) 的跨端映射；当某端无原生对应（如 MUI 无 tonal/elevated）时，必须（MUST）显式标注由该端自定义。

#### Scenario: 中性 variant 命名
- **当** 查看组件契约
- **则** variant properties 用框架中性命名（`variant`/`size`/`state`/`icon`），不含 Flutter 或 MUI 专有词

#### Scenario: 跨端映射齐备
- **当** 查看任一变体
- **则** 标注其 Flutter widget 与 Web/MUI 配置；无原生对应者显式标注「自定义」

### Requirement: Button 完整 M3 变体
Button 必须（MUST）提供 M3 五变体——elevated / filled / tonal / outlined / text；每变体必须（MUST）含 enabled 与 disabled 两态，并支持有无前置图标（`icon` = none / leading）。

#### Scenario: 五变体齐备
- **当** 查看 Button 组件
- **则** 含 elevated / filled / tonal / outlined / text 五变体

#### Scenario: 状态与图标
- **当** 查看任一 Button 变体
- **则** 具备 enabled / disabled 两态，且可切换有无前置图标

### Requirement: Button 绑 token
Button 的颜色、圆角、文字内距、结构尺寸必须（MUST）经 `comp/button/*` 单一入口取用（字体除外，走全局 type scale），不得（MUST NOT）硬编码、不得（MUST NOT）跳过 comp 直接读 `sys/*` 或框架 `ColorScheme`；`comp/button/*` 内部必须（MUST）经 alias 引 sys（颜色 → `sys/color`、内距 / 圆角 → `sys/ui`）。

#### Scenario: 颜色只读 comp
- **当** 检查 filled 变体
- **则** 容器色取 `comp/button/filled/container-color`（内部引 `sys/color/primary`）、文字色取 `comp/button/filled/label-color`（内部引 `sys/color/on-primary`）

#### Scenario: 圆角 / 内距只读 comp
- **当** 检查任一变体
- **则** 圆角取 `comp/button/shape`（引 `sys/ui/radius/full`）、水平内距取 `comp/button/padding-horizontal`（引 `sys/ui/space/xl`）

#### Scenario: 结构尺寸只读 comp
- **当** 检查容器高 / 图标尺寸 / 描边宽
- **则** 各取 `comp/button/container-height`、`comp/button/icon-size`、`comp/button/outline-width`

#### Scenario: 不跳读 sys
- **当** 审视 Button 三端取色 / 取尺寸
- **则** 经 `comp/button/*` 单一入口，不直接读 `sys/*` 或 `ColorScheme`（字体走 type scale 除外）

### Requirement: Button 三端实现
Button 必须（MUST）在三端实现——Figma 组件、Flutter widget、Web(React-MUI) 组件；三端应当（SHALL）遵循同一中性契约（variant/state/icon），跨端外观与语义一致（颜色取自同源 token；M3 与 MUI 差异按契约处理）。

#### Scenario: 三端齐备
- **当** 查看 Button 标杆
- **则** Figma / Flutter / Web 三端均有实现，且遵循同一 variant 契约

#### Scenario: 跨端一致（语义 / token 一致，非像素）
- **当** 在三端使用同一 variant（如 filled）
- **则** 语义与 token 一致（颜色取自同源 token）；因 M3 与 MUI-M2 渲染不同，不要求像素对齐；MUI 无原生的 tonal / elevated 由 Web 自定义达成同等语义

### Requirement: Code Connect 绑定
Button 必须（MUST）经 Code Connect 绑定到代码——Web(React) 用官方 `figma.connect`，Flutter 用 template files；使 Figma Dev Mode 能显示对应端的真实代码片段，并随 variant 变化。

#### Scenario: React Code Connect
- **当** 在 Figma Dev Mode 查看 Button（React 上下文）
- **则** 显示对应的 React-MUI 代码片段，随 variant 变化

#### Scenario: Flutter Code Connect
- **当** 在 Figma Dev Mode 查看 Button（Flutter 上下文）
- **则** 经 template files 显示对应的 Flutter 代码片段

### Requirement: 组件属性全绑 token（审计门禁）
组件的所有可 token 化属性——颜色、圆角、间距、字号、结构尺寸——必须（MUST）绑定变量，不得（MUST NOT）硬编码。disabled 态颜色必须（MUST）绑**带 alpha 的 disabled 语义色变量**（α 由变量提供，不用手设图层 opacity）。唯一豁免：padding=0（无内距）。必须（MUST）有审计门禁扫描组件并报告未绑项；新组件（A3）须通过审计方视为完成。

#### Scenario: 审计报告未绑
- **当** 对组件运行 token 绑定审计
- **则** 列出所有未绑变量的可 token 化属性（fills / strokes 色、圆角、内距、itemSpacing、结构尺寸）

#### Scenario: disabled 全绑（无豁免）
- **当** 审计遇到 disabled 态的 fill / stroke 色
- **则** 须为绑定的 disabled 语义色变量（带 alpha）；未绑则报为违规（不再豁免）

#### Scenario: 通过判据
- **当** 组件除 padding=0 外无未绑属性
- **则** 审计通过

### Requirement: 组件结构尺寸绑 comp token
组件结构尺寸（容器高、图标尺寸、描边宽等）必须（MUST）绑 comp 层 token，不得（MUST NOT）用魔法数字。

#### Scenario: 结构尺寸绑 comp
- **当** 检查 Button 容器高 / 图标尺寸 / 描边宽
- **则** 各绑对应 `comp/button/*` token

### Requirement: 组件 token 单一入口（comp）
组件的所有可 token 化外观属性（颜色、圆角、内距、结构尺寸）必须（MUST）经 `comp/<组件>/*` 单一入口取用，不得（MUST NOT）跳过 comp 直接读 `sys/*` 或框架默认（如 `ColorScheme`）；comp 内部应当（SHALL）经 alias 引 sys 实现语义透传。字体不在此入口（走全局 type scale）。此入口必须（MUST）使组件级定制成为可能——改 `comp/<组件>/*` 仅影响该组件，不动全局 sys。

#### Scenario: 组件只读 comp
- **当** 审视组件三端取用的颜色 / 尺寸
- **则** 均来自 `comp/<组件>/*`，无直接读 `sys/*` 或 `ColorScheme`

#### Scenario: 组件级定制
- **当** 仅修改某组件的 `comp/<组件>/*` token
- **则** 只该组件外观改变，全局 sys 与其他组件不受影响

#### Scenario: 字体例外
- **当** 查看组件字体来源
- **则** 取自全局 type scale（`type/*`），不经 comp

