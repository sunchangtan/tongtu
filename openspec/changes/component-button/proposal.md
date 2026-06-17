## Why

A 总览（`docs/design/component-library-design.md`）把 **A2 定为标杆**：用 Button 把「广泛通用跨端组件库」的方法钉死。按确认的**按组件垂直三端**流程，Button 走完整链路：**Figma 设计 → Flutter 代码 → Web(React-MUI) 代码 → Code Connect 绑定**，用三端实际代码验证跨端契约（非纸面映射）。方法不先立对，A3 全集铺广必返工。

## What Changes

- 立**组件契约规范**（`docs/design/component-contract.md`）：框架中性 variant properties（`variant`/`size`/`state`/`icon`）、状态枚举、token 绑定约定、Flutter↔Web 跨端映射约定。
- **Figma**：Button Component Set（elevated/filled/tonal/outlined/text × enabled/disabled × icon），绑 token。
- **Flutter**：Button widget（`lib/ui/components/`），按契约用 token + type scale。
- **Web**：首建 React + MUI 工程（`web/`），消费 token；实现 React Button。
- **Code Connect**：React 用官方 `figma.connect`；Flutter 用 template files（框架无关，绑 Flutter 代码片段）。

## Capabilities

### New Capabilities
- `design-components`: 组件库的设计契约 + 标杆组件三端实现能力——框架中性 variant 契约、token 绑定、跨端映射；Button 作为首个标杆在 Figma / Flutter / Web 三端实现并经 Code Connect 绑定，后续组件（A3）沿用此方法。

## Impact

- **Figma**：Button Component Set（绑 token）+ Code Connect 元数据。
- **docs**：新增 `docs/design/component-contract.md`。
- **Flutter**：新增 `lib/ui/components/`（Button widget）。
- **Web**：首建 `web/` React+MUI 工程（Vite + TS + MUI，消费 token）+ React Button + `Button.figma.tsx`（Code Connect）。
- **Code Connect**：React 官方集成；Flutter template files（无官方集成，见 design D9）。
- **specs**：新增 `design-components`。
- **范围外（future）**：其余组件（A3：FAB/IconButton/TextField…）；交互态（hover/focus/pressed）逐一画稿（由代码按 M3 实现）。
