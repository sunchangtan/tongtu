// 构建编排：用 SD v4 Node API 解析浅/深两套 DTCG，调自写 format 合并产出 Flutter + CSS。
// 明暗各解析一次（SD 一次 build 只出一组），再由 format 合并为单一产物（见 design D2）。
import StyleDictionary from 'style-dictionary';
import { promises as fs } from 'node:fs';
import { execSync } from 'node:child_process';
import path from 'node:path';
import { fileURLToPath } from 'node:url';
import { toDart } from './format/flutter.mjs';
import { toCss } from './format/css.mjs';
import { toFlutterTypography, toCssTypography } from './format/typography.mjs';
import { toTs } from './format/ts.mjs';

const dirname = path.dirname(fileURLToPath(import.meta.url));
const ROOT = path.resolve(dirname, '../..');
const TOK = path.join(ROOT, 'tokens');

// 输入组合：ref + 对应明/暗语义色 + 维度（见 design §5）
async function resolveTokens(colorFile) {
  const sd = new StyleDictionary({
    source: [
      path.join(TOK, 'ref.json'),
      path.join(TOK, colorFile),
      path.join(TOK, 'sys.dimension.json'),
    ],
    usesDtcg: true,
    platforms: { noop: { transforms: [] } },
    log: { verbosity: 'silent' },
  });
  await sd.hasInitialized;
  const dict = await sd.getPlatformTokens('noop');
  return dict.allTokens;
}

// typography 单独解析（composite token，独立于颜色/维度）
async function resolveTypography() {
  const sd = new StyleDictionary({
    source: [path.join(TOK, 'typography.json')],
    usesDtcg: true,
    platforms: { noop: { transforms: [] } },
    log: { verbosity: 'silent' },
  });
  await sd.hasInitialized;
  const dict = await sd.getPlatformTokens('noop');
  return dict.allTokens;
}

const lightTokens = await resolveTokens('sys.color.light.json');
const darkTokens = await resolveTokens('sys.color.dark.json');
const typoTokens = await resolveTypography();

const dartPath = path.join(ROOT, 'lib/ui/tokens/tokens.g.dart');
const cssPath = path.join(ROOT, 'web/tokens/tokens.css');
const typoDartPath = path.join(ROOT, 'lib/ui/tokens/typography.g.dart');
const typoCssPath = path.join(ROOT, 'web/tokens/typography.css');

await fs.mkdir(path.dirname(dartPath), { recursive: true });
await fs.mkdir(path.dirname(cssPath), { recursive: true });
await fs.writeFile(dartPath, toDart({ lightTokens, darkTokens }));
await fs.writeFile(cssPath, toCss({ lightTokens, darkTokens }));
await fs.writeFile(typoDartPath, toFlutterTypography(typoTokens));
await fs.writeFile(typoCssPath, toCssTypography(typoTokens));
await fs.writeFile(path.join(ROOT, 'web/tokens/tokens.ts'), toTs({ lightTokens, darkTokens }));

// 用 dart format 规范化生成的 Flutter 文件（typography 的 TextStyle 行较长，需换行）
try {
  execSync(`fvm dart format "${dartPath}" "${typoDartPath}"`, { cwd: ROOT, stdio: 'pipe' });
} catch (e) {
  console.warn('⚠ dart format 跳过（fvm/dart 不在 PATH，请手动 fvm dart format lib/ui/tokens/）');
}

const nColor = lightTokens.filter((t) => t.path[1] === 'color').length;
const nDim = lightTokens.filter((t) => t.path[1] === 'ui').length;
const nTypo = typoTokens.filter((t) => t.path[0] === 'type').length;
console.log(`✓ 颜色 ${nColor}×明暗 / 维度 ${nDim} → tokens.g.dart + tokens.css`);
console.log(`✓ typography ${nTypo} 档 → typography.g.dart + typography.css`);
console.log('✓ web JS token → web/tokens/tokens.ts');
