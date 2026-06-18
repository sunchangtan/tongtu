## 1. SVG 源 + 图标清单

- [x] 1.1 选定图标集：Flutter 现用 28 个 Material → Lucide 等价映射；补 40 常用 UI 图标（导航 / 操作 / 状态 / 网络 / 设置），共 68
- [x] 1.2 备齐 `tools/icons/source/*.svg`（Lucide 原始 SVG，68 个，lucide-static v1.21.0）
- [x] 1.3 写 `tools/icons/icons.json` 清单（`{name, category, lucide, material, codepoint}`，codepoint e001–e044 固定）

## 2. build pipeline 骨架

- [ ] 2.1 `tools/icons/build.mjs`：读 `icons.json` + `source/*.svg`，规范化（24×24 / viewBox / stroke）
- [ ] 2.2 三端输出框架（Flutter / Web / Figma-ready）+ README 用法说明

## 3. Flutter IconFont

- [ ] 3.1 SVG → `TongtuIcons.ttf`（svgtofont / fantasticon）+ `lib/ui/icons/tongtu_icons.g.dart`（`TongtuIcons` IconData，codepoint 同清单）
- [ ] 3.2 `pubspec.yaml` 注册字体；28 处 `Icons.*` → `TongtuIcons.*`（按映射表）
- [ ] 3.3 验证：`fvm flutter analyze` 0 警告、`fvm flutter test` 全量编译；模拟器抽样图标渲染无误

## 4. Web @tongtu/icons 包

- [ ] 4.1 建 `web/packages/icons`（`@tongtu/icons`）workspace 包；`build.mjs` 生成 React 图标组件
- [ ] 4.2 playground 加图标总览页（网格展示全部图标 + 名）；`pnpm install` / `build` 验证

## 5. Figma Icons 库 + 归档

- [ ] 5.1 `use_figma` 导入 SVG 建「Icons」component set（`Icons/<name>`），归「Components」区
- [ ] 5.2 `openspec validate design-icon-library --strict`；`openspec archive`
