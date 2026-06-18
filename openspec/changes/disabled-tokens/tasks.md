## 1. Figma disabled token + Button 重绑

- [x] 1.1 建 `sys/color/disabled-container`、`disabled-content`（实色，明暗 mode 预乘 `on-surface` @ 12% / 38%）+ `disabled-icon`、`disabled-border`（alias 引用同值）
- [x] 1.2 Button disabled 10 变体重绑：容器/文字/图标/描边 → disabled-*；删手设图层 opacity
- [x] 1.3 审计（删豁免后）：0 未绑（仅 padding=0 豁免）

## 2. 管线含 alpha

- [x] 2.1 导出 disabled DTCG（α<1 → 8 位 hex）→ `sys.color.light/dark.json`
- [x] 2.2 验证生成：Flutter `Color(0xAARRGGBB)`（α=12%/38%）+ CSS 8hex + TS；明暗 + alias 解析核对

## 3. 门禁删 disabled 豁免

- [x] 3.1 `tools/figma-audit/audit-component.js` 删 `isDisabled && opacity<1` 豁免分支 + 更新 README

## 4. 验证与归档

- [x] 4.1 Button 审计 0 未绑（仅 padding=0 豁免）；Flutter `analyze` 0 + `test` 64；Web `tsc` + `build`
- [ ] 4.2 `openspec validate disabled-tokens --strict` 通过（已）；`openspec archive`
