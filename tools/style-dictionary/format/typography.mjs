// 自写 typography format：DTCG typography composite → Flutter TextTheme + CSS utility classes。
// type scale 值字体无关；fontFamily 取 token 记录值（M3 默认 Roboto），各端可在主题层统一覆盖。

const dval = (t) => t.$value ?? t.value;
const isTypo = (t) => t.path[0] === 'type';

function kebabToCamel(s) {
  return s.replace(/-([a-z0-9])/g, (_, c) => c.toUpperCase());
}
// path ['type','display','large'] → Flutter TextTheme 角色名 'displayLarge'
function roleName(t) {
  return kebabToCamel(t.path.slice(1).join('-'));
}
const px = (v) => parseFloat(String(v));

export function toFlutterTypography(tokens) {
  const typo = tokens.filter(isTypo);
  const entries = typo.map((t) => {
    const v = dval(t);
    const size = px(v.fontSize);
    const lh = px(v.lineHeight);
    const ls = px(v.letterSpacing);
    const height = lh && size ? lh / size : null;
    const parts = [
      `fontFamily: '${v.fontFamily}'`,
      `fontSize: ${size.toFixed(1)}`,
      `fontWeight: FontWeight.w${v.fontWeight}`,
      height != null ? `height: ${height.toFixed(4)}` : null,
      `letterSpacing: ${ls.toFixed(2)}`,
    ].filter(Boolean);
    return `  ${roleName(t)}: TextStyle(${parts.join(', ')}),`;
  });
  return `${[
    '// GENERATED — DO NOT EDIT. 由 tokens/typography.json 生成（node build.mjs）。',
    '// M3 type scale；fontFamily 为默认基线，可在 ThemeData 统一覆盖。',
    '',
    "import 'package:flutter/material.dart';",
    '',
    '/// M3 type scale TextTheme（接入 ThemeData.textTheme）。',
    'const TextTheme tongtuTextTheme = TextTheme(',
    entries.join('\n'),
    ');',
  ].join('\n')}\n`;
}

export function toCssTypography(tokens) {
  const typo = tokens.filter(isTypo);
  const blocks = typo.map((t) => {
    const v = dval(t);
    const cls = `.type-${t.path.slice(1).join('-')}`;
    return [
      `${cls} {`,
      `  font-family: ${v.fontFamily};`,
      `  font-weight: ${v.fontWeight};`,
      `  font-size: ${v.fontSize};`,
      `  line-height: ${v.lineHeight};`,
      `  letter-spacing: ${v.letterSpacing};`,
      '}',
    ].join('\n');
  });
  return `${['/* GENERATED — DO NOT EDIT. 由 tokens/typography.json 生成。 */', ...blocks].join('\n\n')}\n`;
}
