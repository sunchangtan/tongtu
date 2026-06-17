## 1. Figma 变量准备与 DTCG 导出（agent 半自动）

- [x] 1.1 取证：枚举全部变量集合（Primitives / App Theme / Brand / Spacing / Size / Radius）及 alias、scope、code syntax。结论：颜色用 `ref`(35) + App Theme `sys/color`(17 明暗)；现有 Spacing/Size/Radius 是 logo 资产尺度、不适合 UI，维度改为新建
- [x] 1.2 在 Figma 新建 UI 维度变量（集合 `UI Dimension`，`sys/ui/space|radius|font` 共 21 个，参照 M3 + 4dp 栅格，带 WEB/iOS/Android code syntax）
- [x] 1.3 序列化导出 DTCG → `tokens/`：`ref.json`、`sys.color.light.json`、`sys.color.dark.json`、`sys.dimension.json`（UI 维度）
- [x] 1.4 人工抽样核对：导出值（颜色明暗 + 维度各几个）== Figma；alias 链正确

## 2. Style Dictionary 搭建（Node 工具链）

- [x] 2.1 `tools/style-dictionary/`：`package.json` 引入 style-dictionary v4；`.gitignore` 忽略 `node_modules`
- [x] 2.2 `build.mjs`：SD Node API，开启 `usesDtcg`；按输入组合分别解析明 / 暗两套（共用维度集）
- [x] 2.3 冒烟：SD `getPlatformTokens` 验证 DTCG 源可解析、alias 正确求值（`sys.color.primary` → `#3f51b5`）

## 3. Flutter 产物生成（自写 format，TDD）

- [x] 3.1 `format/flutter.mjs`：自写 Dart format，输出 `Color(0xFF…)` 颜色常量 + `const double` 维度常量
- [x] 3.2 `build.mjs` 合并明 / 暗两套 → 单 `lib/ui/tokens/tokens.g.dart`（`TongtuSysColorsLight` / `TongtuSysColorsDark` + `TongtuDimens`），顶部标 GENERATED
- [x] 3.3 抽样核对：`tokens.g.dart` 明暗各值 == Figma 源（且与原手写 app_theme 值吻合）

## 4. CSS 产物生成（自写 format）

- [x] 4.1 `format/css.mjs`：自写 CSS format，明 → `:root`、暗 → `[data-theme=dark]`，`var(--x)`
- [x] 4.2 `build.mjs` 输出 `web/tokens/tokens.css`；核对明暗块值正确

## 5. app_theme 集成（Dart，TDD）

- [x] 5.1 `app_theme.dart`：改为引用 `tokens.g.dart` 常量做 `fromSeed` 打底 + `copyWith` 覆盖品牌关键角色；对外接口不变
- [x] 5.2 widget 测试：浅 / 深主题品牌关键角色取自生成常量；明暗切换正确

## 6. 质量门禁与验证

- [x] 6.1 `dart analyze` 0 错误 0 警告 + `dart format` 规范 + `flutter test` 全过（fvm Flutter 3.44.2 / Dart 3.12.2，38 测试）
- [x] 6.2 `tools/style-dictionary/README.md`：记录同步流程（Figma 导出 → `node build.mjs` → 抽样核对 → 提交 `tokens/` 与生成物）
- [x] 6.3 跨栈同值终检：同一语义 token 在 `tokens.g.dart` 与 `tokens.css` 同值（明暗各抽样）
- [ ] 6.4 `openspec validate design-token-sync --strict` 通过（已）；实施完成后 `openspec archive`
