// 自写 Flutter format：把解析后的明/暗语义色 + 维度合并为单个 tokens.g.dart。
// 不在此拼 ColorScheme（拼装在 app_theme，见 design D3）。

const isColor = (t) => t.path[0] === 'sys' && t.path[1] === 'color';
const isDim = (t) => t.path[0] === 'sys' && t.path[1] === 'ui';
const dval = (t) => t.$value ?? t.value;

function kebabToCamel(s) {
  return s.replace(/-([a-z0-9])/g, (_, c) => c.toUpperCase());
}
// 颜色常量名：sys/color/on-primary → onPrimary
function colorName(t) {
  return kebabToCamel(t.path.slice(2).join('-'));
}
// 维度常量名：sys/ui/space/md → spaceMd；sys/ui/radius/full → radiusFull
function dimName(t) {
  return kebabToCamel(t.path[2] + '-' + t.path[3]);
}
// #rrggbb / #rrggbbaa → Color(0xAARRGGBB)
function dartColor(hex) {
  const h = hex.replace('#', '');
  let rr, gg, bb;
  let aa = 'ff';
  if (h.length === 8) {
    rr = h.slice(0, 2); gg = h.slice(2, 4); bb = h.slice(4, 6); aa = h.slice(6, 8);
  } else {
    rr = h.slice(0, 2); gg = h.slice(2, 4); bb = h.slice(4, 6);
  }
  return `Color(0x${(aa + rr + gg + bb).toUpperCase()})`;
}
// "12px" → 12.0
function dartDouble(v) {
  const n = parseFloat(String(v));
  return Number.isInteger(n) ? n.toFixed(1) : String(n);
}

function colorClass(className, doc, tokens) {
  const lines = tokens
    .filter(isColor)
    .map((t) => `  static const ${colorName(t)} = ${dartColor(dval(t))};`);
  return `/// ${doc}\nclass ${className} {\n  ${className}._();\n\n${lines.join('\n')}\n}`;
}

function dimClass(tokens) {
  const lines = tokens
    .filter(isDim)
    .map((t) => `  static const ${dimName(t)} = ${dartDouble(dval(t))};`);
  return `/// UI 维度（sys/ui：间距 / 圆角 / 字号；无明暗）\nclass TongtuDimens {\n  TongtuDimens._();\n\n${lines.join('\n')}\n}`;
}

export function toDart({ lightTokens, darkTokens }) {
  const header = [
    '// GENERATED — DO NOT EDIT.',
    '// 由 tools/style-dictionary 从 tokens/*.json 生成（node build.mjs）。',
    '// 改值请改 Figma 变量 → 重新导出 DTCG → 重新生成。',
    '',
    "import 'dart:ui';",
    '',
  ].join('\n');
  return `${[
    header,
    colorClass('TongtuSysColorsLight', '浅色语义色（sys.color.light + ref）', lightTokens),
    '',
    colorClass('TongtuSysColorsDark', '深色语义色（sys.color.dark + ref）', darkTokens),
    '',
    dimClass(lightTokens),
  ].join('\n')}\n`;
}
