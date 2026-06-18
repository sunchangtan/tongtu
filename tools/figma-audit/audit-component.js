// ============================================================
// Figma 组件 token 绑定审计门禁（design-components 能力）
//
// 用法：agent 用 Figma MCP `use_figma` 执行本文件内容（figma 全局环境，非 node）；
//       先把 COMPONENT_SET_ID 换成目标组件的 Component Set id。
// 通过判据：返回「✅ 审计通过：0 未绑」。
// 豁免：仅 padding=0（无内距）。disabled 用带 alpha 的独立 disabled 语义色变量
//       （sys/color/disabled-*，α 烤进变量值，绑 color 时 Figma 自动 opacity=α）全绑，不再豁免。
// 注：strokeWeight 绑后展开为 strokeTopWeight/Bottom/Left/Right，故查 strokeTopWeight。
// ============================================================
const COMPONENT_SET_ID = '132:52'; // ← A3 换成目标组件的 Component Set id

const set = await figma.getNodeByIdAsync(COMPONENT_SET_ID);
function hex(c) {
  const h = (n) => Math.round(n * 255).toString(16).padStart(2, '0');
  return '#' + h(c.r) + h(c.g) + h(c.b);
}
const violations = [];
function checkPaints(comp, label, paints) {
  if (!Array.isArray(paints)) return;
  for (const p of paints) {
    if (p.type !== 'SOLID') continue;
    if (p.boundVariables && p.boundVariables.color) continue;
    violations.push(`${comp.name} / ${label} 未绑 ${hex(p.color)}`);
  }
}
const children = set.type === 'COMPONENT_SET' ? set.children : [set];
for (const c of children) {
  const bv = c.boundVariables || {};
  checkPaints(c, '容器', c.fills);
  if (c.strokes && c.strokes.length) {
    checkPaints(c, '描边', c.strokes);
    if (!bv.strokeTopWeight) violations.push(`${c.name} strokeWeight 未绑`);
  }
  if ('topLeftRadius' in c && !bv.topLeftRadius) violations.push(`${c.name} radius 未绑`);
  for (const f of ['paddingLeft', 'paddingRight', 'paddingTop', 'paddingBottom']) {
    if (c[f] > 0 && !bv[f]) violations.push(`${c.name} ${f}(${c[f]}) 未绑`);
  }
  if (c.itemSpacing > 0 && !bv.itemSpacing) violations.push(`${c.name} itemSpacing 未绑`);
  if ('height' in c && c.layoutMode && c.counterAxisSizingMode === 'FIXED' && !bv.height) {
    violations.push(`${c.name} height 未绑`);
  }
  for (const ch of c.children || []) {
    checkPaints(c, ch.type === 'TEXT' ? '文字' : '图标', ch.fills);
    if (ch.type === 'ELLIPSE' || ch.type === 'INSTANCE') {
      const cb = ch.boundVariables || {};
      if (!cb.width || !cb.height) violations.push(`${c.name} 图标尺寸 未绑`);
    }
  }
}
return violations.length === 0
  ? '✅ 审计通过：0 未绑（仅 padding=0 豁免）'
  : `❌ ${violations.length} 未绑:\n` + violations.slice(0, 20).join('\n');
