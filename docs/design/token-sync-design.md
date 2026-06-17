# 跨栈 Token 同步基础设施 · 设计方案

- 版本：v1.1（设计阶段，待评审）
- 日期：2026-06-17
- 定位：通途多端组件库的**子项目 0**（根基），先于组件实现
- 关联：`docs/design/logo-spec.md`（设计 token 来源），Figma「Tongtu Brand」变量体系

---

## 1. 背景与目标

通途要建三端组件库（Figma 设计 / Flutter app / Web React-MUI），三端必须共享同一套设计 token，否则各自漂移。本子项目搭建**跨栈 token 同步管线**：以 Figma 变量为源，产出标准 token 文件，自动生成各端可用的 token（Flutter Dart + CSS），实现单一真相源、跨栈一致。

参照业界主流（Material / Spectrum / Primer）：**W3C DTCG 格式 + Style Dictionary 转换**。

---

## 2. 范围（v1，YAGNI）

| 范围内 | 范围外（future） |
|--------|------------------|
| 颜色（ref 基础色 + sys 语义，含明暗）、间距、圆角、尺寸/字号 | 字体文件、阴影、动效 |
| DTCG JSON 源 → Flutter Dart + CSS 两端产出 | React 组件本身（后续子项目）|
| 手动同步流程 + README | CI 自动化（Figma webhook → build → PR）|
| agent 半自动导出 | REST API（需 Enterprise）/ Tokens Studio 工程化导出 |

---

## 3. 管线架构

```
Figma 原生变量（ref/sys，已建）
  │  ① 导出（agent 半自动：use_figma 读变量 → 序列化）
  ▼
tokens/*.json（W3C DTCG 标准格式，提交 git，单一真相源）
  │  ② Style Dictionary 转换（Node）
  ▼
  ├─ lib/ui/tokens/tokens.g.dart   （Flutter：明/暗语义色常量 + 维度常量；ColorScheme 在 app_theme 拼）
  └─ web/tokens/tokens.css         （CSS：var(--x)，:root / [data-theme=dark]；web 通用，接 MUI 由 React 子项目定）
```

---

## 4. 目录结构（新增）

```
tokens/                          # DTCG JSON 源（Figma 导出，提交）
  ref.json                       # ref 层：基础色（future 规整为 HCT tonal palette）
  sys.color.light.json           # sys 语义色 · 浅色 token set
  sys.color.dark.json            # sys 语义色 · 深色 token set
  sys.dimension.json             # spacing / size / radius（无明暗）
tools/style-dictionary/
  package.json                   # Node：style-dictionary v4（开启 usesDtcg）
  build.mjs                      # 构建编排：用 SD Node API 跑 light/dark 两套（见 §6）
  format/flutter.mjs             # 自写 Dart format：合并明/暗 → 单 tokens.g.dart
  format/css.mjs                 # 自写 CSS format：:root + [data-theme=dark] 两块
  README.md                      # 同步流程
lib/ui/tokens/tokens.g.dart      # 生成物（顶部标 GENERATED，勿手改）
web/tokens/tokens.css            # 生成物（CSS 变量，提交，供 web/React 消费）
```

---

## 5. DTCG 格式与明暗处理（review 修正点）

- 采用 **W3C Design Tokens（DTCG）** 格式：`{ "$type": "color", "$value": "#3F51B5" }`；alias 用引用 `{ref.indigo.40}`。
- **明暗用 token sets（标准做法，非单 token 两值）**：`sys.color.light.json` 与 `sys.color.dark.json` 两套语义色 set，共享同一 `ref.json`。每个 mode 各跑一次解析，输入组合：
  - 浅色 = `ref.json` + `sys.color.light.json` + `sys.dimension.json`
  - 深色 = `ref.json` + `sys.color.dark.json` + `sys.dimension.json`
- 维度类（spacing/size/radius）无明暗，单 set，两次解析共用。
- **明暗如何并入单个 Flutter 文件**：不靠纯 config（SD 一次 build 只出一组文件），改用 SD 的 Node API（`build.mjs`）分别解析浅/深两套，再由自写 format 把两组语义色合并写入同一个 `tokens.g.dart`（`_SysColorsLight` / `_SysColorsDark` 两组常量 + 共享维度常量）。CSS 端两套各出一块，合并为 `:root` + `[data-theme=dark]`。

---

## 6. 三个环节

### ① 导出器（agent 半自动起步）
- 用 `use_figma` 读取全部变量集合（Primitives / App Theme / Brand / Spacing / Size / Radius）及 alias 关系，序列化为 DTCG JSON（按 ref/sys、light/dark 分文件），由 agent 写入 `tokens/`。
- **为何半自动**：Figma Variables REST API 仅 Enterprise 可用（已查证：官方文档「available to full members of Enterprise orgs」），当前为 Organization plan，无法用 REST 全自动；Tokens Studio 需迁移变量管理。故 v1 用 agent 导出起步，导出环节标注「future 升级 REST API（升 Enterprise 后）或 Tokens Studio」。
- **关键认知**：核心工程在后半段（DTCG→SD→产物），导出是可替换前端，先扎根基。

### ② Style Dictionary（Node）
- `tools/style-dictionary/`，引入 style-dictionary v4（支持 DTCG，**需在 config/parser 显式开 `usesDtcg: true`**——默认仍读旧的 `value`/`type`）。
- 用 `build.mjs` 以 SD Node API 编排：对浅/深两套各解析一次（输入组合见 §5），共用维度集。
- CSS：自写 `format/css.mjs`，把两套合并为 `:root`（浅）+ `[data-theme=dark]`（深）→ `var(--x)`。
- Flutter：**自写 `format/flutter.mjs`**（SD 无官方 Dart platform）→ 生成 `Color(0xFF…)` 颜色常量（明/暗两组）与 `const double` 维度常量，合并进同一个 `tokens.g.dart`。**不在此拼 ColorScheme**（拼装放 app_theme，见 §7）。

### ③ 生成物
- Flutter：`tokens.g.dart` —— `_SysColorsLight` / `_SysColorsDark` 两组语义色常量 + 共享维度常量；顶部注释 GENERATED，勿手改。
- CSS：`tokens.css` —— `:root`（浅色）+ `[data-theme=dark]`（深色）。

---

## 7. 与现有 `app_theme.dart` 集成

`app_theme.dart` 从「硬编码颜色」改为「引用生成的 `tokens.g.dart` 常量」——token 成为单一真相源，Figma 改 → 重新导出+生成 → app 自动跟随。

**ColorScheme 拼装方式（v1，YAGNI）**：保持现有逻辑——`ColorScheme.fromSeed(seed)` 打底生成完整 M3 全套角色（surface 层级、inverse、scrim 等几十个），再用 `tokens.g.dart` 的明/暗语义色常量 `copyWith` 覆盖那 17 个品牌关键角色（primary/secondary/surface/…）。差别只是被覆盖的颜色值来自生成常量、不再硬编码；其余角色仍由 fromSeed 派生。

**为何不全用生成 token 拼**：Figma `App Theme` 只有 17 个/mode，不足以覆盖 M3 的 40+ 角色；用真 HCT tonal palette 自算全套角色工程量大且需先把 ref 规整为标准色阶，留 future。`AppTheme.light/dark` 对外接口不变（`main.dart` 无需改）。

---

## 8. 同步流程（手动，v1）

1. agent 运行 `use_figma` 导出 → 写 `tokens/*.json`；
2. `cd tools/style-dictionary && npm install && node build.mjs`；
3. 检查生成物（`dart analyze` 0 警告）→ 提交 `tokens/` 与生成物。

README 记录命令。**future**：CI 自动（Figma webhook/定时 → 导出 → build → 自动 PR）。

---

## 9. 验证（完成判据）

- 抽样核对：生成的 Flutter/CSS token 值 == Figma 变量值（明暗各抽几个）；
- `dart analyze lib/ui/tokens lib/ui/app_theme.dart` 0 错误 0 警告；
- app 切换系统明暗，主题色随 token 正确变化（真机/模拟器）；
- CSS 变量在浅色/深色块值正确。

---

## 10. 风险与权衡

| 风险 | 应对 |
|------|------|
| 导出半自动、依赖 agent | 标注 future 工程化（REST API/Tokens Studio/CI）；核心管线不受影响 |
| SD 无官方 Dart + 明暗需并入单文件 | 用 SD Node API（`build.mjs`）编排两套解析，自写 format 合并；逻辑集中、参考社区 flutter transform |
| 明暗 token sets 正确性 | §9 抽样核对明暗各值 |
| 引入 Node 工具链到 Flutter+Go 仓库 | 隔离在 `tools/style-dictionary/`；将来与 React/web 子项目共享 |

---

## 11. 版本记录

| 版本 | 日期 | 变更 |
|------|------|------|
| v1.0 | 2026-06-17 | 初稿：W3C DTCG + Style Dictionary 管线；agent 半自动导出起步；明暗用 token sets；Flutter 自写 format；CI/REST/Tokens Studio 列 future。经主流方案 review 修正。 |
| v1.1 | 2026-06-17 | 二次 review 修正：明确明暗并入单 tokens.g.dart 的机制（SD Node API 编排 build.mjs + 自写 format）；ColorScheme 定为 fromSeed 打底 + 生成常量 copyWith（YAGNI）；点明 usesDtcg；CSS 产物移出 build/ 至 web/tokens/；写明每个 build 输入组合；弱化「CSS 供 MUI」与「ref tonal」措辞；analyze 改 dart analyze。 |
