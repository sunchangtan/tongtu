// 自写 CSS format：把解析后的明/暗语义色合并为 :root + [data-theme=dark]；维度/comp 在 :root。

const isColor = (t) => t.path[0] === 'sys' && t.path[1] === 'color';
const isDim = (t) => t.path[0] === 'sys' && t.path[1] === 'ui';
const isComp = (t) => t.path[0] === 'comp';
const dval = (t) => t.$value ?? t.value;
const cssVar = (t) => `--${t.path.join('-')}`;

export function toCss({ lightTokens, darkTokens }) {
  const colorLines = (tk) => tk.filter(isColor).map((t) => `  ${cssVar(t)}: ${dval(t)};`);
  const dimLines = (tk) => tk.filter(isDim).map((t) => `  ${cssVar(t)}: ${dval(t)};`);
  const compLines = (tk) => tk.filter(isComp).map((t) => `  ${cssVar(t)}: ${dval(t)};`);
  return `${[
    '/* GENERATED — DO NOT EDIT. 由 tokens/*.json 经 tools/style-dictionary 生成。 */',
    ':root {',
    ...colorLines(lightTokens),
    ...dimLines(lightTokens),
    ...compLines(lightTokens),
    '}',
    '',
    '[data-theme="dark"] {',
    ...colorLines(darkTokens),
    '}',
  ].join('\n')}\n`;
}
