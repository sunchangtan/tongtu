## 1. 组件契约规范

- [ ] 1.1 写 `docs/design/component-contract.md`：中性 variant properties（`variant`/`size`/`state`/`icon`）、状态枚举、token 绑定约定、Flutter↔MUI 跨端映射
- [ ] 1.2 自检：契约框架中性、可复制到其他组件（A3 模板性）

## 2. Figma Button Component Set

- [ ] 2.1 取证：Figma Component Set / variant properties API（`createComponent`/`combineAsVariants`）
- [ ] 2.2 建 Button 五变体 × state(enabled/disabled) × icon(none/leading)，auto-layout + 绑 token（D5 配色、圆角 radius/full、文字 type/label/large、内距 sys/ui/space）
- [ ] 2.3 截图核对：五变体浅/深配色正确、disabled 符合 M3、圆角/文字/内距来自 token

## 3. Flutter Button（三层方案，TDD）

- [ ] 3.1 样式层：`app_theme` 加 component themes（`filledButtonTheme`/`outlinedButtonTheme`/… shape=radius/full、padding=space/xl、textStyle=label/large）+ `ThemeExtension<TongtuTokens>`（扩展预留）
- [ ] 3.2 组件层：薄 `lib/ui/components/button.dart`（`TongtuButton(variant)` 委托 M3 widget，样式继承 theme、不写死）
- [ ] 3.3 widget 测试：variant 映射、样式取自 theme、disabled 态；`dart analyze` 0 + `dart format` + `flutter test`（fvm）

## 4. Web React + MUI 工程 + React Button

- [ ] 4.1 首建 `web/` React+MUI 工程（Vite + TS + MUI）；消费 token（`createTheme` 引 token 值 / 或 `tokens.css`）
- [ ] 4.2 React Button：中性 variant → MUI 配置（filled/outlined/text 原生；tonal/elevated 自定义）
- [ ] 4.3 冒烟：渲染各变体（简单页面；Storybook 留 future）；lint 通过

## 5. Code Connect

- [ ] 5.1 React：`@figma/code-connect` + `Button.figma.tsx`（`figma.connect`，variant 用 `figma.enum`）
- [ ] 5.2 Flutter：template files（框架无关）绑 Figma Button → Flutter 代码片段
- [ ] 5.3 验证：Figma Dev Mode 显示 React / Flutter 代码片段且随 variant 变化

## 6. 验证与归档

- [ ] 6.1 契约自检 + 三端一致核对（同一 variant 三端外观/语义一致）
- [ ] 6.2 质量门禁：Flutter analyze 0 / test 全过（fvm）；Web lint 通过
- [ ] 6.3 `openspec validate component-button --strict` 通过；实施完成后 `openspec archive`
