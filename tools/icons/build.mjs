// 图标库 pipeline：读 icons.json + source/*.svg → 三端生成物。
// Web 已实现；Flutter IconFont（stroke→outline + font）待实现（见底部 TODO）。
import { readFileSync, writeFileSync, mkdirSync } from 'node:fs';
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

// === Flutter: TongtuIcons.ttf + tongtu_icons.g.dart ===
// TODO（阶段4）：Lucide 是描边 SVG，IconFont 字形需填充路径——
//   ① stroke→outline（svg-outline-stroke 等）② SVG→font（svgtofont / fantasticon）
//   ③ 生成 lib/ui/icons/TongtuIcons.ttf + tongtu_icons.g.dart（codepoint 同 icons.json）。
console.log('… Flutter IconFont 待实现（阶段 4）');
