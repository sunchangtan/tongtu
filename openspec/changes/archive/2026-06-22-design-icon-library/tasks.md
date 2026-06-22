## 1. SVG 源 + 图标清单

- [x] 1.1 选定图标集：Flutter 现用 28 个 Material → Lucide 等价映射；补 40 常用 UI 图标（导航 / 操作 / 状态 / 网络 / 设置），共 68
- [x] 1.2 备齐 `tools/icons/source/*.svg`（Lucide 原始 SVG，68 个，lucide-static v1.21.0）
- [x] 1.3 写 `tools/icons/icons.json` 清单（`{name, category, lucide, material, codepoint}`，codepoint e001–e044 固定）

## 2. Figma 图标库（设计先行）

- [x] 2.1 `use_figma` 把 68 个 SVG 建成 `Icons/<name>` component（Assets 面板按 `/` 自动归 Icons 文件夹），白底 + 墨色描边，wrap 网格排进 Components page 的 Icons 区
- [x] 2.2 截图验证 stroke 线宽 / 风格统一；page 组织理顺为主流「一个 Components page + slash 命名」（Tongtu Brand / Foundations / Components 三 page）；master 改名 `Logo/Mark`，logo instance 跨 page 引用验证完好
- [ ] 2.3（可选后续）图标 stroke 由 hex 墨色改绑 `sys` 墨色变量（随明暗）

## 3. build pipeline 骨架

- [x] 3.1 `tools/icons/build.mjs`：读 `icons.json` + `source/*.svg`，提取 inner → Web `icons-data.ts`
- [x] 3.2 Web 输出已实现（`@tongtu/icons`）；Flutter 输出在 `build.mjs` 留 TODO（见阶段 4，含 stroke→outline）

## 4. Flutter IconFont

- [x] 4.1 子集化 Lucide 官方 `lucide.ttf`（已 outline）→ `TongtuIcons.ttf`（25KB / 71 图标，fonttools）+ `lib/ui/icons/tongtu_icons.g.dart`（`TongtuIcons` IconData，Lucide codepoint）；补 cloud / cloud-off / eraser 覆盖全部用法
- [x] 4.2 `pubspec.yaml` 注册字体（family TongtuIcons）
- [x] 4.2b 替换 49 处 `Icons.*` → `TongtuIcons.*`（13 lib 文件 + import）+ test 同步（6 文件 `find.byIcon`）；补 clipboard/qr-code 覆盖全部用法；映射表 `ICON_MIGRATION.md`
- [x] 4.3 验证：`fvm flutter analyze` 第一方 0 问题、`fvm flutter test` 151 passed

## 5. Web @tongtu/icons 包 + 归档

- [x] 5.1 建 `web/packages/icons`（`@tongtu/icons`）workspace 包：`Icon` 组件（SVG-based）+ `iconsData`；`build.mjs` 生成 `icons-data.ts`
- [x] 5.2 playground 图标总览页（68 图标网格 + 名）；pnpm 类型检查 + preview 渲染验证通过
- [x] 5.3 `openspec validate design-icon-library --strict`；`openspec archive`
