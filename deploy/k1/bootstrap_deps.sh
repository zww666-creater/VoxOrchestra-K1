#!/usr/bin/env bash
# 无 sudo 权限时，在用户目录编译安装 K1 构建依赖。
set -euo pipefail

PREFIX=${VOXORCHESTRA_K1_PREFIX:-$HOME/.local/voxorchestra-k1}
CACHE_ROOT=${VOXORCHESTRA_K1_DEPS_CACHE:-${XDG_CACHE_HOME:-$HOME/.cache}/voxorchestra-k1-deps}
JOBS=${VOXORCHESTRA_BUILD_JOBS:-$(nproc)}

if ! [[ "$JOBS" =~ ^[1-9][0-9]*$ ]]; then
  echo "VOXORCHESTRA_BUILD_JOBS 必须是正整数" >&2
  exit 2
fi
if [ "$JOBS" -gt 4 ]; then
  JOBS=4
fi

for cmd in git cmake g++; do
  command -v "$cmd" >/dev/null 2>&1 || {
    echo "缺少 $cmd，无法进行无 root 依赖构建" >&2
    exit 1
  }
done

mkdir -p "$PREFIX" "$CACHE_ROOT"

checkout_tag() {
  local url=$1
  local tag=$2
  local dir=$3
  if [ ! -d "$dir/.git" ]; then
    git clone --depth 1 --branch "$tag" "$url" "$dir"
  else
    git -C "$dir" fetch --depth 1 origin "refs/tags/$tag:refs/tags/$tag"
    git -C "$dir" checkout --detach "$tag"
  fi
}

checkout_tag https://github.com/zeromq/libzmq.git v4.3.5 "$CACHE_ROOT/libzmq"
cmake -S "$CACHE_ROOT/libzmq" -B "$CACHE_ROOT/build-libzmq" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_SHARED=ON \
  -DBUILD_STATIC=OFF \
  -DBUILD_TESTS=OFF \
  -DWITH_DOCS=OFF \
  -DWITH_LIBSODIUM=OFF
cmake --build "$CACHE_ROOT/build-libzmq" -j"$JOBS"
cmake --install "$CACHE_ROOT/build-libzmq"

export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/lib64/pkgconfig${PKG_CONFIG_PATH:+:$PKG_CONFIG_PATH}"
export CMAKE_PREFIX_PATH="$PREFIX${CMAKE_PREFIX_PATH:+:$CMAKE_PREFIX_PATH}"
export LD_LIBRARY_PATH="$PREFIX/lib:$PREFIX/lib64${LD_LIBRARY_PATH:+:$LD_LIBRARY_PATH}"

checkout_tag https://github.com/zeromq/cppzmq.git v4.10.0 "$CACHE_ROOT/cppzmq"
cmake -S "$CACHE_ROOT/cppzmq" -B "$CACHE_ROOT/build-cppzmq" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DCMAKE_PREFIX_PATH="$PREFIX" \
  -DCPPZMQ_BUILD_TESTS=OFF
cmake --build "$CACHE_ROOT/build-cppzmq" -j"$JOBS"
cmake --install "$CACHE_ROOT/build-cppzmq"

checkout_tag https://github.com/nlohmann/json.git v3.11.3 "$CACHE_ROOT/json"
cmake -S "$CACHE_ROOT/json" -B "$CACHE_ROOT/build-json" \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DJSON_BuildTests=OFF \
  -DJSON_Install=ON
cmake --build "$CACHE_ROOT/build-json" -j"$JOBS"
cmake --install "$CACHE_ROOT/build-json"

cat >"$PREFIX/env.sh" <<EOF
# shellcheck shell=bash
export VOXORCHESTRA_K1_PREFIX="$PREFIX"
export PATH="$PREFIX/bin:\${PATH}"
export PKG_CONFIG_PATH="$PREFIX/lib/pkgconfig:$PREFIX/lib64/pkgconfig\${PKG_CONFIG_PATH:+:\$PKG_CONFIG_PATH}"
export CMAKE_PREFIX_PATH="$PREFIX\${CMAKE_PREFIX_PATH:+:\$CMAKE_PREFIX_PATH}"
export LD_LIBRARY_PATH="$PREFIX/lib:$PREFIX/lib64\${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
EOF

test -r "$PREFIX/include/zmq.h"
test -r "$PREFIX/include/zmq.hpp"
test -r "$PREFIX/include/nlohmann/json.hpp"
pkg-config --exists libzmq

echo "K1 用户态依赖已安装到 $PREFIX"
echo "继续执行: source '$PREFIX/env.sh' && deploy/k1/build.sh"
