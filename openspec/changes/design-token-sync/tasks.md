## 1. Figma 导出 DTCG（agent 半自动）

- [ ] 1.1 用 `use_figma` 读取全部变量集合（Primitives / App Theme / Brand / Spacing / Size / Radius）及 alias 关系，确认变量 id、scope、code syntax（落地前先取证）
- [ ] 1.2 序列化为 DTCG JSON，按 ref / sys、明暗分文件写入 `tokens/`（`ref.json`、`sys.color.light.json`、`sys.color.dark.json`、`sys.dimension.json`）
- [ ] 1.3 人工抽样核对：导出值（明暗各几个）== Figma 变量值；alias 链正确

## 2. Style Dictionary 搭建（Node 工具链）

- [ ] 2.1 `tools/style-dictionary/`：`package.json` 引入 style-dictionary v4；`.gitignore` 忽略 `node_modules`
- [ ] 2.2 `build.mjs`：SD Node API，开启 `usesDtcg`；按输入组合分别解析明 / 暗两套（共用维度集）
- [ ] 2.3 冒烟：先用 SD 标准 `css/variables` 跑通，验证 DTCG 源可解析、alias 正确求值

## 3. Flutter 产物生成（自写 format，TDD）

- [ ] 3.1 `format/flutter.mjs`：自写 Dart format，输出 `Color(0xFF…)` 颜色常量 + `const double` 维度常量
- [ ] 3.2 `build.mjs` 合并明 / 暗两套 → 单 `lib/ui/tokens/tokens.g.dart`（`_SysColorsLight` / `_SysColorsDark` + 共享维度常量），顶部标 GENERATED
- [ ] 3.3 抽样核对：`tokens.g.dart` 明暗各值 == Figma 源

## 4. CSS 产物生成（自写 format）

- [ ] 4.1 `format/css.mjs`：自写 CSS format，明 → `:root`、暗 → `[data-theme=dark]`，`var(--x)`
- [ ] 4.2 `build.mjs` 输出 `web/tokens/tokens.css`；核对明暗块值正确

## 5. app_theme 集成（Dart，TDD）

- [ ] 5.1 `app_theme.dart`：改为引用 `tokens.g.dart` 常量做 `fromSeed` 打底 + `copyWith` 覆盖品牌关键角色；对外接口不变
- [ ] 5.2 widget 测试：浅 / 深主题品牌关键角色取自生成常量；明暗切换正确

## 6. 质量门禁与验证

- [ ] 6.1 `dart analyze lib/ui/tokens lib/ui/app_theme.dart` 0 错误 0 警告；`dart format` 规范；`flutter test` 全过
- [ ] 6.2 `tools/style-dictionary/README.md`：记录同步流程（Figma 导出 → `node build.mjs` → 抽样核对 → 提交 `tokens/` 与生成物）
- [ ] 6.3 跨栈同值终检：同一语义 token 在 `tokens.g.dart` 与 `tokens.css` 同值（明暗各抽样）
- [ ] 6.4 `openspec validate design-token-sync --strict` 通过；实施完成后 `openspec archive`
