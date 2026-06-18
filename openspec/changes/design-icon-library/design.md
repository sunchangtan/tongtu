## Context

现状：Flutter 28 种 Material 字体图标、web 几无图标、无统一图标资产；设计系统已三端同步 token / 组件 / logo，独缺图标同源。

brainstorming 五决策：三端同步 / 统一 SVG 源 pipeline / Lucide / 现用+扩展 ~60-80 / Flutter IconFont。

## Goals / Non-Goals

**Goals:**
- 三端一份 SVG 源，加图标只改「源 + 清单」、跑 build 三端联动。
- Flutter 用法接近现有（`Icon(TongtuIcons.x)` ← `Icons.x`），28 处平滑替换、字体渲染内存友好。
- Web 经 `@tongtu/icons` 包消费；Figma 设计稿可拖用图标组件。
- 风格统一（Lucide stroke 圆角，与双 T logo 一致）。

**Non-Goals:**
- 不全量收录 Lucide（YAGNI，~60-80 够用、按需扩展）。
- 不做多 weight / 多色（Lucide 单 stroke 一致即可）。
- 不自设计图标（沿用 Lucide）。
- 不发布 npm（内部 workspace 复用，同 `@tongtu/components`）。

## Decisions

### D1：单一 SVG 源 + 清单驱动 pipeline
`tools/icons/source/*.svg`（Lucide 原始 SVG）为唯一真相源；`icons.json` 清单列每图标 `{name, category, lucide, material, codepoint}`。`build.mjs` 读清单 + SVG → 三端生成物。与 token pipeline（DTCG → Style Dictionary → 三端）同构。

### D2：图标集 Lucide
Lucide（1500+，24×24 / 2px stroke / 圆角端，ISC 许可）。风格与双 T logo（直线圆角线段）一致；三端生态齐（Web / Flutter / Figma）。ISC 兼容 GPL-3.0。

### D3：范围——现用 28 + 常用扩展
收录 Flutter 现用 28 个 Material 图标的 Lucide 等价（映射见 `icons.json` 的 `material` 字段）+ 补 ~30-50 个常见 UI 图标（导航 / 操作 / 状态），共 ~60-80。不全量。

### D4：Flutter IconFont
用 SVG→font 工具（如 `svgtofont` / `fantasticon`）生成 `TongtuIcons.ttf` + `tongtu_icons.g.dart`（`class TongtuIcons { static const IconData search = IconData(0xe001, fontFamily: 'TongtuIcons'); … }`）。`pubspec.yaml` 注册字体。28 处 `Icons.x` → `TongtuIcons.x`（按映射）。字体渲染、内存友好（贴合 iOS NE 内存红线哲学）。

### D5：Web `@tongtu/icons` 包
`web/packages/icons`（`@tongtu/icons`）新 workspace 包；`build.mjs` 生成 React 图标组件（统一 `<Icon name>` 或每图标一 component）。`packages/components` / playground 经 `workspace:*` 消费；playground 加图标总览页。

### D6：Figma「Icons」组件库
用 `use_figma` 把 SVG 源导入 Tongtu Brand 文件，建「Icons」component set（各图标一 component，命名 `Icons/<name>`），归入「Components」区。

### D7：目录结构
```
tools/icons/
  source/*.svg          # Lucide SVG 源（~60-80）
  icons.json            # 清单：{name, category, lucide, material, codepoint}
  build.mjs             # pipeline → 三端
lib/ui/icons/
  TongtuIcons.ttf       # 生成·图标字体
  tongtu_icons.g.dart   # 生成·TongtuIcons IconData
web/packages/icons/     # @tongtu/icons（生成 React 组件）
  src/, package.json, tsconfig.json
```

## Risks / Trade-offs

| 风险 | 应对 |
|------|------|
| Material→Lucide 个别无完美等价 | 清单逐个核对；无完美对应选最近似 + 备注；必要时极少数保留 Material |
| SVG→font 工具链引入 | 选成熟工具（svgtofont / fantasticon）；生成物入库、可复现 |
| 28 处 Flutter 替换回归 | 按映射表替换；`fvm flutter analyze` / `test` 全量编译；模拟器抽样 |
| codepoint 稳定性 | 清单固定 `name → codepoint`，增量加图标不改既有 codepoint |
| Web 新包 monorepo 集成 | 同 `@tongtu/components` 模式；`pnpm install` + playground 验证 |

## Migration Plan

1. 选定图标集（28 映射 + 扩展），写 `icons.json` + 备齐 `source/*.svg`。
2. `build.mjs` 骨架（读清单 + SVG，规范化）。
3. Flutter：生成 font + IconData，注册 pubspec，替换 28 处，验证。
4. Web：生成 `@tongtu/icons`，playground 展示，验证。
5. Figma：导入建 Icons 组件库。

**回滚**：图标库为新增；Flutter 替换可 git 还原回 `Icons.*`。
