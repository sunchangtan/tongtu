## 1. Figma typography（Text Styles → DTCG）

- [ ] 1.1 取证：Figma Text Styles API（`getLocalTextStylesAsync`）的读取形态；与现有 `sys/ui/font` 数值档的关系（落地前先取证）
- [ ] 1.2 在 Figma 建 M3 type scale Text Styles（15 档，M3 标准值；fontFamily 用默认）
- [ ] 1.3 导出 DTCG typography composite → `tokens/typography.json`；人工抽样核对档位值 == M3 规范

## 2. 扩 token 管线

- [ ] 2.1 冒烟：SD（`usesDtcg`）能否解析 typography composite token（取 `$value` 各子属性）
- [ ] 2.2 扩 `build.mjs` + 自写 `format/flutter` 分支：typography → Flutter `TextTheme`（M3 13 角色映射）
- [ ] 2.3 扩 `format/css` 分支：typography → CSS（utility classes 或 vars）

## 3. 产物与集成（TDD）

- [ ] 3.1 生成 `lib/ui/tokens/` typography（`TextTheme`/`TextStyle`，顶部标 GENERATED）
- [ ] 3.2 `app_theme.dart` 接入 `ThemeData.textTheme`；widget 测试验证关键档取自生成值
- [ ] 3.3 生成 `web/tokens/tokens.css` typography；跨栈同值核对（明/暗无关，抽样档位）

## 4. Foundations 展示页（Figma 设计资产）

- [ ] 4.1 色板展示：ref tonal 色阶 + sys 语义色（明暗对照）
- [ ] 4.2 字阶展示：type scale 15 档样板
- [ ] 4.3 间距/圆角标尺：`sys/ui/space`、`radius` 可视化

## 5. 质量门禁与验证

- [ ] 5.1 `dart analyze` 0 警告 + `dart format` 规范 + `flutter test` 全过（fvm）
- [ ] 5.2 跨栈同值终检：同一 type scale 档在 Flutter 与 CSS 产物字体属性一致
- [ ] 5.3 `openspec validate design-foundations --strict` 通过；实施完成后 `openspec archive`
