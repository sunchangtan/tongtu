## Why

`component-tokens-gate` 的审计门禁有唯一豁免：disabled 态 opacity 色——因 Figma「paint 绑 color 变量 + 手设图层 opacity」冲突（opacity 被吞）。已验证正解：用**带 alpha 的独立 disabled 语义色变量**（α 烤进变量值，绑 color 时 Figma 自动把 α 映射为 paint.opacity，绑定与透明度都生效）。据此 disabled 可全绑 → **消除门禁豁免**。

## What Changes

- 建 `sys/color/disabled-*`（container / content / icon / border，明暗 mode 各预乘 `on-surface` @ 12% / 38%；container、content 为实色，icon、border 用 alias 引用同值，2 源值 4 语义）。
- Button disabled 重绑这些变量（去掉手设图层 opacity）。
- 管线：disabled 含 alpha 导出 DTCG（8 位 hex）→ Flutter `Color(0xAARRGGBB)` + CSS `rgba()` + TS。
- 审计门禁**删除 disabled 豁免**（disabled 全绑，仅保留 padding=0 豁免）。

## Capabilities

### Modified Capabilities
- `design-tokens`: sys 层增加 disabled 语义色（带 alpha，明暗 mode）。
- `design-components`: 审计门禁去除 disabled 豁免——disabled 用 alpha 变量全绑。

## Impact

- **Figma**：`sys/color/disabled-*` 变量 + Button disabled 重绑。
- **tokens/**：`sys.color.light/dark.json` 加 disabled-*（实色含 alpha）。
- **管线**：导出/生成支持含 alpha 颜色（8 hex / rgba）。
- **门禁**：`tools/figma-audit/audit-component.js` 删 disabled 豁免。
- **Flutter/Web**：disabled token 产物（框架 disabled 自带同值，产物供显式取用）。
