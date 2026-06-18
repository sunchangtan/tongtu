# 组件开发避坑库（Figma / Flutter / 管线特有）

- 定位：组件库三端开发中**特有**的坑，与通用 `code-review-checklist.md`（六类通用陷阱）互补。
- 用法：开发新组件（A3）前通读；踩新坑后**即时追加**，保持为活的经验库。
- 来源：A1 → comp 单一入口各 change 的实战教训。

## 核心：未经验证的假设是 bug 之源

组件开发横跨 **Figma 变量 API、Style Dictionary、Flutter M3、MUI** 四套黑盒，每套都有反直觉行为。铁律：**对黑盒行为，探针实验 > 文档推理 > 直觉**。本库每条坑几乎都是「想当然」的产物——comp 单一入口一役，3 次探针各拦下一个错误假设。

---

## A. 管线 / Token

### A1. 不验证 SD 别名 / 类型行为就写 format
- **现象**：以为多级别名要自己解析；以为解析后 token 不带 `$type`。
- **根因**：未验证 Style Dictionary 实际输出。
- **防范**：改 format 前写**最小探针**（建临时 token → resolve → 打印 `path / $type / $value`）。已实证：comp→sys→ref 多级别名 SD v4 原生解析为终值；解析后 token 带 `$type`（`color` / `dimension`），`type` 为 undefined——format 用 `t.$type` 分流。

### A2. 跨 source 引用解析失败
- **现象**：comp 引 `{type.label.large}` 报「reference could not be found」。
- **根因**：typography 由 `resolveTypography` 单独解析，不在 `resolveTokens` 的 source 集合；SD 只在**同一 source 集合**内解析别名。
- **防范**：被引用 token 必须与引用方同 source。据此决策字体不入 comp（跨 source + composite 复杂度高、收益低）——见 `component-contract.md` §4 边界。

### A3. comp 颜色明暗「免费」但 format 要分别取
- **现象**：纠结 comp 颜色要不要明暗两套。
- **根因**：`build.mjs` 已对 light / dark 各 resolve 一次，`comp.json` 在两次 source 中 → comp 颜色自动随明暗解析。
- **防范**：format 从 `lightTokens` / `darkTokens` 分别提取 comp 颜色 → 明暗两类（`TongtuCompColorsLight/Dark`）。

---

## B. Figma 变量（最密集）

### B1. disabled 透明度：绑 color + 手设 opacity 冲突
- **现象**：绑 color 变量后手设 `paint.opacity`，opacity 被吞。
- **根因**：Figma「绑定 + 手设透明」二者冲突。
- **防范**：用**带 alpha 的独立色变量**（α 烤进变量值，如 `#1a1c2a1f`）；绑 color 时 Figma 自动把 α 映射为 `paint.opacity`。绝不用 α=1 变量 + 手设 opacity。

### B2. strokeWeight 绑定展开四边
- **现象**：`setBoundVariable('strokeWeight', v)` 后 `boundVariables` 无 `strokeWeight` key。
- **根因**：展开绑到 `strokeTopWeight / Bottom / Left / Right`。
- **防范**：审计查 `strokeTopWeight`。

### B3. letterSpacing 读回 float32 噪声
- **现象**：读回 `letterSpacing` 带浮点噪声。
- **防范**：round 后再比较 / 写入。

### B4. alias 不能 override alpha
- **现象**：想 alias 一个变量却改其 alpha → 失败。
- **根因**：Figma alias 直接引用、α 跟随。
- **防范**：值相同才能 alias；不同 alpha 需独立实色变量。

### B5. comp 颜色单 mode alias 引 sys 双 mode
- **现象**：comp 变量建在单 mode collection，怎么随明暗？
- **根因**：alias 解析时**穿透到目标变量**，目标按消费端 mode 解析。
- **防范**：comp 颜色变量（单 mode）alias 引 `sys/color`（双 mode），明暗由消费节点的 App Theme mode 穿透；与 DTCG 端 comp 引 sys 明暗两套语义一致。建法：`createVariable(name, collectionObj, type)` + `setValueForMode(modeId, createVariableAlias(target))`。验证：解析 alias 链核对明暗终值与 token 同值。

---

## C. Flutter（M3 框架）

### C1. 共享 component theme 无法区分同 widget 的 variant
- **现象**：想用 `FilledButtonTheme` 给 filled 与 tonal 设不同色 → 互相覆盖。
- **根因**：`FilledButton` 与 `FilledButton.tonal` **共享同一 `FilledButtonTheme`**。
- **防范**：variant 间不同的属性（色）**置组件层**显式给出（wrapper 按 variant 构造 `ButtonStyle`）；variant 无关属性（尺寸）才走 component theme。**通则**：用任一 M3 widget 前，确认其 theme 是否被多 variant / 多构造共享。

### C2. 必用 fvm
- **现象**：用全局 dart 跑 → 版本不符、依赖报错（曾误判为 share_plus 需 Dart 3.10）。
- **防范**：所有 Flutter / Dart 命令一律 `fvm flutter` / `fvm dart`（锁 3.44.2 / Dart 3.12.2）。

### C3. 测试 runAsync / tap 配合、loading 动画
- **防范**：真实 IO 放 `runAsync` 内、`tap` 触发 onPressed 放 `runAsync` 外；有无限动画（loading）时初载不能 `pumpAndSettle`（用 `pump`）。

### C4. 显式设色与 M3 默认一致性
- **现象**：组件层显式设色后担心外观变。
- **根因**：comp 引的就是同源 sys，默认皮肤下显式色 == M3 默认。
- **防范**：回归测试 + 模拟器抽样确认外观不变；价值在「可定制」非「改默认外观」。

---

## D. Web（MUI）

### D1. Web 视觉验证：优先 preview 截图，受限时回退 build
- **现象**：部分沙箱环境 Claude Preview `getcwd` 失败、dev server 起不来；但常规环境 `preview_start`（`.claude/launch.json` 配 vite dev）可正常启动并 `preview_screenshot` 对照设计稿。
- **防范**：先试 `preview_start` + 截图（最直接，能逐变体对照 Figma）；若该环境确实起不来，再回退 `vite build`（命令行）+ 代码审查变体齐全。按环境择一，**不预设「一定起不来」**。

### D2. MUI 无 tonal / elevated 原生 variant
- **防范**：中性 variant → MUI variant 映射；无原生者（tonal / elevated）用 `sx` 自定义达同等语义。按 comp 单一入口，各 variant 色经 `sx` 从 comp 取（不靠 MUI palette 默认）。

### D3. Code Connect：parser 只在 config，命令行无 `--parser`
- **现象**：`figma connect publish --parser html` 报 `unknown option '--parser'`。
- **根因**：parser（`react` / `html`）只能在 config 文件配（`codeConnect.parser`），命令行没有 `--parser` 选项。
- **防范**：多端用多份 config——React `figma.config.json`（parser `react`）、Flutter `figma.flutter.config.json`（parser `html`）；publish / parse 用 `--config <file>` 切换。

### D4. Code Connect：html template 占位符不接受表达式
- **现象**：Flutter html template 里 `${props.disabled ? 'null' : '() {}'}` 报 `Expected a call expression … got ConditionalExpression`。
- **根因**：html template 的 `${…}` 占位符只接受 prop **值引用**，不接受三元 / 运算等表达式。
- **防范**：分支 / 可选逻辑全部用 `figma.enum` 的 value mapping 表达——把整值（含注释、整行）映射进 enum，占位符只引用 prop。例：State→onPressed（`'() {}'` / `'null, // 禁用'`）、Icon→leadingIcon（整行 / 空串）。

### D5. Code Connect：Flutter 标签 + React include
- **现象**：① Flutter 发布后 Dev Mode 标签是「Web Components」而非「Flutter」；② React 发布报 `Import for <组件> could not be resolved` warning。
- **根因**：① html parser 默认 label「Web Components」；② `include` 只匹配 `*.figma.tsx`（Code Connect 文件），未含组件源，import 解析不全。
- **防范**：① Flutter 发布加 `--label Flutter`；换标签后旧标签会残留，先 `unpublish --config <html> --label "<旧>"` 清除。② React `include` 扩到含组件源（如 `src/**/*.tsx`，不只 `*.figma.tsx`）。

### D6. Code Connect：Flutter 片段须符合 dart format
- **现象**：Flutter html template 是手写字符串拼接（缩进、trailing comma、inline 注释位置易跑偏），Dev Mode 直接展示给开发者复制。
- **防范**：发布前把各组合渲染片段写入临时 `.dart` 文件跑 `fvm dart format`——**`0 changed` 即达标**（2 空格缩进、参数 trailing comma、注释位置合规）；也可 `figma connect preview --config <html>` 看实际渲染。Button 四组合（enabled/disabled × 无图标/前置图标）已校验通过。

### D7. Code Connect：html template 无 source（View connection 跳不动），用 links 弥补
- **现象**：Flutter（html parser）在 Dev Mode 的「View connection」跳不动；React 正常。parse 看 React `source` 有值、Flutter `source` 为空。
- **根因**：`figma.connect` 的输入 options（`FigmaConnectMeta`）**没有 `source` 字段**——source 由 CLI 从组件 `import` 自动推断；html template 第一参数是 URL 字符串、无组件 import，CLI 推断不出，source 永远空。改配置无解。
- **防范**：用 options 的 `links: [{ name, url }]` 显式加一个跳到组件源码的链接（如 Flutter → `lib/ui/components/button.dart` 的 GitHub blob URL），在 Dev Mode 与片段一起显示、可点。React 的 source 仍自动（前提：仓库有 remote + 已 push + 再 publish）。

---

## E. 流程

### E1. 改名 / 重构后未全量验证
- **防范**：`fvm flutter test` 全量编译整个 lib，是「无破坏」的硬证据；`analyze` 聚焦改动文件确认 0 警告。

### E2. 提交边界
- **现象**：设计系统改动与用户进行中工作混在工作区。
- **防范**：只 `git add` 自己的文件路径；绝不碰他人进行中文件（core.go / 订阅 / 日志 / p1-* 等）。提交仅在用户明确要求时。

---

## 维护

踩新坑 → 即时追加（现象 → 根因 → 防范）。关联：`code-review-checklist.md`（通用六类）、`component-dev-guide.md`（流程 SOP）、`component-gate.md`（门禁）。
