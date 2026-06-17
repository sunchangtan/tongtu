## 1. Figma typography（Text Styles → DTCG）

- [x] 1.1 取证：Figma Text Styles 为空（需全新建）；`sys/ui/font` 6 档数值已有（保留作数值档）；API 形态确认
- [x] 1.2 在 Figma 建 M3 type scale 15 档 Text Styles（Roboto，M3 标准值）
- [x] 1.3 导出 DTCG typography composite → `tokens/typography.json`；清理 Figma float32 精度噪声为规范值

## 2. 扩 token 管线

- [x] 2.1 冒烟：SD（`usesDtcg`）成功解析 typography composite token（15 档 $value 完整）
- [x] 2.2 扩 `build.mjs` + 自写 `format/typography.mjs`：typography → Flutter `TextTheme`（15 角色映射）
- [x] 2.3 同 format：typography → CSS utility classes（`.type-*`）

## 3. 产物与集成（TDD）

- [x] 3.1 生成 `lib/ui/tokens/typography.g.dart`（`tongtuTextTheme`，GENERATED；build 自动 dart format）
- [x] 3.2 `app_theme.dart` 接入 `ThemeData.textTheme`；widget 测试验证关键档取自生成值
- [x] 3.3 生成 `web/tokens/typography.css`；跨栈同值核对（Flutter TextTheme ↔ CSS，抽样档位）

## 4. Foundations 展示页（Figma 设计资产）

- [x] 4.1 色板：ref tonal 色阶 + sys 语义色（Light/Dark frame mode 对照）
- [x] 4.2 字阶：type scale 15 档样板（应用对应 Text Style）
- [x] 4.3 间距/圆角标尺：`sys/ui/space`、`radius` 可视化

## 5. 质量门禁与验证

- [x] 5.1 `dart analyze` 0 警告 + `dart format` 规范 + `flutter test` 全过（fvm，44 测试）
- [x] 5.2 跨栈同值终检：同一 type scale 档在 Flutter `TextTheme` 与 CSS 字体属性一致
- [ ] 5.3 `openspec validate design-foundations --strict` 通过（已）；`openspec archive`
