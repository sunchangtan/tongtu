// 自写 TS format：生成 web JS token（供 React MUI createTheme 消费，与 Flutter/CSS 同源同值）。

const dval = (t) => t.$value ?? t.value;
const isColor = (t) => t.path[0] === 'sys' && t.path[1] === 'color';
const isDim = (t) => t.path[0] === 'sys' && t.path[1] === 'ui';
function kebabToCamel(s) {
  return s.replace(/-([a-z0-9])/g, (_, c) => c.toUpperCase());
}
const colorName = (t) => kebabToCamel(t.path.slice(2).join('-'));
const dimName = (t) => kebabToCamel(`${t.path[2]}-${t.path[3]}`);

function objLiteral(entries) {
  return `{\n${entries.map(([k, v]) => `  ${k}: ${v},`).join('\n')}\n}`;
}

export function toTs({ lightTokens, darkTokens }) {
  const cl = lightTokens.filter(isColor).map((t) => [colorName(t), `'${dval(t)}'`]);
  const cd = darkTokens.filter(isColor).map((t) => [colorName(t), `'${dval(t)}'`]);
  const dm = lightTokens.filter(isDim).map((t) => [dimName(t), parseFloat(dval(t))]);
  return `${[
    '// GENERATED — DO NOT EDIT. 由 tokens/*.json 生成（node build.mjs），与 Flutter/CSS 同源。',
    `export const colorsLight = ${objLiteral(cl)} as const;`,
    '',
    `export const colorsDark = ${objLiteral(cd)} as const;`,
    '',
    `export const dims = ${objLiteral(dm)} as const;`,
  ].join('\n')}\n`;
}
