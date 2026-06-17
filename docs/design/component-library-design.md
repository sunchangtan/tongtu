# 多端组件库 · 设计方案（子项目 A：Figma 组件库）

- 版本：v1.0（设计阶段，待评审）
- 日期：2026-06-18
- 定位：通途多端组件库工作线的**子项目 A**（Figma 设计库），承接子项目 0（token 同步）
- 关联：`docs/design/token-sync-design.md`（子项目 0）、`openspec/specs/design-tokens`、Figma「Tongtu Brand」

---

## 1. 定位

广泛通用、**app(Flutter) + web(React-MUI) 跨平台共享**的 Figma 组件库：

- 以 **Material 3** 为设计语言；消费子项目 0 已建的 token（`sys/color` + `sys/ui`）。
- Figma 是设计真相源，定义组件的**视觉 + 变体 + 属性**；子项目 B（Flutter）/ C（Web）按它实现。
- 「广泛通用」≠ 直接铺全集——广度越大方法返工代价越高，故先立方法（契约 + 标杆）再铺广。

---

## 2. 范围

设计系统 = **Foundations（基础）+ Components（组件）**，两者都做。

### 2.1 Foundations（基础变量展示）
| 基础 | token 现状 | A 要做 |
|------|-----------|--------|
| 颜色 | ✅ ref 35 tonal + sys/color 17 明暗（子项目 0） | 色板展示页：tonal 色阶 + 语义色明暗对照 |
| 间距/圆角 | ✅ sys/ui/space、radius（子项目 0） | 标尺展示 |
| 字体 | ⚠️ 仅字号数值 sys/ui/font（缺完整 type scale） | **补全 M3 type scale**（见 §6）+ 字阶展示 |

### 2.2 Components（M3 常用全集，完整变体 + 状态）
| 层 | 组件 |
|----|------|
| 输入 | Button、IconButton、FAB、TextField、Checkbox、Radio、Switch、Slider、Chip、SegmentedButton、Menu |
| 容器 | Card、List/ListTile、Dialog、BottomSheet、Tooltip、Banner |
| 导航 | TopAppBar、NavigationBar、NavigationRail、Tabs、Drawer |
| 反馈 | Progress(linear/circular)、SnackBar、Badge |

（app 已在用的优先：Button、Card、TextField、ListTile、NavigationBar、Tabs、Dialog、Progress、IconButton。）

---

## 3. 跨端中性契约（「可共享」成立的核心）

每个组件定一套**框架中性的 variant properties**，并给两端映射。以 Button 为例：

| 中性 variant | Flutter | Web/MUI |
|---|---|---|
| `filled` | `FilledButton` | `variant="contained"` |
| `outlined` | `OutlinedButton` | `variant="outlined"` |
| `text` | `TextButton` | `variant="text"` |
| `tonal` | `FilledButton.tonal` | 自定义（MUI 无原生） |
| `elevated` | `ElevatedButton` | 自定义 |

- 属性命名中性（`variant`/`size`/`state`/`leadingIcon`…）；状态枚举统一（enabled/hovered/focused/pressed/disabled）。
- 颜色绑 `sys/color`、尺寸绑 `sys/ui`、文字用 type scale。
- **MUI 是 Material 2 模型**，部分 M3 变体（tonal/elevated）Web 端需自定义——契约里显式标注，B/C 各自落地。

---

## 4. Figma 组织结构

- **Page: Foundations** —— 色板（tonal + 语义明暗）、字阶（type scale 样板）、间距/圆角标尺。
- **Page: Components** —— 按层分组（输入/容器/导航/反馈）；每组件一个 **Component Set**（variant properties）+ 绑 token + 组件描述写**跨端映射**。
- **命名规范**：组件名中性；variant properties 全库统一。

---

## 5. 实施顺序（A 拆 3 阶段，各自独立 spec/实施）

| 阶段 | 内容 | 依赖/理由 |
|------|------|----------|
| **A1 · 基础** | 补全 typography（M3 type scale → Figma Text Styles + 扩 token 管线生成 Flutter `TextTheme`/CSS）+ Foundations 展示页 | 组件文字依赖 type scale；颜色/间距 token 已就绪 |
| **A2 · 标杆** | Button 完整 M3 变体 + 跨端契约规范（立方法） | 一个组件压测方法，防全集返工 |
| **A3 · 铺广** | 按契约扩到 M3 组件全集（20+） | 方法立住后批量 |

每阶段独立交付验证。本设计为 A 总览；各阶段再出自己的 OpenSpec change。

---

## 6. typography 补全（A1 核心，现存缺口）

子项目 0 只做了字号数值（sys/ui/font 6 档），M3 完整 type scale 未做。A1 补：

- **type scale**：display / headline / title / body / label × Large/Medium/Small（15 档），每档含 `size` / `weight` / `lineHeight` / `letterSpacing`。
- **Figma 形态**：typography 在 Figma 是 **Text Styles**（复合样式，非 variable）；字号数值可继续用 variable。
- **token 同步扩展**：DTCG 的 typography 是 composite token；需扩子项目 0 的 `build.mjs` / format，生成 Flutter `TextTheme` 与 CSS（`font-size`/`font-weight`/`line-height`/`letter-spacing`）。比颜色/维度复杂，是 A1 的技术重点。

---

## 7. 与子项目 0 / B / C 的关系

- **依赖子项目 0**：颜色/间距/圆角 token 直接复用；A1 扩 token 管线增加 typography。
- **供 B / C**：A 产出 Figma 组件 + 跨端映射约定；B（Flutter）/ C（Web-MUI）据此实现。Code Connect（Figma↔代码）在 B/C 阶段做（依赖代码存在）。

---

## 8. 范围外（future）

- 组件的代码实现（子项目 B/C）。
- Code Connect 元数据（B/C 阶段）。
- 阴影/高度（elevation）、动效 token（后续 Foundations 扩展）。
- 响应式/自适应布局（页面层面，归 B/C 实现）。

---

## 9. 风险与权衡

| 风险 | 应对 |
|------|------|
| A 是大工程 | 拆 A1/A2/A3 独立交付，先立方法（契约+标杆）再铺广 |
| typography composite + Figma Text Styles 比颜色复杂 | A1 重点攻关；先验证 type scale 同步管线再做展示 |
| 跨端 M3 ≠ MUI(M2) | 契约框架中性 + 显式标注两端落地差异；不假设单一框架 |
| 导出半自动（依赖 agent） | 同子项目 0：核心管线不受导出方式影响 |

---

## 10. 版本记录

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0 | 2026-06-18 | 初稿：定位（广泛通用 app+web 跨端共享 Figma 组件库）；范围（Foundations + 完整 M3 type scale + 组件全集）；跨端中性契约；Figma 结构；三阶段 A1/A2/A3；typography 补全为 A1 核心。经 brainstorming 逐项确认。 |
