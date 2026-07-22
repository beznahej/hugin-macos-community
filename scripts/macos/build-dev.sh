#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SOURCE_DIR="${HUGIN_SOURCE_DIR:-$ROOT_DIR/upstream/hugin}"
BUILD_DIR="${HUGIN_BUILD_DIR:-$ROOT_DIR/build/macos-dev}"
ARCHITECTURE="${HUGIN_ARCHITECTURE:-$(uname -m)}"
DEPLOYMENT_TARGET="${HUGIN_MACOS_DEPLOYMENT_TARGET:-13.0}"

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

cmake -S "$SOURCE_DIR" -B "$BUILD_DIR" -G Ninja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_OSX_ARCHITECTURES="$ARCHITECTURE" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET" \
  -DCMAKE_MACOSX_RPATH=ON \
  "$@"

cmake --build "$BUILD_DIR" --parallel
