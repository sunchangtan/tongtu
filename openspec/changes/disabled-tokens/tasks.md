## 1. Figma disabled token + Button 重绑

- [ ] 1.1 建 `sys/color/disabled-container`、`disabled-content`（实色，明暗 mode 预乘 `on-surface` @ 12% / 38%）+ `disabled-icon`、`disabled-border`（alias 引用同值）
- [ ] 1.2 Button disabled 重绑：容器→disabled-container、文字→disabled-content、图标→disabled-icon、描边→disabled-border；删手设图层 opacity
- [ ] 1.3 审计（删豁免后）：0 未绑（仅 padding=0 豁免）

## 2. 管线含 alpha

- [ ] 2.1 导出 disabled DTCG（α<1 → 8 位 hex）→ `sys.color.light/dark.json`
- [ ] 2.2 验证生成：Flutter `Color(0xAARRGGBB)` + CSS（8 hex / rgba）+ TS；明暗抽样核对

## 3. 门禁删 disabled 豁免

- [ ] 3.1 `tools/figma-audit/audit-component.js` 删 `isDisabled && opacity<1` 豁免分支 + 更新 README

## 4. 验证与归档

- [ ] 4.1 Button 审计 0 未绑（仅 padding=0 豁免）；Flutter `analyze` 0 + `test`；Web `tsc` + `build`
- [ ] 4.2 `openspec validate disabled-tokens --strict` 通过；实施完成后 `openspec archive`
