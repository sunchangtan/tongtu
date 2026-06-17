## 1. Figma comp token + Button 重绑

- [ ] 1.1 Figma 建 comp token 集合（`comp/button/container-height=40`、`icon-size=18`、`outline-width=1`，带 code syntax）
- [ ] 1.2 Button 重绑：height→`comp/button/container-height`、icon→`comp/button/icon-size`、stroke→`comp/button/outline-width`、itemSpacing→`sys/ui/space/sm`、去冗余垂直内距（靠 height + 垂直居中）
- [ ] 1.3 审计核对：除 disabled opacity 外 0 未绑

## 2. 扩管线生成 comp 产物

- [ ] 2.1 导出 comp DTCG → `tokens/comp.json`
- [ ] 2.2 扩 `build.mjs`：comp → Flutter `TongtuComp` 常量 + CSS（`--comp-*`）+ TS

## 3. 三端组件用 comp token

- [ ] 3.1 Flutter：`app_theme` `_buttonStyle.minimumSize` 用 `TongtuComp.buttonContainerHeight`；`TongtuButton` icon 尺寸用 comp
- [ ] 3.2 Web：MUI theme `MuiButton` minHeight 用 comp；React Button icon 尺寸
- [ ] 3.3 Flutter `test` + Web `build` 验证

## 4. 审计门禁脚本

- [ ] 4.1 `tools/` 下 Figma token 绑定审计脚本（扫组件报未绑，豁免 `State=disabled` opacity）
- [ ] 4.2 文档：A3 每组件建完跑审计、0 未绑（除豁免）才算完成

## 5. 验证与归档

- [ ] 5.1 Button 审计 0 未绑（除豁免）；comp 三端同值
- [ ] 5.2 Flutter `analyze` 0 + `test`（fvm）；Web `tsc` + `vite build`
- [ ] 5.3 `openspec validate component-tokens-gate --strict` 通过；实施完成后 `openspec archive`
