# 组件门禁（完成判据）

组件须过**全部**门禁方视为完成。三类：自动（`run.sh`）+ 半自动（Figma 审计，经 `use_figma`）+ 人工（契约符合性抽查）。

## 一键运行（命令行自动项）

```bash
bash tools/component-gate/run.sh
```

依次跑：① token 管线 build ② Flutter analyze + test ③ Web tsc + build。任一失败即整体失败（退出码非 0）。

## 门禁项

### A. 自动（`run.sh`）

| 项 | 命令 | 判据 |
|----|------|------|
| 管线 build | `node tools/style-dictionary/build.mjs` | 退出 0，产物生成 |
| Flutter 分析 | `fvm flutter analyze`（组件库代码） | 0 警告 |
| Flutter 测试 | `fvm flutter test` | 全绿 |
| Web 类型 + 构建 | `npm --prefix web run build` | tsc 0 错 + build 成功 |

### B. 半自动：Figma 绑定审计（经 `use_figma`）

- 由 Claude / agent 用 `use_figma` 执行 `tools/figma-audit/audit-component.js`（顶部 `COMPONENT_SET_ID` 换成目标组件的 Component Set id）。
- 判据：返回 `✅ 0 未绑`（仅 padding=0 豁免）。
- **为何不进 `run.sh`**：Figma 变量绑定只能经 Plugin API（`use_figma`）或变量 REST API 读取，而后者仅 Figma Enterprise 开放；普通命令行 / CI 读不到绑定。故此项经 MCP 一键执行，不强塞进 shell（见 `component-dev-pitfalls.md` 约束）。

### C. 人工抽查（契约符合性，对照 `component-contract.md`）

- [ ] variant 中性命名、全变体矩阵齐（variant × state × icon）
- [ ] 三端齐备（Figma / Flutter / Web），同一 variant 契约
- [ ] **comp 单一入口**：三端只读 `comp/<组件>/*`（颜色 + 尺寸），无直读 `sys/*` / `ColorScheme`（字体除外）
- [ ] 明暗终值三端**同源同值**（抽样 2~3 个变量解析核对）
- [ ] Code Connect 绑定（React `figma.connect` + Flutter template）

## 通过判据

**自动全绿 + Figma 0 未绑 + 人工清单全勾** = 组件完成。
