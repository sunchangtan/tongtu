## Context

A1 是组件库（子项目 A）的基础阶段，承接子项目 0 的 token 管线（`docs/design/token-sync-design.md`、能力 `design-tokens`）。补两块基础：**typography（完整 M3 type scale）** 与 **Foundations 展示页**。typography 是组件文字的依赖，是 A1 技术重点；颜色/间距/圆角 token 已在子项目 0 就绪，A1 只做其展示。

关键约束：
- 复用子项目 0 管线（DTCG → Style Dictionary → Flutter + CSS），不另起炉灶。
- typography 在 Figma 是 **Text Styles**（复合样式，非 variable），DTCG 里是 **composite token**——比颜色/维度复杂。
- 跨端共享：Flutter + Web 各取所需，type scale 值字体无关（M3 规范）。

## Goals / Non-Goals

**Goals:**
- 完整 M3 type scale（15 档，含 size/weight/lineHeight/letterSpacing）→ Figma Text Styles + DTCG。
- 扩管线生成 Flutter `TextTheme` + CSS typography，跨栈同值。
- app_theme 接入 `textTheme`。
- Foundations 展示页（颜色/字体/间距/圆角）。

**Non-Goals:**
- 组件本身（A2/A3）。
- 锁定品牌字体家族（fontFamily 各端默认；见 D5）。
- 阴影/动效 token。

## Decisions

### D1：type scale 用 M3 标准 15 档
display(L57/M45/S36)、headline(L32/M28/S24)、title(L22/M16/S14)、body(L16/M14/S12)、label(L14/M12/S11)；字重/行高/字间距按 M3 规范。值字体无关，可跨端通用。

### D2：Figma typography = Text Styles（非 variable）
typography 在 Figma 用 **Text Styles**（`getLocalTextStylesAsync` 读取），不是 variable（Figma variable 不支持复合排版）。字号数值仍可引用 variable，但完整档以 Text Style 承载。

### D3：DTCG composite token
typography 以 DTCG `$type: "typography"` 的 composite `$value`（`fontFamily`/`fontSize`/`fontWeight`/`lineHeight`/`letterSpacing`）存于 `tokens/typography.json`。

### D4：扩管线生成两端产物
- **Flutter**：自写 typography format → 生成 `TextTheme`（M3 13 角色映射）或 `TongtuTextStyles` 常量（`TextStyle`）；app_theme 接入 `ThemeData.textTheme`。
- **CSS**：生成 typography（倾向 CSS utility classes，如 `.md-body-large {…}`，语义清晰；或 CSS vars）。
- 复用 `build.mjs` 编排，新增 typography 解析分支。

### D5：fontFamily v1 不锁定
type scale 值（size/weight/lineHeight/letterSpacing）字体无关，先做；`fontFamily` 不锁品牌字体，由各端默认（Flutter/Web 系统字体），future 再引入品牌字体。

### D6：sys/ui/font 与 type scale 关系
`sys/ui/font`（子项目 0 的 6 档数值）保留作通用数值档；完整语义排版以 type scale 为准。组件优先用 type scale。

## Open Questions（实施/评审时定）

- Flutter 产物形态：完整 `TextTheme`（接 `ThemeData`，组件自动继承）vs `TongtuTextStyles` 常量（显式取用）？倾向前者（M3 组件自动用）。
- CSS 形态：utility classes vs CSS vars？倾向 classes。
- Figma Text Styles → DTCG 的导出：agent 半自动（同子项目 0），需冒烟验证 `getLocalTextStylesAsync` 读取与序列化。

## Risks / Trade-offs

| 风险 | 应对 |
|------|------|
| typography composite + Text Styles 比颜色复杂 | 先冒烟验证读取 + SD 解析 composite，再做产物（同子项目 0 科学验证） |
| Flutter TextTheme 13 角色 vs M3 type scale 15 档映射 | TextTheme 角色（displayLarge…labelSmall）正好对应 type scale，直接映射 |
| 跨端 typography 一致性 | 抽样核对 Flutter/CSS 同档字体属性 |

## Migration Plan

1. Figma 建 type scale Text Styles → 导出 DTCG typography.json（冒烟验证）。
2. 扩管线生成 Flutter TextTheme + CSS → app_theme 接入。
3. Foundations 展示页（Figma）。

回滚：app_theme 不接 textTheme 即退回默认 M3 排版，无破坏。
