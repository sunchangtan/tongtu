## Context

Button token 现状碎片化：颜色由 M3 `ColorScheme` 框架自动取、尺寸分 `TongtuDimens`（padding/shape）+ `TongtuComp`（结构尺寸）两处、字体走 `tongtuTextTheme`。用户痛点「尺寸从两个地方读取」即此。

已用 SD 探针验证（`tools/style-dictionary` 临时脚本，验证后删）：
- **多级别名** comp→sys→ref 由 SD v4 原生解析——`comp/button/filled/container-color` → `{sys.color.primary}` → `{ref.indigo.40}` → `#3f51b5`（终值）；`disabled-container` → `#1a1c2a1f`（带 alpha 正确）。
- **前提**：被引用 token 须同处一个解析 source。现有 `resolveTokens` 的 source（ref + sys.color + sys.dimension + comp）已覆盖 comp 引 sys.color / sys.ui 的全部需要，**无需改 source**（探针中唯一报错的引用是字体 `{type.label.large}`，因 typography 单独解析；本 change 字体不纳入 comp，见 D2）。

## Goals / Non-Goals

**Goals:**
- 完整 `comp/button/*`（颜色按变体 + disabled + 尺寸），组件三端只读 comp。
- 管线 format 支持 comp 多类型（颜色明暗 + 尺寸）。
- Flutter / Web / Figma Button 改读 comp，获组件级定制能力。
- 立 comp 单一入口模板，A3 沿用。

**Non-Goals:**
- **字体纳入 comp**（D2）：三端字体走全局 type scale，组件级换字体罕见（YAGNI）。
- **A3 其他组件实施**：本 change 只做 Button + 模板 + 管线支撑。
- **size 变体**：Button 单尺寸，不引入 size 维度。
- **hover / pressed state layer 纳入 comp**：交由框架按 foreground 自动（YAGNI）。
- **Web 暗色主题**：Web 当前单 light，comp 颜色 Web 端取 light，暗色非本 change 范围。

## Decisions

### D1：comp/button/* 全集（颜色按变体 + disabled + 尺寸）
对齐 M3 官方（`md.comp.*-button.*`），颜色按变体拆，使每变体独立可定制：
```
尺寸（单套，无明暗）
  comp/button/container-height   = 40px                    (固有)
  comp/button/icon-size          = 18px                    (固有)
  comp/button/outline-width      = 1px                     (固有)
  comp/button/padding-horizontal = {sys.ui.space.xl}       → 24
  comp/button/shape              = {sys.ui.radius.full}    → 9999
变体颜色（随明暗）
  comp/button/filled/container-color   = {sys.color.primary}
  comp/button/filled/label-color       = {sys.color.on-primary}
  comp/button/tonal/container-color    = {sys.color.secondary-container}
  comp/button/tonal/label-color        = {sys.color.on-secondary-container}
  comp/button/outlined/label-color     = {sys.color.primary}
  comp/button/outlined/outline-color   = {sys.color.outline}
  comp/button/text/label-color         = {sys.color.primary}
  comp/button/elevated/container-color = {sys.color.surface}
  comp/button/elevated/label-color     = {sys.color.primary}
disabled（随明暗，引 sys disabled）
  comp/button/disabled-container = {sys.color.disabled-container}
  comp/button/disabled-label     = {sys.color.disabled-content}
  comp/button/disabled-icon      = {sys.color.disabled-icon}
  comp/button/disabled-outline   = {sys.color.disabled-border}
```
变体取色与现有 Button（`button.dart`）一致：filled=primary、tonal=secondary-container、outlined=outline 描边 + primary 文字、text=primary、elevated=surface 容器 + primary 文字。

### D2：字体不纳入 comp（边界）
三端字体消费机制本就独立于 comp 且全局：Flutter `tongtuTextTheme.labelLarge`、CSS `.type-label-large`、MUI `theme.typography`。强行纳入会逼 CSS/TS 端处理 typography composite（拆字段或特殊引用），复杂度高、与原生字体机制相悖；组件级换字体是罕见特例（YAGNI）。故 **comp 单一入口范围 = 颜色 + 尺寸**；字体走全局 type scale。Button 颜色/尺寸只读 comp、字体读 type scale——契约文档写明此边界。

### D3：多级别名由 SD v4 原生解析（无需改解析器）
comp→sys→ref 链由 SD 解析为终值（探针已验证）。前提：被引用 token 同处一个 source 集合——现有 `resolveTokens` source 已齐备（comp 只引 sys.color / sys.ui）。`build.mjs` 不改。

### D4：comp 颜色随明暗（免费得两套）
`build.mjs` 已对 `sys.color.light.json` / `sys.color.dark.json` 各解析一次，`comp.json` 在两次 source 中均在。故 `comp/button/filled/container-color` 在 lightTokens 解析为 light primary、darkTokens 解析为 dark primary——comp 颜色「免费」得明暗两套。format 分别从 light / darkTokens 提取 comp 颜色。

### D5：Flutter 产物结构（尺寸单套 + 颜色明暗两套）
- 尺寸（无明暗）：`TongtuComp { buttonContainerHeight, buttonIconSize, buttonOutlineWidth, buttonPaddingHorizontal, buttonShape }`（double）。
- 颜色（明暗）：`TongtuCompColorsLight` / `TongtuCompColorsDark { buttonFilledContainerColor, buttonFilledLabelColor, ..., buttonDisabledContainer, ... }`（Color）。

comp format 按 `$type` 区分 color / dimension（实现时先验证解析后 token 带 `$type`，否则按值形态 `#...` / `...px` 兜底）。

### D6：Flutter Button 显式设色（取舍）
组件「只读 comp」要求切断对 `ColorScheme` 自动取色的隐式依赖——各变体 `ButtonStyle` 显式设 `backgroundColor` / `foregroundColor`（从 comp 取）。取舍：
- **失**：M3「一套 style 自动适配明暗」；改为明暗各一套 `ButtonStyle`（由 `_buttonThemes(compColors)` 参数化生成，不繁琐）。
- **得**：单一入口 + 组件级定制（改 comp/button 即改 Button，不动全局）。
- disabled 用 `WidgetStateProperty.resolveWith` 按 `disabled` state 返回 comp disabled 色；hover / pressed 的 state layer 仍由框架按 `foregroundColor` 自动生成（不纳入 comp，D-NonGoal）。
- **默认皮肤下显式设色 == M3 默认**（comp 引的就是 ColorScheme 同源 sys），故**外观不变**——价值在可定制性，不在改默认外观。回归测试确认外观与现状一致。

### D7：Web 取 comp 色
`theme.ts` 的 `MuiButton` styleOverrides 与 `Button.tsx` 的 tonal / elevated `sx` 从 `comp/button/*`（tokens.ts 的 comp）取色，替换硬引 `colorsLight.*`。`ts.mjs` 的 comp 输出扩展为含颜色（明暗两套）+ 尺寸；Web 端取 light（暗色非本 change 范围，D-NonGoal）。

### D8：Figma comp/button/* 变量 + Button 重绑
Component collection 建 `comp/button/*` 变量：颜色用 alias 引 App Theme 的 `sys/color/*`（明暗两 mode）、尺寸用 alias 引 UI Dimension（padding/shape）+ 固有字面值（height/icon/outline）。Button 20 变体把 fill / label / outline / 结构尺寸重绑到 comp（替换原绑 sys）。审计门禁沿用（绑变量即过，comp 或 sys 皆为变量）。

### D9：组件级定制能力（本 change 的核心收益）
单一入口使「改 `comp/<组件>/*` 只影响该组件」成为可能——例如把 `comp/button/filled/container-color` 从 `{sys.color.primary}` 改为别的 sys 色或固有色，仅 Button 变，全局 sys 与其他组件不受影响。这是 sys 直读做不到的。

## Risks / Trade-offs

| 风险 | 应对 |
|------|------|
| 解析后 comp token 是否带 `$type`（区分 color/dim） | 实现时先实验确认；否则按值形态（`#...` vs `...px`）兜底 |
| Flutter 显式设色 → app_theme 变长 | `_buttonThemes(compColors)` 参数化，明暗各调一次 |
| 默认皮肤显式设色与 M3 默认是否一致 | comp 引同源 sys，理论一致；回归测试（现有 64）+ 模拟器抽样确认外观不变 |
| Web comp 明暗 | Web 当前单 light，comp 取 light，保持现状（暗色非本 change） |
| Figma 颜色 alias 跨 collection（Component→App Theme） | use_figma 建变量时跨 collection alias 引用；建后审计 0 未绑确认 |

## Migration Plan

1. `tokens/comp.json` 扩展 → 跑 `build.mjs`，验证多级别名解析 + comp 明暗颜色 → 调 format（flutter / ts / css 支持 comp 多类型）。
2. `app_theme` Button 改读 comp（显式设色明暗两套）→ Flutter `analyze` + `test`（外观回归不变）。
3. `web` theme / Button 改读 comp → `tsc` + `build`。
4. Figma `comp/button/*` 变量 + Button 20 变体重绑 → 审计 0 未绑。
5. 契约文档更新 → `openspec validate --strict` → `archive`。

**回滚**：comp 颜色为增量；app_theme / web 改回读 sys / ColorScheme 即恢复。
