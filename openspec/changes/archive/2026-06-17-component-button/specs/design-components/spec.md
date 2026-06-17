## ADDED Requirements

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
Button 的颜色、圆角、文字、内距必须（MUST）绑定对应 token（颜色 `sys/color`、圆角 `sys/ui/radius`、文字 `type/label`、内距 `sys/ui/space`），不得（MUST NOT）硬编码。

#### Scenario: 颜色绑 sys/color
- **当** 检查 filled 变体
- **则** 容器色绑 `sys/color/primary`、文字色绑 `sys/color/on-primary`

#### Scenario: 圆角/文字/内距绑 token
- **当** 检查任一变体
- **则** 圆角绑 `sys/ui/radius`、文字用 `type/label` type scale、水平内距绑 `sys/ui/space`

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
