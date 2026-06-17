## 1. 组件契约规范

- [x] 1.1 写 `docs/design/component-contract.md`：中性 variant properties + 状态枚举 + token 绑定 + Flutter↔MUI 跨端映射
- [x] 1.2 自检：契约框架中性、可复制到其他组件（A3 模板性）

## 2. Figma Button Component Set

- [x] 2.1 取证 Component Set / variant properties API（`createComponent`/`combineAsVariants`，并入 filled 标杆验证）
- [x] 2.2 建 Button 20 变体（5 variant × state × icon）绑 token（D5 配色 / 圆角 radius/full / 文字 label/large / 内距 space/xl）
- [x] 2.3 截图核对；修复 disabled 透明度（Figma paint 绑定+opacity 冲突 → disabled 改不绑+固定 on-surface+opacity）

## 3. Flutter Button（三层方案，TDD）

- [x] 3.1 样式层：`app_theme` component themes（filled/outlined/text/elevated）+ `ThemeExtension<TongtuTokens>`
- [x] 3.2 组件层：薄 `lib/ui/components/button.dart`（`TongtuButton` 委托 M3 widget，样式继承 theme）
- [x] 3.3 widget 测试 9 + `dart analyze` 0 + `dart format`（fvm）

## 4. Web React + MUI 工程 + React Button

- [x] 4.1 首建 `web/` React+MUI 工程（Vite+TS+MUI）；扩 `build.mjs` 生成 web JS token（`tokens.ts`，跨栈同源）
- [x] 4.2 React Button（中性 variant→MUI；tonal/elevated 用 sx 自定义）
- [x] 4.3 冒烟：`tsc` 0 + `vite build` 打包成功（视觉截图被 preview 沙箱 `getcwd` 环境问题挡，以 lint+build+token 值核对替代）

## 5. Code Connect

- [x] 5.1 React：`@figma/code-connect` + `Button.figma.tsx`（`figma.connect`）+ `figma.config.json`
- [x] 5.2 Flutter：html template（`figma/button.flutter.figma.ts`）输出 Flutter 代码片段
- [ ] 5.3 发布 + Dev Mode 验证：需 Figma access token，由用户执行（见 `web/CODE_CONNECT.md`）

## 6. 验证与归档

- [x] 6.1 契约自检 + 三端一致核对（filled 三端均取 `primary` token，语义一致；非像素）
- [x] 6.2 门禁：Flutter `test` 64 全过 + `analyze` 0；Web `tsc` 0 + `vite build` OK
- [ ] 6.3 `openspec validate component-button --strict` 通过（已）；`openspec archive`
