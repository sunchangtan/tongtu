## Context

现状：`web/` 是单个 Vite app（`tongtu-web-components`，npm），组件 / 展示 / token / Code Connect 混在 `src/`，无专门组件目录，库与展示耦合。

brainstorming 确认三项决策：① 内部复用为主（组件库不加构建/发布，YAGNI）；② pnpm workspaces；③ `packages/components`（库）+ `apps/playground`（app）分包。

## Goals / Non-Goals

**Goals:**
- 组件库独立为 workspace 包，与测试 app 清晰分离。
- 测试 app 经 workspace 依赖消费组件库（`@tongtu/components`）。
- 现有功能（Button 全变体展示、Code Connect、token 同源）不回归。

**Non-Goals:**
- 发布到 npm（YAGNI，组件库无构建产物；将来要发布再加 vite lib / tsup）。
- token 单独包（当前只 web 消费，放组件库内）。
- Turborepo / Nx（2 包，pnpm workspaces 足够）。

## Decisions

### D1：pnpm workspaces，`web/` 作 monorepo 根
`pnpm-workspace.yaml` 含 `packages/*`、`apps/*`；根 `package.json` 私有、放编排 scripts。npm → pnpm（删 `package-lock.json`）。

### D2：两个包
- `@tongtu/components`（`packages/components`）：组件库。
- `playground`（`apps/playground`）：测试/展示 app。

### D3：组件库无构建（源码直接消费）
`packages/components/package.json` 的 `exports` / `main` 指向 `src/index.ts`；app 的 Vite 经 workspace 依赖直接编译组件库 TS 源——无需组件库单独 build。app `tsconfig` 正常 resolve workspace 包。

### D4：token 归属组件库
token 生成物（`tokens.ts` / `tokens.css` / `typography.css`）放 `packages/components/src/tokens`；`tools/style-dictionary/build.mjs` 的 web 输出路径从 `web/tokens` 改到此。Flutter token 输出不变。

### D5：Code Connect 归属组件库
`Button.figma.tsx`（React）、`button.flutter.figma.ts`（Flutter）、`figma.config.json` ×2、`.env`、`CODE_CONNECT.md` 移到 `packages/components`。config 的 `include` 路径相应更新；publish 后 source URL 变为 `…/web/packages/components/src/Button.tsx`，须重新 publish（见避坑 D5 path 注意）。

### D6：目录结构
```
web/
  pnpm-workspace.yaml          # packages/*, apps/*
  package.json                 # root（私有，scripts）
  packages/components/
    src/{Button.tsx, theme.ts, tokens/, index.ts}
    figma/{Button.figma.tsx, button.flutter.figma.ts}
    figma.config.json, figma.flutter.config.json, .env, CODE_CONNECT.md
    package.json, tsconfig.json
  apps/playground/
    src/{App.tsx, main.tsx}
    index.html, vite.config.ts, package.json, tsconfig.json
```

## Risks / Trade-offs

| 风险 | 应对 |
|------|------|
| pnpm 切换（删 npm lock 重装） | `pnpm install` 后 `pnpm dev`/`build` 验证 |
| token 路径改后生成失效 | 改 `build.mjs` 输出后跑一次确认 `packages/components/src/tokens` 生成 |
| Code Connect source URL 变 | config 路径更新 + 重新 publish；parse 验证 source 指向新路径 |
| 组件库无构建、app resolve 失败 | `exports` 指 `src/index.ts` + app Vite/tsconfig resolve workspace 包；`pnpm dev` 验证 |

## Migration Plan

1. pnpm 切换（装 pnpm、`pnpm-workspace.yaml`、根 `package.json`、删 `package-lock.json`）。
2. 建 `packages/components`：移 Button/theme/token/Code Connect + `package.json`/`tsconfig`/`index.ts`。
3. 建 `apps/playground`：移 App/main + `vite.config`/`index.html`/`package.json`（依赖 `@tongtu/components`）。
4. `build.mjs` token 输出路径改。
5. Code Connect config 路径更新 + 重新 publish。
6. 根 scripts 编排。
7. 验证：`pnpm install`、playground `dev`/`build`、Code Connect `parse`。

**回滚**：git 还原 `web/` 旧结构 + `git checkout package-lock.json`。
