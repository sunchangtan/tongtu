## Context

`component-tokens-gate` 门禁唯一豁免 disabled opacity（Figma paint 绑 color + 手设 opacity 冲突）。已用 use_figma 验证：**COLOR 变量 α=0.12 绑 fill → paint.opacity 自动 = 0.12 + 绑定生效**。故 disabled 改用带 alpha 的独立变量全绑，消豁免。

## Goals / Non-Goals

**Goals:**
- `sys/color/disabled-*`（带 alpha，明暗 mode）。
- Button disabled 全绑（去手设 opacity）。
- 管线支持含 alpha 颜色三端产物。
- 门禁删 disabled 豁免。

**Non-Goals:**
- 组件级 `component/*/disabled/*` 中间层（YAGNI；Button disabled = 通用 `on-surface@α`，无组件特异，等真特异再加）。
- 改代码端 disabled 行为（Flutter M3 / MUI 框架自带，同值）。

## Decisions

### D1：4 语义 2 源值（实色 + alias）
- `sys/color/disabled-container` = `on-surface` @ 12%（实色）
- `sys/color/disabled-content` = `on-surface` @ 38%（实色）
- `sys/color/disabled-icon` = alias → `disabled-content`（同 38%）
- `sys/color/disabled-border` = alias → `disabled-container`（同 12%）

明暗 mode 各预乘（light `on-surface`=#1a1c2a、dark=#e4e2e9）。alias 跟随 mode。

### D2：Figma alias 不能改 alpha
Figma 变量 alias 直接引用、α 跟随，无法 override alpha。故 container/content 存预乘实色 `{r,g,b: on-surface, a}`；icon/border alias 同值变量（值相同才能 alias）。源语义（on-surface@α）靠命名 + 文档保留。

### D3：含 alpha 导出/生成
disabled 变量 α<1 → 导出 DTCG 用 8 位 hex（`#1a1c2a1f`，末两位 = α）。生成：Flutter `Color(0xAARRGGBB)`（现有 dartColor 已支持 8 hex）、CSS（8 hex / rgba）、TS。

### D4：Button disabled 重绑
容器→disabled-container、文字→disabled-content、图标→disabled-icon、描边→disabled-border；**删除手设 paint.opacity**（α 由变量提供）。

### D5：门禁删 disabled 豁免
`audit-component.js` 去掉 `isDisabled && opacity<1` 豁免分支——disabled fill 现在绑变量，与 enabled 一视同仁。仅保留 padding=0 豁免。

## Risks / Trade-offs

| 风险 | 应对 |
|------|------|
| 导出 hex 需含 alpha | 序列化 a<1 时输出 8 hex；dartColor 已处理 8 hex |
| alias 跟随 mode 是否正确 | 抽样核对明暗 disabled 值 |
| 代码端 disabled 重复 | 代码端 disabled 由框架自带（不强制用 token，产物供需要时取） |

## Migration Plan

1. Figma 建 disabled-*（明暗预乘 + alias）→ Button 重绑 → 审计（删豁免后）0 未绑。
2. 导出 DTCG（含 alpha）→ 管线生成三端。
3. 验证（审计 + Flutter test + Web build）。

回滚：disabled 变量为增量；Button 绑回固定色+opacity 即恢复。
