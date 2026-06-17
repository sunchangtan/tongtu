## Context

承接 A2：Button 未全绑变量。用户定「严格全绑 + comp token + 门禁」。结构尺寸 sys 无档 → 建 comp 层；disabled opacity Figma 限制 → 豁免。

## Goals / Non-Goals

**Goals:**
- comp 层 token（组件结构尺寸），随管线生成三端产物。
- Button 三端全绑（除 disabled opacity）。
- Figma 审计门禁脚本（A3 复用）。

**Non-Goals:**
- 改 disabled 的 Figma 表达（绕不过的 paint 限制）。
- A3 其余组件（本 change 立 comp token + 门禁，A3 套用）。

## Decisions

### D1：comp 层 token
新 Figma 集合「Component」，`comp/button/container-height=40`、`comp/button/icon-size=18`、`comp/button/outline-width=1`（FLOAT，组件级固有尺寸，sys 无对应档故直接值）。DTCG 存 `tokens/comp.json`。

### D2：Button 全绑重绑
- height → `comp/button/container-height`（绑 Figma 组件 height；去冗余 `paddingTop/Bottom`，靠 height + 垂直居中）。
- icon w/h → `comp/button/icon-size`。
- strokeWeight → `comp/button/outline-width`。
- itemSpacing → `sys/ui/space/sm`。
- 颜色/圆角/内距/字（已绑）保持。

### D3：disabled opacity 豁免
Figma paint「绑 color 变量 + opacity」冲突（opacity 被吞，已查证）。disabled 容器/文字/图标/描边用固定 `on-surface` + opacity，**无法绑**。门禁对 `State=disabled` 的 fill/stroke opacity 豁免。

### D4：管线扩 comp
`build.mjs` 解析 `comp.json` → 生成 Flutter（`TongtuComp` 常量）+ CSS（`--comp-*`）+ TS（comp JS）。与 sys 同源同值。

### D5：三端用 comp token
- Flutter：app_theme `_buttonStyle.minimumSize` 用 `TongtuComp.buttonContainerHeight`；`TongtuButton` icon 尺寸用 comp。
- Web：MUI theme `MuiButton.minHeight` 用 comp；React Button icon 尺寸。

### D6：审计门禁
Figma 脚本扫组件全部可 token 化属性（fills/strokes color、cornerRadius、padding、itemSpacing、height、icon、stroke），报未绑；**豁免** `State=disabled` 的 opacity 色。0 未绑（除豁免）才过。A3 每组件建完跑此审计。脚本置 `tools/`（agent 经 use_figma 跑）。

## Risks / Trade-offs

| 风险 | 应对 |
|------|------|
| comp token 增 token 层复杂度 | 仅组件固有尺寸入 comp；与 sys 分明（sys=语义、comp=组件） |
| disabled 无法绑（门禁漏洞） | 豁免显式（仅 State=disabled opacity），审计脚本白名单 |
| comp 产物三端绑改动 | Button 已三端在，改绑点小；A3 起即遵循 |

## Migration Plan

1. Figma 建 comp token → Button 重绑 → 审计脚本验证 0 未绑（除豁免）。
2. 扩管线生成 comp 产物 → 三端组件改用 comp token。
3. 验证（审计 + Flutter test + Web build）。

回滚：comp token 为增量；Button 绑回固定值即恢复（无破坏）。
