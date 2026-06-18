#!/usr/bin/env bash
# 构建 BundleMRS.7z（p1-geo-mrs-conversion）：拉 metacubex meta-rules-dat 的 geosite + geoip
# mrs 全集，按 geosite/<名>.mrs、geoip/<名>.mrs 组织打成 7z，供 iOS app 预置。
# 主 app 首启把它拷到内核 home-dir（App Group），内核 rule-provider 经 path-in-bundle 从中按需取，
# 实现 geo 规则首连零网络必达（mihomo 官方 BundleMRS 机制）。
# 前置：git、7z（brew install p7zip）。
set -euo pipefail

REPO="https://github.com/MetaCubeX/meta-rules-dat.git"
BRANCH="meta"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="${1:-$ROOT/ios/Runner/Resources/BundleMRS.7z}"

command -v git >/dev/null || { echo "❌ 需要 git"; exit 1; }
command -v 7z >/dev/null || { echo "❌ 需要 7z（brew install p7zip）"; exit 1; }

WORK="$(mktemp -d)"
trap 'rm -rf "$WORK"' EXIT

echo "▶ [1/4] sparse clone $BRANCH 分支 geo/*.mrs ..."
# 仅静默 stdout、保留 stderr 以便排障（网络/分支/磁盘错误可见，对齐 build-xcframework.sh 风格）。
# --no-cone 为 deprecated 但功能正常（只拉 *.mrs 省带宽，全集约 12.6MB）；将来 git 若移除该模式，
# 可改回 cone：`git -C ... sparse-checkout set geo/geosite geo/geoip`（拉全目录约 188MB，仍只打包 *.mrs）。
git clone --depth 1 --branch "$BRANCH" --filter=blob:none --no-checkout "$REPO" "$WORK/mrd" >/dev/null
git -C "$WORK/mrd" sparse-checkout set --no-cone '/geo/geosite/*.mrs' '/geo/geoip/*.mrs' >/dev/null
git -C "$WORK/mrd" checkout >/dev/null

echo "▶ [2/4] 组织 bundle 结构（geosite/ geoip/）..."
mkdir -p "$WORK/bundle/geosite" "$WORK/bundle/geoip"
cp "$WORK/mrd"/geo/geosite/*.mrs "$WORK/bundle/geosite/"
cp "$WORK/mrd"/geo/geoip/*.mrs "$WORK/bundle/geoip/"
gs=$(find "$WORK/bundle/geosite" -name '*.mrs' | wc -l | tr -d ' ')
gi=$(find "$WORK/bundle/geoip" -name '*.mrs' | wc -l | tr -d ' ')
echo "  geosite=$gs geoip=$gi"
{ [ "$gs" -gt 1000 ] && [ "$gi" -gt 100 ]; } || { echo "❌ mrs 数量异常（geosite=$gs geoip=$gi）"; exit 1; }

echo "▶ [3/4] 校验 mrs magic（外层 zstd 28b52ffd）..."
for f in "$WORK/bundle/geosite/google.mrs" "$WORK/bundle/geoip/cn.mrs"; do
	m=$(xxd -p -l4 "$f" 2>/dev/null)
	[ "$m" = "28b52ffd" ] || { echo "❌ $f magic=$m 非 zstd mrs"; exit 1; }
done
echo "  ✅ magic 校验通过"

echo "▶ [4/4] 7z 打包 → $OUT ..."
mkdir -p "$(dirname "$OUT")"
rm -f "$OUT"
(cd "$WORK/bundle" && 7z a -t7z -mx=9 -bso0 -bsp0 "$OUT" geosite geoip >/dev/null)
echo "  ✅ $(du -h "$OUT" | cut -f1)  $OUT"
