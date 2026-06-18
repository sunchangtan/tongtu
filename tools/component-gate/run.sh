#!/usr/bin/env bash
# 组件门禁 runner：跑命令行可自动化的门禁项（build / Flutter / Web）。
# Figma 绑定审计经 use_figma 执行（见 docs/guidelines/component-gate.md），不在此脚本。
set -uo pipefail
cd "$(dirname "$0")/../.." || exit 2

fail=0
step() { echo ""; echo "━━━ $1 ━━━"; }
ok() { echo "✓ $1"; }
ng() { echo "✗ $1"; fail=1; }

step "① token 管线 build"
if node tools/style-dictionary/build.mjs; then ok "build"; else ng "build"; fi

step "② Flutter analyze（组件库代码：components / app_theme / tokens）"
if fvm flutter analyze lib/ui/components lib/ui/app_theme.dart lib/ui/tokens; then ok "analyze 0 警告"; else ng "analyze"; fi

step "③ Flutter test（全量，证无破坏）"
if fvm flutter test; then ok "test 全绿"; else ng "test"; fi

step "④ Web tsc + vite build"
if npm --prefix web run build; then ok "web build"; else ng "web build"; fi

echo ""
if [ "$fail" -eq 0 ]; then
  echo "✅ 命令行门禁全绿。"
  echo "   下一步（半自动 / 人工）："
  echo "   · 经 use_figma 跑 tools/figma-audit/audit-component.js → 0 未绑"
  echo "   · 对照 docs/guidelines/component-gate.md §C 人工清单"
else
  echo "❌ 有门禁项失败，见上。"
fi
exit "$fail"
