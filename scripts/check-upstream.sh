#!/usr/bin/env bash
# 校验 core-bridge 依赖来源：mihomo 必须来自官方仓库（项目 CLAUDE.md 技术红线）
# 用法：scripts/check-upstream.sh（任意目录均可），CI 与 pre-commit 中调用
set -euo pipefail
cd "$(dirname "$0")/.."
GOMOD=core-bridge/go.mod

# 1. 必须依赖官方 module 并锁定具体版本
if ! grep -Eq 'github\.com/metacubex/mihomo v[0-9]' "$GOMOD"; then
    echo "❌ ${GOMOD} 缺少官方 mihomo 依赖（github.com/metacubex/mihomo vX.Y.Z）"
    exit 1
fi

# 2. 不允许未标注补丁说明的 mihomo replace（临时补丁须以「// 补丁:」注释指向补丁文件）
if grep -E '^replace[[:space:]].*mihomo' "$GOMOD" | grep -v '// 补丁:'; then
    echo "❌ 检测到指向非官方仓库的 mihomo replace，且未标注补丁说明（// 补丁: <路径>）"
    exit 1
fi

echo "✅ 内核依赖来源校验通过：官方 github.com/metacubex/mihomo（$(grep -Eo 'mihomo v[0-9][^ ]*' "$GOMOD" | head -1)）"
