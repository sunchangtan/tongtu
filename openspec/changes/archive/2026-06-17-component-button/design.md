## Context

A2 是子项目 A 的标杆阶段，按**按组件垂直三端**走完 Button：Figma 设计 → Flutter 代码 → Web(React-MUI) 代码 → Code Connect 绑定。用三端实际代码验证跨端契约，而非纸面映射。承接 A1（token + typography 已就绪）。

关键约束：
- 契约**框架中性**；M3(Flutter) 与 M2(MUI) 差异显式标注。
- 组件**绑 token**（A1 / 子项目 0）。
- 三端代码 + Code Connect 真打通。

## Goals / Non-Goals

**Goals:**
- 组件契约规范（中性 variant/size/state/icon + token 绑定 + 跨端映射）。
- Button 三端实现：Figma Component Set + Flutter widget + React-MUI 组件。
- Code Connect：React 官方 `figma.connect` + Flutter template files。
- 首建 Web React + MUI 工程（消费 token）。

**Non-Goals:**
- 其余组件（A3）。
- 交互态（hover/focus/pressed）逐一画稿——代码按 M3 实现。
- size 多档（v1 标准，契约预留）。

## Decisions

### D1：variant = M3 五变体
`variant ∈ {elevated, filled, tonal, outlined, text}`。

### D2：state = enabled / disabled（画稿）
Figma 与代码画 enabled + disabled；hover/focus/pressed 交互态由代码按 M3 实现，契约标注。

### D3：size v1 标准一档
标准高度 40；`size`（small/large）契约预留，A3/future。

### D4：icon = none / leading

### D5：token 绑定（M3 配色，用现有 sys/color）
| variant | 容器 | 文字/图标 | 描边 |
|---|---|---|---|
| filled | `primary` | `on-primary` | — |
| tonal | `secondary-container` | `on-secondary-container` | — |
| outlined | 透明 | `primary` | `outline` |
| text | 透明 | `primary` | — |
| elevated | `surface` | `primary` | —（+阴影 future）|

圆角 `sys/ui/radius/full`、文字 `type/label/large`、内距 `sys/ui/space`；disabled 用 `on-surface` 透明度（容器 12% / 文字 38%）。

> **elevated 局限（C）**：M3 elevated = surfaceContainerLow 容器 + 阴影区分；我们 sys/color 缺 surfaceContainer 系列、未做 elevation token，浅色下 elevated（surface 容器 + 无阴影）视觉偏弱。v1 保留五变体（尊重「完整 M3」），但 elevated 视觉**待补 surfaceContainer + elevation token 完善**；实施若浅色立不住，暂用 `surface-variant` 近似 + 标注。

### D6：跨端映射（契约核心）
| 中性 variant | Flutter | Web/MUI |
|---|---|---|
| filled | `FilledButton` | `variant="contained"` |
| outlined | `OutlinedButton` | `variant="outlined"` |
| text | `TextButton` | `variant="text"` |
| tonal | `FilledButton.tonal` | 自定义（secondary container 色） |
| elevated | `ElevatedButton` | 自定义（contained + elevation） |

### D7：Figma Component Set 结构
variant(5) × state(2) × icon(2) = 20 variants；properties `Variant`/`State`/`Icon`。

### D8：三端实现 + Flutter 三层方案（兼顾扩展 + 样式定制）
顺序：Figma → Flutter → Web。Flutter 端采用三层，避免「裸 widget 无扩展」与「厚 wrapper 重写样式」两个极端：
1. **样式层**：`app_theme` 加 component themes（`filledButtonTheme`/`outlinedButtonTheme`/… 定义 shape=`radius/full`、padding=`space/xl`、textStyle=`label/large`），样式集中、改一处全局生效；+ `ThemeExtension<TongtuTokens>` 放 M3 没有的通途自定义（扩展预留）。
2. **组件层**：薄 `TongtuButton({variant, onPressed, label, leadingIcon})`，按 variant 委托对应 M3 widget（filled→`FilledButton`…），**不写死样式**（继承样式层）；提供统一 variant API（对齐 MUI）+ 扩展点 + Code Connect 单入口。
3. **token 层**：颜色 `ColorScheme`、字 `textTheme`、维度 `TongtuDimens`（已有）。

**Web**：React-MUI 组件，variant→MUI 映射（见 D6 / D10）。

### D9：Code Connect
- **React**：`@figma/code-connect` 官方集成，`Button.figma.tsx` 用 `figma.connect()` 映射 Figma Button → React Button（variant 等用 `figma.enum`）。
- **Flutter**：无官方集成 → **template files**（框架无关），手写模板把 Figma Button 映射为 Flutter 代码片段，随 variant 变化。

### D10：Web React + MUI 工程（首建）
`web/` 下建 Vite + React + TypeScript + MUI 工程；消费 token（`createTheme` 引 token 值 / 或 `tokens.css` CSS vars）；Button 为 React 组件，中性 variant → MUI 配置；tonal/elevated MUI 无原生 → 自定义。隔离于 `web/`，不影响 Flutter / Go。

## Open Questions（评审/实施时定）

- React 脚手架：Vite（轻，倾向）vs Next。
- React 消费 token：`createTheme` 引 JS token 值 vs CSS vars（倾向前者，MUI 原生）。
- elevated 是否 v1 就补 surfaceContainer + elevation token（倾向 future，先 surface-variant 近似）。

## Risks / Trade-offs

| 风险 | 应对 |
|------|------|
| A2 大（三端 + 工程 + Code Connect） | tasks 分阶段；标杆一次立全，A3 铺其余组件快 |
| Flutter 无官方 Code Connect | template files（框架无关），手写模板维护 |
| M3 ≠ MUI（tonal/elevated 无原生） | 契约显式标注，Web 自定义实现 |
| React 工程是新基础设施 | 隔离 `web/`（像子项目 0 的 Style Dictionary） |

## Migration Plan

1. 契约文档 `component-contract.md`。
2. Figma Button Component Set（绑 token）。
3. Flutter Button widget（`lib/ui/components/`）+ 测试。
4. Web React+MUI 工程 + React Button。
5. Code Connect（React 官方 + Flutter template）。

回滚：均为新增设计资产/代码/工程，无破坏性。
