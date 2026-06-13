#!/usr/bin/env bash
# 构建 MihomoCore.xcframework（任务 3.1）
# 切片：iOS(arm64) / iOS Simulator(arm64) / macOS(arm64+x86_64)
# 产物：build/MihomoCore.xcframework
# 前置：Xcode、Go（go.mod toolchain 自动匹配）、gomobile（go.mod tool 指令固化）
set -euo pipefail
cd "$(dirname "$0")/../core-bridge"

OUT_DIR=../build
mkdir -p "$OUT_DIR"

echo "▶ gomobile bind（iOS 最低 15.0，剥离符号表与调试信息以控制体积）"
# -tags with_gvisor：iOS NE 必须用 gvisor 用户态栈（system 栈无法 bind tun 地址），
#   不带此 tag 内核报 "gvisor not included in this build"（问题 8，官方 Makefile 同法）
go tool gomobile bind \
    -target=ios,iossimulator,macos \
    -iosversion=15.0 \
    -tags with_gvisor \
    -trimpath \
    -ldflags="-s -w" \
    -o "$OUT_DIR/MihomoCore.xcframework" \
    ./mihomocore

echo "▶ 校验产物切片（spec：干净环境一键构建；LC_UUID 在链接产物 ios-poc 上校验）"
for bin in "$OUT_DIR"/MihomoCore.xcframework/*/MihomoCore.framework/MihomoCore; do
    echo "--- $bin"
    file "$bin" | grep -q "ar archive" || { echo "❌ 非静态库归档: $bin"; exit 1; }
    lipo -archs "$bin"
done
# 三个平台切片目录必须齐备
for slice in ios-arm64 ios-arm64_x86_64-simulator macos-arm64_x86_64; do
    [ -d "$OUT_DIR/MihomoCore.xcframework/$slice" ] || { echo "❌ 缺少切片: $slice"; exit 1; }
done

echo "▶ 产物体积（design 待解问题 2：记录二进制体积）"
du -sh "$OUT_DIR/MihomoCore.xcframework"/*/MihomoCore.framework

echo "✅ xcframework 构建完成: $OUT_DIR/MihomoCore.xcframework"
