## 1. 管线：comp 多类型 token + format

- [x] 1.1 `tokens/comp.json` 扩展：颜色按变体（filled/tonal/outlined/text/elevated 引 sys.color）+ disabled（引 sys.color.disabled-*）+ 尺寸（padding/shape 引 sys.ui，height/icon/outline 固有）
- [x] 1.2 `format/flutter.mjs`：comp 按 `$type` 分流——color 生成 `TongtuCompColorsLight/Dark`（明暗两套 Color）、dimension 生成 `TongtuComp`（单套 double）
- [x] 1.3 `format/ts.mjs` + `format/css.mjs`：comp 多类型（颜色明暗 + 尺寸；CSS 颜色明暗分流 :root/[data-theme=dark]）
- [x] 1.4 跑 `node tools/style-dictionary/build.mjs`：验证多级别名 comp→sys→ref 解析为终值、comp 颜色明暗两套、Flutter `dart format` 通过

## 2. Flutter：Button 只读 comp

- [x] 2.1 `components/button.dart`：各变体按 variant + 明暗从 comp 显式取色（`_styleFor`——因 filled/tonal 共享 M3 `FilledButtonTheme`，色须置组件层而非 component theme）；disabled 用 `WidgetStateProperty` 取 comp disabled 色
- [x] 2.2 Button 尺寸（shape/padding/min-height/icon-size）改取 `TongtuComp`（`app_theme._sizeStyle`），去除对 `TongtuDimens` 的直接引用
- [x] 2.3 `flutter analyze` 0 警告；`flutter test` 通过（64 全绿，外观回归不变）

## 3. Web：Button 只读 comp

- [x] 3.1 `theme.ts`：`MuiButton` styleOverrides 尺寸（圆角 `comp/button/shape`、内距 `padding-horizontal`、高度 `container-height`）从 comp 取
- [x] 3.2 `Button.tsx`：各变体（含 tonal/elevated/disabled）`sx` 从 `compColorsLight` 取色，替换硬引 `colorsLight`
- [x] 3.3 `tsc --noEmit` + `vite build` 通过（412 modules）

## 4. Figma：comp/button/* 变量 + Button 重绑

- [x] 4.1 Component collection 建 `comp/button/*` 变量（13 色 + 2 尺寸，id 157:2~16）：颜色 alias 引 `sys/color/*`（单 mode alias，明暗由消费端 mode 穿透）、padding/shape alias 引 UI Dimension；height/icon/outline 固有值已存
- [x] 4.2 Button 20 变体重绑 comp：容器/文字/描边/图标色 + 圆角/内距 → `comp/button/*`
- [x] 4.3 审计 `audit-component.js`：0 未绑；并解析核对 comp 明暗终值与 token 同源同值

## 5. 契约 + 验证归档

- [x] 5.1 `docs/design/component-contract.md`：写明 comp 单一入口范围（颜色 + 尺寸，字体走 type scale）+ A3 沿用模板（v1.1）
- [x] 5.2 `openspec validate comp-single-entry --strict` 通过
- [x] 5.3 `openspec archive comp-single-entry`
