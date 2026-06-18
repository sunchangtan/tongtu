## 1. pnpm workspace 骨架

- [x] 1.1 装 pnpm；建 `web/pnpm-workspace.yaml`（`packages/*`、`apps/*`）+ 根 `package.json`（私有，编排 scripts）
- [x] 1.2 删 `web/package-lock.json`（切换包管理器）

## 2. packages/components 组件库

- [x] 2.1 移 `Button.tsx` / `theme.ts` → `packages/components/src`；建 `src/index.ts` 统一导出（Button / theme / tokens / types）
- [x] 2.2 移 token 生成物 → `packages/components/src/tokens`
- [x] 2.3 移 Code Connect（`Button.figma.tsx`、`button.flutter.figma.ts`、`figma.config.json` ×2、`.env`、`CODE_CONNECT.md`）→ `packages/components`
- [x] 2.4 建 `packages/components/package.json`（`@tongtu/components`，`exports` 指 `src/index.ts`）+ `tsconfig.json`

## 3. apps/playground 测试 app

- [x] 3.1 移 `App.tsx` / `main.tsx` → `apps/playground/src`；移 `index.html` / `vite.config.ts`
- [x] 3.2 建 `apps/playground/package.json`（依赖 `@tongtu/components`: `workspace:*`）+ `tsconfig.json`
- [x] 3.3 `App.tsx` import 改从 `@tongtu/components` 取（不再相对路径）

## 4. 管线 + Code Connect 路径

- [x] 4.1 `tools/style-dictionary/build.mjs`：web token 输出 `web/tokens` → `packages/components/src/tokens`
- [x] 4.2 Code Connect config `include` 路径更新；重新 publish（source URL 变为新路径），`parse` 确认 source

## 5. 验证归档

- [x] 5.1 `pnpm install`；playground `pnpm dev` 展示 Button 全变体；`vite build`；Code Connect `parse` 通过
- [x] 5.2 `openspec validate web-monorepo --strict`；`openspec archive`
