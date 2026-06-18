// 自写 CSS format：明/暗语义色 → :root + [data-theme=dark]；维度与 comp 尺寸在 :root，comp 颜色随明暗。

const isColor = (t) => t.path[0] === 'sys' && t.path[1] === 'color';
const isDim = (t) => t.path[0] === 'sys' && t.path[1] === 'ui';
const isComp = (t) => t.path[0] === 'comp';
const isCompColor = (t) => isComp(t) && t.$type === 'color';
const isCompDim = (t) => isComp(t) && t.$type === 'dimension';
const dval = (t) => t.$value ?? t.value;
const cssVar = (t) => `--${t.path.join('-')}`;

export function toCss({ lightTokens, darkTokens }) {
  const colorLines = (tk) => tk.filter(isColor).map((t) => `  ${cssVar(t)}: ${dval(t)};`);
  const dimLines = (tk) => tk.filter(isDim).map((t) => `  ${cssVar(t)}: ${dval(t)};`);
  const compDimLines = (tk) => tk.filter(isCompDim).map((t) => `  ${cssVar(t)}: ${dval(t)};`);
  const compColorLines = (tk) => tk.filter(isCompColor).map((t) => `  ${cssVar(t)}: ${dval(t)};`);
  return `${[
    '/* GENERATED — DO NOT EDIT. 由 tokens/*.json 经 tools/style-dictionary 生成。 */',
    ':root {',
    ...colorLines(lightTokens),
    ...dimLines(lightTokens),
    ...compDimLines(lightTokens),
    ...compColorLines(lightTokens),
    '}',
    '',
    '[data-theme="dark"] {',
    ...colorLines(darkTokens),
    ...compColorLines(darkTokens),
    '}',
  ].join('\n')}\n`;
}
