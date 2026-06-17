# 通途跨栈 Token 同步（Style Dictionary）

以 Figma 变量为单一真相源，生成 Flutter 与 CSS 的设计 token。
设计见 `openspec/changes/design-token-sync` 与 `docs/design/token-sync-design.md`。

## 管线

```
Figma 变量
  → tokens/*.json          DTCG，单一真相源（提交 git）
  → build.mjs              Style Dictionary v4（usesDtcg），解析明/暗两套
  → lib/ui/tokens/tokens.g.dart    Flutter：明暗语义色常量 + 维度常量
  + web/tokens/tokens.css          CSS：:root + [data-theme=dark]
```

## 同步流程

1. **导出**（Figma 改了变量后）：由 agent 用 Figma MCP 读变量、序列化为 DTCG，写入 `tokens/`：
   - `ref.json` —— 基础色（实际 hex）
   - `sys.color.light.json` / `sys.color.dark.json` —— 语义色（alias → ref）
   - `sys.dimension.json` —— UI 维度 `sys/ui/*`（px）
2. **生成**：
   ```sh
   cd tools/style-dictionary
   npm install        # 首次
   node build.mjs
   ```
3. **核对**：抽样比对生成值与 Figma；`dart analyze lib/ui/tokens lib/ui/app_theme.dart` 0 警告。
4. **提交**：`tokens/` 与生成物（`tokens.g.dart`、`tokens.css`）一并提交。

## 消费

- **Flutter**：`AppTheme`（`lib/ui/app_theme.dart`）用 `TongtuSysColorsLight/Dark` 拼 `ColorScheme`（`fromSeed` 打底 + `copyWith`）；组件尺寸用 `TongtuDimens`。
- **Web**：引入 `web/tokens/tokens.css`，用 `var(--sys-color-*)` / `var(--sys-ui-*)`；深色容器加 `data-theme="dark"`。接 MUI palette 的映射由 Web 子项目负责。

## 约定

- `tokens.g.dart` / `tokens.css` 是**生成物、勿手改**；改值改 Figma → 重导出 → 重新生成。
- 明暗用 token sets（`sys.color.light/dark`），共享 `ref`；维度无明暗。
- 颜色沿用现有 Figma 变量；UI 维度（`sys/ui/space|radius|font`）参照 Material 3 + 4dp 栅格。
- future：CI 自动化、Figma Variables REST API（需 Enterprise）、字号行高 / 字重。
