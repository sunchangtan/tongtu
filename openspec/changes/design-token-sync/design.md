## Context

通途要建三端组件库（Figma / Flutter / Web React-MUI），三端共享设计 token。本 change 是**子项目 0（根基）**：搭 Figma→DTCG→Style Dictionary→（Flutter + CSS）的跨栈 token 同步管线。完整设计见 `docs/design/token-sync-design.md`（v1.1）；本文件提炼该 change 的关键决策与边界。

关键约束：
- **单一真相源**：token 源在 `tokens/`（DTCG），三端产物皆由其生成，不各自硬编码。
- **不发明私有格式**：用 W3C DTCG 标准（对齐 Material / Spectrum / Primer）。
- **导出半自动**：Figma Variables REST API 仅 Enterprise 可用（已查证：官方「available to full members of Enterprise orgs」），当前 Organization plan → 导出半自动起步。
- **工具链隔离**：Node / Style Dictionary 限于 `tools/`，不污染 Flutter / Go 构建。

## Goals / Non-Goals

**Goals:**
- DTCG token 源：ref 基础色 + sys 语义色（明暗两 token set）+ UI 维度（间距 / 圆角 / 字号，参照 M3，新建于 `sys/ui/*`）。
- 生成 Flutter（`tokens.g.dart`：明暗两组常量 + 维度常量）+ CSS（`:root` / `[data-theme=dark]`）。
- app_theme 引用生成 token，明暗切换正确，对外接口不变。
- 跨栈同值（Flutter 与 CSS 同一语义 token 同值）。

**Non-Goals:**
- M3 全 40+ 角色自算（现 fromSeed 打底，YAGNI；见 D3）。
- 字体文件 / 阴影 / 动效 token；字号的行高 / 字重 / 字间距（M3 type scale 其余维度，future）。
- React 组件本身（子项目 C）；CSS→MUI palette 映射归子项目 C。
- CI 自动化、REST / Tokens Studio 全自动导出。

## Decisions

### D1：W3C DTCG + Style Dictionary（不发明格式）
token 源用 DTCG（`$type` / `$value` / alias `{ref.x}`）；转换用 Style Dictionary v4。SD v4 默认仍读旧 `value` / `type`，**须显式开 `usesDtcg: true`**，否则解析不到值。
- **备选**：Tokens Studio 全流程 → 需迁移变量管理，重；纯自定义脚本 → 重造轮子、无社区生态。

### D2：明暗用 token sets，并入单个 Flutter 文件靠 SD Node API
明暗各一套语义色 set（light / dark），共享 ref；维度单 set。每个 mode 各解析一次，输入组合：
- 浅色 = `ref.json` + `sys.color.light.json` + `sys.dimension.json`
- 深色 = `ref.json` + `sys.color.dark.json` + `sys.dimension.json`

**明暗如何并入单个 `tokens.g.dart`**：SD 一次 build 只出一组文件，故不用纯 config，改用 SD Node API（`build.mjs`）分别解析两套，自写 format 合并写入同一文件（`_SysColorsLight` / `_SysColorsDark` 两组常量 + 共享维度常量）。CSS 端两套各出一块，合并为 `:root` + `[data-theme=dark]`。
- **备选**：单 token 两值（非标准、SD 不友好）；生成两个 dart 文件（消费端要 import 两处，不如单文件）。

### D3：ColorScheme = fromSeed 打底 + 生成常量 copyWith（YAGNI）
app_theme 保持现有逻辑：`ColorScheme.fromSeed(seed)` 生成完整 M3 全套角色，再用 `tokens.g.dart` 的明暗语义色常量 `copyWith` 覆盖品牌关键角色（~17 个）；其余角色仍由 fromSeed 派生。差别仅是被覆盖值来自生成常量、不再硬编码。
- **为何不全用生成 token 拼完整 ColorScheme**：Figma `App Theme` 仅 17 / mode，不足覆盖 M3 的 40+ 角色；source 不变时全角色映射结果 ≈ fromSeed，付出重建 ref tonal palette + 80+ alias 的成本只换「脱离算法手调个别角色」，当前无组件消费细分角色 → YAGNI，留 future。混合模式还能随 Flutter / M3 升级自动获得新增角色。
- **备选**：真 HCT tonal palette 全角色映射 → 终态，但现阶段过度设计；届时用 Material Theme Builder / Figma M3 插件生成、成本大降。

### D4：产物框架无关，Web 适配归子项目 C
生成物只是框架无关数据：CSS 变量 + Dart 常量。MUI（稳定版仍 Material 2 调色：`primary.main/light/dark` + `augmentColor` 自动补全）如何引用 CSS 变量、把 sys token 映射进其 palette，属 Web 组件子项目（C）。本 change 不预设 MUI 用法。
- **依据**：MUI 自带 `augmentColor`「打底」（等价 Flutter fromSeed），token 只供关键品牌色即可；复杂路 40+ 角色对 M2-MUI 反而过剩。

### D5：工具链隔离 + 生成物提交
Node / SD 限 `tools/style-dictionary/`（`node_modules` gitignore）。生成物（`tokens.g.dart`、`tokens.css`）提交 git（消费端直接引用，避免每次构建依赖 Node）。CSS 放 `web/tokens/`（非 `build/`，避开 Flutter gitignore）。`tokens.g.dart` 顶部标 GENERATED、勿手改。

### D6：UI 维度 token 新建（参照 M3），与 logo 资产维度隔离
取证（task 1.1）发现 Figma 现有 Spacing / Size / Radius 变量是 logo 设计稿尺度（字号 200、尺寸 1024、圆角 512、间距含 `clearspace` / `mark-gap`），不适合做 UI / 组件 token。故 v1 颜色沿用现有 `ref` + `sys/color`，**维度新建一套 UI 尺度 token**（参照 Material 3 + 4dp 栅格）：
- `sys/ui/space/*`：0 / 4 / 8 / 12 / 16 / 24 / 32 / 48（4dp 栅格）
- `sys/ui/radius/*`：0 / 4 / 8 / 12 / 16 / 28 / 9999（M3 shape scale）
- `sys/ui/font/*`：12 / 14 / 16 / 20 / 24 / 32（M3 type scale 常用档，纯字号）

命名用 `sys/ui/*` 子空间，与 logo 资产维度（`sys/space` 等）物理隔离，不动 logo 变量。字号行高 / 字重 / 字间距留 future（Flutter M3 `textTheme` 自带）。
- **备选**：把 logo 维度迁到 `brand/*` 释放 `sys/space` 给 UI → 命名更对称，但需动 logo 变量、现阶段不必，否决。

## Risks / Trade-offs

- **导出半自动、依赖 agent** → 标 future 工程化（REST API 升 Enterprise / Tokens Studio / CI）；核心管线（DTCG→SD→产物）不受导出方式影响，可后替换。
- **SD 无官方 Dart platform + 明暗需并入单文件** → 用 SD Node API 编排两套解析、自写 format 合并；逻辑集中于 `build.mjs` + `format/flutter.mjs`，参考社区 flutter transform。
- **明暗 token sets 正确性** → 抽样核对生成的 Flutter / CSS 明暗各值 == Figma 源。
- **引入 Node 到 Flutter+Go 仓库** → 隔离 `tools/`，不入 app / 内核构建路径；将来与 Web 子项目共享。

## Migration Plan

1. Figma 导出 DTCG → 写 `tokens/*.json`，人工抽样核对。
2. 搭 Style Dictionary（`tools/`，`usesDtcg` + `build.mjs`）→ 生成 `tokens.g.dart` + `tokens.css`。
3. app_theme 改引用生成常量 → `dart analyze` 0 警告、明暗切换验证。

回滚：app_theme 退回硬编码颜色即可，生成管线为增量、无破坏性。

## Open Questions

- 自写 Flutter format 的精确产物形态（裸常量 vs 包一层 class）——实施时定，倾向 private 常量 + app_theme 引用。
- CSS 变量命名前缀与 Figma code syntax（WEB `var(--x)`）的精确对齐——实施时按 Figma 现有 code syntax 落。
