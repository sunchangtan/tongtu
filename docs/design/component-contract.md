# 通途组件库 · 跨端契约规范

- 版本：v1.0
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

## 4. token 绑定约定

组件**不得硬编码**，一律绑 token：

| 维度 | token |
|------|-------|
| 颜色 | `sys/color`（容器 / 文字 / 描边各取对应语义角色） |
| 圆角 | `sys/ui/radius` |
| 文字 | `type`（M3 type scale，如 `type/label/large`） |
| 间距 / 内距 | `sys/ui/space` |

disabled 态：按 M3 用 `on-surface` 透明度（容器 12% / 文字 38%）。

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

## 6. Flutter 实现约定（三层）

避免「裸 widget 无扩展」与「厚 wrapper 重写样式」两个极端：

1. **样式层**：`ThemeData` 的 component themes（`filledButtonTheme` 等，集中定义 shape / padding / textStyle，全绑 token）+ `ThemeExtension<TongtuTokens>`（放 M3 没有的通途自定义）。
2. **组件层**：薄 wrapper（`TongtuXxx({variant, …})`），按 variant 委托 M3 widget，**不写死样式**（继承样式层）；提供统一 variant API + 扩展点 + Code Connect 单入口。
3. **token 层**：`ColorScheme` / `textTheme` / `TongtuDimens`（已生成）。

原则：**样式进 theme（全局可换肤），wrapper 保持薄**。

---

## 7. Web 实现约定（React-MUI）

- 工程：`web/`（Vite + TypeScript + MUI）。
- token：`createTheme` 引 token 值（或 `tokens.css` CSS vars）。
- 组件：React wrapper，中性 variant → MUI 配置；MUI 无原生者（tonal / elevated）用 theme variants + `sx` 自定义达成同等语义。

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
