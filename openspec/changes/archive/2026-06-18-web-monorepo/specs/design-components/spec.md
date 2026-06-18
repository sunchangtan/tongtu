## ADDED Requirements

### Requirement: 组件库 monorepo 工程结构
Web 组件库必须（MUST）作为独立 workspace 包（`packages/components`）存在，与测试 / 展示 app（`apps/playground`）分离，以 pnpm workspaces 组织（`web/` 为 monorepo 根）；组件库应当（SHALL）经 `src/index.ts` 统一导出，测试 app 必须（MUST）经 workspace 依赖（`@tongtu/components`: `workspace:*`）消费，不得（MUST NOT）将组件与展示 app 混在同一目录、或经相对路径引组件库内部文件。

#### Scenario: 组件库与测试 app 分离
- **当** 查看 web 前端结构
- **则** 组件库在 `packages/components`（含 Button / theme / token / Code Connect），测试 app 在 `apps/playground`，二者为独立 workspace 包

#### Scenario: 测试 app 经 workspace 依赖消费
- **当** 测试 app 引用组件
- **则** 经 `@tongtu/components`（workspace 依赖）import，而非相对路径引组件库内部文件

#### Scenario: 组件库统一导出入口
- **当** 消费方 import 组件库
- **则** 经 `@tongtu/components` 包入口（`src/index.ts`）取 Button / theme / tokens，不直接深引内部模块路径
