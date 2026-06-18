# 组件开发规范（SOP）

- 定位：从零开发一个新组件（A3）的**操作流程与强制要求**。组件「长什么样」见 `component-contract.md`（契约）；本文讲「怎么做」。
- 强制：A3 每个组件按本 SOP 推进，**每阶段过卡点才进下一步**；完成须过 `component-gate.md` 全部门禁。
- 配套：`component-dev-pitfalls.md`（避坑库，开发前通读）。

## 0. 前置

- 通读 `component-contract.md`（契约）+ `component-dev-pitfalls.md`（避坑库）。
- 为该组件开 OpenSpec change（proposal / design / specs / tasks），`openspec validate --strict` + **确认计划（门控）** 后再编码（遵 CLAUDE.md 8 步）。
- 黑盒行为先探针、后实现（避坑库核心）。

## 1. 设计先行 → Figma（第一端）

总顺序：**Figma → Flutter → Web → Code Connect**（设计先行，避免代码与设计漂移）。

- 1.1 定 variant properties（中性命名，contract §2）：`variant / size / state / icon`。
- 1.2 建 Component Set：全变体矩阵（variant × state × icon）。
- 1.3 **token 全绑（comp 单一入口，contract §4）**：
  - 先在 Component collection 建 `comp/<组件>/*` 变量——颜色 alias 引 `sys/color`、padding/shape alias 引 `sys/ui`、固有尺寸（容器高 / 图标 / 描边宽）字面值。
  - 变体节点 fill / stroke / label / icon / radius / padding 绑到 `comp/<组件>/*`。
  - disabled 用带 alpha 的 `sys/color/disabled-*`（避坑 B1）。
- 1.4 **卡点**：Figma 绑定审计 = 0 未绑（见门禁，经 `use_figma` 跑 `audit-component.js`）。

## 2. Flutter（第二端）

- 2.1 导出 DTCG（`tokens/*.json`）→ `node tools/style-dictionary/build.mjs` 生成三端产物。
- 2.2 三层落地（contract §6）：
  - **尺寸** → `ThemeData` component theme（取 `TongtuComp`）。
  - **色** → 组件层 wrapper 按 variant + 明暗从 `TongtuCompColors{Light,Dark}` 构造（避坑 C1：共享 theme 无法区分 variant）。
  - wrapper 保持薄：选 widget + 取 comp 色 + 统一 variant API + 扩展点。
- 2.3 **卡点**：`fvm flutter analyze` 0 警告 + `fvm flutter test` 全绿。

## 3. Web（第三端）

- 3.1 `createTheme` 尺寸取 `comp`；组件 wrapper 各 variant 色经 `sx` 从 `compColorsLight` 取（contract §7）。
- 3.2 中性 variant → MUI 映射；无原生者用 `sx` 自定义（避坑 D2）。
- 3.3 **卡点**：`npm --prefix web run build`（tsc + vite build）通过（避坑 D1）。

## 4. Code Connect

- React：官方 `@figma/code-connect` 的 `figma.connect`（variant 用 `figma.enum` 映射）。
- Flutter：无官方集成 → template files。
- 一个 Figma 组件可同时绑多端。

## 5. 完成

- 过 `component-gate.md` **全部**门禁（自动 + Figma 审计 + 人工清单）。
- 若契约有演进，更新 `component-contract.md` 版本记录。
- `openspec archive`；更新进度 memory。

## 强制原则（红线）

1. **设计先行**：先 Figma 定型，再代码端。
2. **comp 单一入口**：三端组件只读 `comp/<组件>/*`（颜色 + 尺寸），不直读 `sys/*` / `ColorScheme`（字体走全局 type scale 除外）。
3. **探针优先**：黑盒行为先实验、后实现。
4. **同源同值**：三端取同一 token 产物；抽样核对明暗终值一致。
5. **门禁全绿才算完成**：未过门禁不得宣称完成。
