#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_DIR="${HUGIN_SOURCE_DIR:-$ROOT_DIR/upstream/hugin}"
BUILD_DIR="${HUGIN_BUILD_DIR:-$ROOT_DIR/build/macos-dev}"
ARCHITECTURE="${HUGIN_ARCHITECTURE:-$(uname -m)}"
DEPLOYMENT_TARGET="${HUGIN_MACOS_DEPLOYMENT_TARGET:-13.0}"
DEPS_PREFIX="${HUGIN_DEPS_PREFIX:-$ROOT_DIR/build/deps/macos-$ARCHITECTURE}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This build entry point supports macOS only." >&2
  exit 1
fi

for tool in cmake ninja; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing required tool: $tool" >&2
    exit 1
  fi
done

if [[ ! -f "$SOURCE_DIR/CMakeLists.txt" ]]; then
  echo "Hugin source not found at $SOURCE_DIR" >&2
  echo "Run ./scripts/import-upstream-snapshot.sh first." >&2
  exit 1
fi

mkdir -p "$BUILD_DIR"

cmake_args=(
  -S "$SOURCE_DIR"
  -B "$BUILD_DIR"
  -G Ninja
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_OSX_ARCHITECTURES="$ARCHITECTURE" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET" \
  -DCMAKE_MACOSX_RPATH=ON
)

cmake_prefix_path="${HUGIN_CMAKE_PREFIX_PATH:-}"
if [[ -d "$DEPS_PREFIX" ]]; then
  if [[ -n "$cmake_prefix_path" ]]; then
    cmake_prefix_path="$DEPS_PREFIX;$cmake_prefix_path"
  else
    cmake_prefix_path="$DEPS_PREFIX"
  fi

  if [[ -f "$DEPS_PREFIX/include/vigra/gaborfilter.hxx" ]]; then
    cmake_args+=(-DVIGRA_INCLUDE_DIR="$DEPS_PREFIX/include")
  fi

  if [[ -f "$DEPS_PREFIX/lib/libvigraimpex.dylib" ]]; then
    cmake_args+=(-DVIGRA_LIBRARIES="$DEPS_PREFIX/lib/libvigraimpex.dylib")
  elif [[ -f "$DEPS_PREFIX/lib/libvigraimpex.a" ]]; then
    cmake_args+=(-DVIGRA_LIBRARIES="$DEPS_PREFIX/lib/libvigraimpex.a")
  fi
fi

if [[ -n "$cmake_prefix_path" ]]; then
  cmake_args+=(-DCMAKE_PREFIX_PATH="$cmake_prefix_path")
fi

cmake "${cmake_args[@]}" "$@"

cmake --build "$BUILD_DIR" --parallel
