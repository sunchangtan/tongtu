# 通途组件库 · 跨端契约规范

- 版本：v1.1
- 定位：组件库（子项目 A）的契约基准，三端（Figma / Flutter / Web React-MUI）共享。A2 由 Button 落地，A3 所有组件遵循。
- 关联：`docs/design/component-library-design.md`、`openspec/specs/design-tokens`、`openspec/specs/design-components`

---

## 1. 目的

统一组件的**属性 / 状态 / token 绑定 / 跨端映射 / 实现分层**，使同一组件在三端语义一致、可共享、可扩展。这是模板：A2 用 Button 落地，A3 每个组件套用同一套规范。

---

## 2. variant properties（框架中性）

组件用统一的中性属性，不绑某端框架：

| 属性 | 含义 | 取值 |
|------|------|------|
| `variant` | 视觉变体 | 按组件（Button：filled / tonal / outlined / text / elevated） |
| `size` | 尺寸档 | small / medium / large（v1 多数组件仅 medium 标准档，其余预留） |
| `state` | 状态 | enabled / disabled（画稿态） |
| `icon` | 图标位 | none / leading / trailing（按组件） |

命名一律**中性英文、全库统一**，不含 Flutter / MUI 专有词。

---

## 3. 状态模型

- **画稿态**：`enabled` / `disabled` —— Figma 出 variant，各端实现。
- **交互态**：`hover` / `focus` / `pressed` —— **不画 variant**，由各端框架自带（Flutter M3 widget、MUI）按 M3 规范渲染。契约只规定其 token 规则，不逐一画稿。

---

## 4. token 绑定约定（comp 单一入口）

组件**不得硬编码**。颜色与尺寸一律经 **`comp/<组件>/*` 单一入口**取用——组件只读 comp，**不直接读 sys 或框架 ColorScheme**；comp 内部经 alias 引 sys 实现语义透传。字体例外：走全局 type scale。

| 维度 | 组件取用 | comp 内部引 |
|------|----------|-------------|
| 颜色（容器 / 文字 / 描边，按 variant） | `comp/<组件>/<variant>/*-color` | `sys/color/*` |
| disabled 色（容器 / 文字 / 图标 / 描边） | `comp/<组件>/disabled-*` | `sys/color/disabled-*`（带 alpha） |
| 圆角 | `comp/<组件>/shape` | `sys/ui/radius` |
| 内距 | `comp/<组件>/padding-*` | `sys/ui/space` |
| 结构尺寸（容器高 / 图标尺寸 / 描边宽） | `comp/<组件>/{container-height,icon-size,outline-width}` | 固有字面值（sys 无对应档） |
| 字体 | `type`（M3 type scale，如 `type/label/large`） | —（不经 comp，见下） |

**颜色为何按 variant 拆**：对齐 M3 官方 comp 层；每 variant 独立可定制——改 `comp/<组件>/<variant>/*` 只影响该组件该变体，不动全局 sys（组件级换肤）。

**字体为何不入 comp**：三端字体本就独立消费全局 type scale（Flutter `textTheme`、CSS `.type-*`、MUI `typography`）；纳入 comp 会逼各端处理 typography composite，复杂度高、收益低（组件级换字体罕见）。故 comp 单一入口范围 = **颜色 + 尺寸**。

disabled 态：用带 alpha 的 `sys/color/disabled-*`（容器 12% / 文字 38%，α 烤进变量值），经 `comp/<组件>/disabled-*` 取，不用图层 opacity。

---

## 5. 跨端映射约定

每组件每 variant 须标注：**Flutter widget + Web/MUI 配置**；某端无原生对应时显式标「自定义」。

跨端「一致」= **语义 + token 一致，非像素一致**（M3 与 MUI-M2 渲染本就不同）。

### Button 范例（A2 落地）
| variant | Flutter | Web/MUI |
|---------|---------|---------|
| filled | `FilledButton` | `variant="contained"` |
| outlined | `OutlinedButton` | `variant="outlined"` |
| text | `TextButton` | `variant="text"` |
| tonal | `FilledButton.tonal` | 自定义（secondary container 色） |
| elevated | `ElevatedButton` | 自定义（contained + elevation） |

---

## 6. Flutter 实现约定（三层 + comp 单一入口）

避免「裸 widget 无扩展」与「厚 wrapper 重写样式」两个极端：

1. **样式层**：`ThemeData` component themes 放**共享尺寸**（shape / padding / minHeight / iconSize / textStyle，取自 `comp/<组件>/*` + type scale）作兜底 + `ThemeExtension<TongtuTokens>`（放 M3 没有的通途自定义）。
2. **组件层**：薄 wrapper（`TongtuXxx({variant, …})`），按 variant 委托 M3 widget，并按 **comp 单一入口**取色——按 `variant` + 明暗从 `TongtuCompColors{Light,Dark}` 构造仅含色的 `ButtonStyle`（disabled 用 `WidgetStateProperty`）；提供统一 variant API + 扩展点 + Code Connect 单入口。
   - **色为何在组件层而非 theme**：M3 的 `FilledButton` 与 `FilledButton.tonal` 共享同一 `FilledButtonTheme`，色无法经 component theme 区分 variant；故色置组件层显式给出，尺寸（variant 无关）仍走 component theme。
3. **token 层**：`ColorScheme` / `textTheme` / `TongtuComp`（尺寸）/ `TongtuCompColors{Light,Dark}`（按 variant 明暗色）。

原则：**尺寸进 theme（共享兜底），色按 variant 从 comp 取（组件级可换肤），wrapper 仍薄（只选 widget + 取 comp 色）**。

---

## 7. Web 实现约定（React-MUI）

- 工程：`web/`（Vite + TypeScript + MUI）。
- token：`createTheme` 引 token 值（或 `tokens.css` CSS vars）。
- 组件：React wrapper，中性 variant → MUI 配置；按 **comp 单一入口**，各 variant 色（含 disabled）从 `compColorsLight` 经 `sx` 取（不依赖 MUI palette 默认），尺寸经 `createTheme` 的 `MuiButton` styleOverrides 取自 `comp`；MUI 无原生者（tonal / elevated）用 `sx` 自定义达成同等语义。

---

## 8. Code Connect 约定

- **React**：官方 `@figma/code-connect`，`figma.connect`（variant 用 `figma.enum` 映射）。
- **Flutter**：无官方集成 → **template files**（框架无关），手写模板绑 Flutter 代码片段。
- 一个 Figma 组件可同时绑多端实现。

---

## 9. 命名规范

- 组件名：中性（Button / TextField / Card…）。
- variant properties：中性、全库统一（§2）。
- Figma Component Set properties：`Variant` / `State` / `Icon`（首字母大写）。

---

## 10. 版本记录

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0 | 2026-06-18 | A2 标杆立契约：中性 variant / 状态模型 / token 绑定 / 跨端映射 / Flutter 三层 / Web React-MUI / Code Connect 约定；Button 作为首个落地范例。 |
| v1.1 | 2026-06-18 | 升级为 comp 单一入口：颜色 + 尺寸经 `comp/<组件>/*` 取（comp 引 sys），字体走 type scale；Flutter 色置组件层（filled/tonal 共享 theme）；Web 各 variant `sx` 取 comp 色。A3 沿此模板。 |
