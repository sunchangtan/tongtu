# Code Connect 发布说明

把 Figma 组件绑定到代码，使 Figma Dev Mode 显示真实代码片段。**发布需 Figma access token**（你的账号），故由你执行。

## 前置

1. Figma access token：Figma → Settings → Security → Personal access tokens（需 Code Connect 写权限）。
2. 已 `npm install`（含 `@figma/code-connect`）。

## React（官方集成）

定义：`src/Button.figma.tsx`（`figma.connect` 映射 Figma Button → `TongtuButton`，variant/state）。配置：`figma.config.json`（parser: react）。

发布：
```sh
cd web
npx figma connect publish --token <FIGMA_TOKEN>
```
发布后，Figma Dev Mode 选中 Button（按 Variant/State）即显示对应 React-MUI 代码片段。

## Flutter（template files，无官方集成）

Flutter 无官方 Code Connect（已查证）。用 html template 输出 Flutter 代码片段：`figma/button.flutter.figma.ts`。

发布（单独 parser）：
```sh
cd web
npx figma connect publish --parser html --dir figma --token <FIGMA_TOKEN>
```
发布后，Dev Mode（Flutter 上下文）显示 `TongtuButton(variant: …, onPressed: …)` 片段。

## 校验（不发布，仅本地检查）
```sh
npx figma connect parse --token <FIGMA_TOKEN>
```

## 说明
- Figma 组件 URL 中的 `node-id=132-52` 是 Button Component Set；若组件重建导致 id 变化，更新两个 `.figma.*` 文件中的 URL。
- 跨端「一致」= 语义 / token 一致，非像素（M3 与 MUI-M2 渲染不同）。
