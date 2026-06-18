## Why

`web/` 目前是**单个 Vite app**（`tongtu-web-components`，npm 管理）——组件（`Button.tsx`）、展示页（`App.tsx`）、token、Code Connect 全混在 `src/`，没有专门的组件目录。组件库无法独立复用，展示与库耦合，「改组件」和「改展示」搅在一起。

经 brainstorming 确认三项决策：**内部复用为主**（YAGNI，组件库不加构建/发布）、**pnpm workspaces**、**`packages/components` + `apps/playground`** 分包。据此把 `web/` 重构为 monorepo，组件库与测试 app 分离。

## What Changes

- `web/` 改造为 **pnpm monorepo 根**（2 个 workspace）：
  - `packages/components`（`@tongtu/components`）：纯组件库——Button + theme + token + Code Connect，`src/index.ts` 统一导出。
  - `apps/playground`：测试/展示 app，经 `workspace:*` 依赖消费组件库，跑现有 `App.tsx` 展示页。
- 组件库**无构建**：`package.json` 的 `exports` 指向 `src/index.ts`，app 的 Vite 直接编译其 TS 源。
- 迁移：token 生成路径、Code Connect config / source、包管理器 npm→pnpm、根 scripts。

## Capabilities

### Modified Capabilities
- `design-components`: 新增「组件库 monorepo 工程结构」——组件库独立为 workspace 包、与测试 app 分离。

## Impact

- **web/**：重构为 monorepo（`pnpm-workspace.yaml`、`packages/components`、`apps/playground`）。
- **tools/style-dictionary/build.mjs**：web token 输出 `web/tokens` → `packages/components/src/tokens`。
- **Code Connect**：config 的 `include` 路径更新；source URL 变为 `…/web/packages/components/src/Button.tsx`，须**重新 publish**。
- **包管理器**：npm → pnpm（删 `package-lock.json`，`pnpm install`）。
