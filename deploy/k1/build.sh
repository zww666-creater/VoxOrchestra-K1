#!/usr/bin/env bash
# SpacemiT K1 / Bianbu Linux 原生构建与回归测试。
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)
BUILD_DIR=${VOXORCHESTRA_BUILD_DIR:-$ROOT/build-k1}
JOBS=${VOXORCHESTRA_BUILD_JOBS:-$(nproc)}

fail() {
  echo "K1 构建失败: $*" >&2
  exit 1
}

for cmd in cmake g++ python3; do
  command -v "$cmd" >/dev/null 2>&1 || fail "缺少 $cmd"
done

if ! [[ "$JOBS" =~ ^[1-9][0-9]*$ ]]; then
  fail "VOXORCHESTRA_BUILD_JOBS 必须是正整数"
fi
# K1 通常内存比桌面机紧张，默认限制并行度，仍可显式设置更小值。
if [ "$JOBS" -gt 4 ]; then
  JOBS=4
fi

ARCH=$(uname -m)
if [ "$ARCH" != riscv64 ] && [ "${VOXORCHESTRA_ALLOW_NON_RISCV:-0}" != 1 ]; then
  fail "当前架构为 $ARCH；K1 原生构建应为 riscv64（CI 可设置 VOXORCHESTRA_ALLOW_NON_RISCV=1）"
fi

if command -v pkg-config >/dev/null 2>&1; then
  pkg-config --exists libzmq || fail "缺少 libzmq 开发包"
fi

cd "$ROOT"
cmake -S . -B "$BUILD_DIR" \
  -DCMAKE_BUILD_TYPE=Release \
  -DVOXORCHESTRA_ENABLE_HARDWARE_BACKENDS=OFF
cmake --build "$BUILD_DIR" -j"$JOBS"
ctest --test-dir "$BUILD_DIR" --output-on-failure
bash scripts/check_no_hw_deps.sh "$BUILD_DIR"

echo "K1 构建与测试完成: $BUILD_DIR"
