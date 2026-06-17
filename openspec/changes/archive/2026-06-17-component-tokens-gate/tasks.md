## 1. Figma comp token + Button 重绑

- [x] 1.1 Figma 建 comp token 集合（`comp/button/container-height=40`、`icon-size=18`、`outline-width=1`，带 code syntax）
- [x] 1.2 Button 重绑：height→`comp/button/container-height`、icon→`comp/button/icon-size`、stroke→`comp/button/outline-width`、itemSpacing→`sys/ui/space/sm`、去冗余垂直内距（靠 height + 居中）
- [x] 1.3 审计核对：0 未绑（disabled opacity 与 padding=0 豁免）

## 2. 扩管线生成 comp 产物

- [x] 2.1 导出 comp DTCG → `tokens/comp.json`
- [x] 2.2 扩 `build.mjs` + 3 format：comp → Flutter `TongtuComp` + CSS（`--comp-*`）+ TS（`comp`），与 sys 同源同值

## 3. 三端组件用 comp token

- [x] 3.1 Flutter：`app_theme` `_buttonStyle` minimumSize / iconSize 用 `TongtuComp`
- [x] 3.2 Web：MUI theme `MuiButton` minHeight 用 `comp.buttonContainerHeight`
- [x] 3.3 验证：Flutter `test` 64 全过 + `analyze` 0；Web `tsc` + `vite build`

## 4. 审计门禁脚本

- [x] 4.1 `tools/figma-audit/audit-component.js`（扫组件报未绑，豁免 disabled opacity / padding=0）
- [x] 4.2 `tools/figma-audit/README.md`（A3 每组件建完跑、0 未绑才算完成 + 豁免规则）

## 5. 验证与归档

- [x] 5.1 Button 审计 0 未绑（除豁免）；comp 三端同值（40 = 40px = 40）
- [x] 5.2 Flutter `analyze` 0 + `test` 64（fvm）；Web `tsc` + `vite build`
- [ ] 5.3 `openspec validate component-tokens-gate --strict` 通过（已）；`openspec archive`
