// 图标库 pipeline：读 icons.json + source/*.svg → 三端生成物。
// Web 已实现；Flutter IconFont（stroke→outline + font）待实现（见底部 TODO）。
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
import { execSync } from 'node:child_process';
import { fileURLToPath } from 'node:url';
import path from 'node:path';

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(__dirname, '../..');

const icons = JSON.parse(readFileSync(path.join(__dirname, 'icons.json'), 'utf8'));

// 提取 SVG 的内部内容（去掉 <svg> 外壳，只留 path/circle/... 供组件复用同一套 viewBox/stroke）
function inner(svg) {
  const m = svg.match(/<svg[^>]*>([\s\S]*?)<\/svg>/);
  return m ? m[1].replace(/\s+/g, ' ').trim() : '';
}

const bodies = {};
for (const ic of icons) {
  bodies[ic.name] = inner(readFileSync(path.join(__dirname, 'source', `${ic.name}.svg`), 'utf8'));
}

// === Web: @tongtu/icons（SVG inner → icons-data.ts）===
const webSrc = path.join(ROOT, 'web/packages/icons/src');
mkdirSync(webSrc, { recursive: true });
const dataTs =
  '// GENERATED — DO NOT EDIT. 由 tools/icons/build.mjs 生成（与 Flutter / Figma 同源）。\n' +
  'export const iconsData = {\n' +
  icons.map((ic) => `  ${JSON.stringify(ic.name)}: ${JSON.stringify(bodies[ic.name])},`).join('\n') +
  '\n} as const;\n\n' +
  'export type IconName = keyof typeof iconsData;\n';
writeFileSync(path.join(webSrc, 'icons-data.ts'), dataTs);
console.log(`✓ Web: ${icons.length} 图标 → web/packages/icons/src/icons-data.ts`);

// === Flutter: TongtuIcons.ttf（Lucide 子集字体）+ tongtu_icons.g.dart ===
// Lucide 官方 lucide.ttf 已做好 stroke→outline；这里子集化到 68 个、沿用 Lucide 自有 codepoint。
const lucideTtf = path.join(__dirname, 'node_modules/lucide-static/font/lucide.ttf');
const lucideCp = JSON.parse(
  readFileSync(path.join(__dirname, 'node_modules/lucide-static/font/codepoints.json'), 'utf8'),
);
const flutterDir = path.join(ROOT, 'lib/ui/icons');
mkdirSync(flutterDir, { recursive: true });

const fEntries = icons
  .map((ic) => ({ name: ic.name, cp: lucideCp[ic.name] }))
  .filter((e) => e.cp != null);

// 子集化：只保留这 68 个图标的 unicode
const unicodes = fEntries.map((e) => `U+${e.cp.toString(16).toUpperCase()}`).join(',');
const ttfOut = path.join(flutterDir, 'TongtuIcons.ttf');
execSync(
  `python3 -m fontTools.subset "${lucideTtf}" --unicodes=${unicodes} --output-file="${ttfOut}" --no-layout-closure`,
  { stdio: 'pipe' },
);

// kebab-case → camelCase（Dart 标识符）
const toDart = (n) => n.replace(/-(.)/g, (_, c) => c.toUpperCase());
const dart =
  '// GENERATED — DO NOT EDIT. 由 tools/icons/build.mjs 生成（Lucide 子集字体，与 Web / Figma 同源）。\n' +
  "import 'package:flutter/widgets.dart';\n\n" +
  '/// 通途图标（Lucide 子集 IconFont）。用法：`Icon(TongtuIcons.search)`。\n' +
  '/// 字体注册见 pubspec.yaml（family: TongtuIcons，asset: lib/ui/icons/TongtuIcons.ttf）。\n' +
  'class TongtuIcons {\n' +
  '  TongtuIcons._();\n' +
  "  static const _family = 'TongtuIcons';\n\n" +
  fEntries
    .map((e) => `  static const IconData ${toDart(e.name)} = IconData(0x${e.cp.toString(16)}, fontFamily: _family);`)
    .join('\n') +
  '\n}\n';
writeFileSync(path.join(flutterDir, 'tongtu_icons.g.dart'), dart);
console.log(`✓ Flutter: ${fEntries.length} 图标 → lib/ui/icons/TongtuIcons.ttf + tongtu_icons.g.dart`);
