# Code Connect 发布说明

把 Figma 组件绑定到代码，使 Figma Dev Mode 显示真实代码片段。**发布需 Figma access token**（你的账号），故由你执行。

## 前置

1. Figma access token：Figma → Settings → Security → Personal access tokens（勾 Code Connect「write」scope）。
2. 已 `npm install`（含 `@figma/code-connect`）。
3. token 写入 `web/.env`（`FIGMA_ACCESS_TOKEN=...`）——CLI 内置 dotenv 自动读取，命令**无需 `--token`**。`.env` 已被 `.gitignore` 忽略，绝不入库（模板见 `.env.example`）。

## 配置（两端两份 config，parser 不同）

- **React**：`figma.config.json`（`parser: react`，include `src/**/*.figma.tsx`）。
- **Flutter**：`figma.flutter.config.json`（`parser: html`，include `figma/**/*.figma.ts`）——Flutter 无官方集成，用 html template（已查证）。

> 注：`parser` 只能在 config 里配，**命令行没有 `--parser` 选项**；多 parser 用多份 config + `--config` 切换。

> monorepo 下 Code Connect 全部归本包（`web/packages/components`）。命令在本包目录跑；或在 `web/` 根用 pnpm 脚本（`pnpm cc:parse` / `cc:parse:flutter` / `cc:publish` / `cc:publish:flutter`，已 `--filter @tongtu/components` 转发）。

## 校验（本地，不上传）

```sh
cd web/packages/components
npx figma connect parse                                       # React
npx figma connect parse --config figma.flutter.config.json    # Flutter
```

## 发布

```sh
cd web/packages/components
npx figma connect publish                                                # React
npx figma connect publish --config figma.flutter.config.json --label Flutter  # Flutter
```

> Flutter 用 `--label Flutter`（html parser 默认标签是「Web Components」，须显式改）。换标签后旧标签残留，先 `unpublish --config figma.flutter.config.json --label "<旧>"` 清除。

发布后，Figma Dev Mode 选中 Button（按 Variant / State）→ 切语言下拉看 React-MUI / Flutter 两端片段。

## 说明

- 片段：React `<TongtuButton variant=… disabled=… >`；Flutter `TongtuButton(variant: …, onPressed: …, label: 'Button')`。
- 两端绑同一组件（node-id `132-52`）；发布后在 Dev Mode 确认**两端片段都在**。
- **html template 占位符只接受值 / prop 引用，不接受三元等表达式**——分支逻辑用 `figma.enum` 的 value mapping 表达（如 State → onPressed `() {}` / `null`）。
- 组件 URL 的 `node-id=132-52` 是 Button Component Set；若重建导致 id 变，更新两个 `.figma.*` 文件的 URL。
- 跨端「一致」= 语义 / token 一致，非像素（M3 与 MUI-M2 渲染不同）。
