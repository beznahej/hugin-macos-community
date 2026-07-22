#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARCHITECTURE="${HUGIN_ARCHITECTURE:-$(uname -m)}"
DEPLOYMENT_TARGET="${HUGIN_MACOS_DEPLOYMENT_TARGET:-13.0}"
SOURCE_ROOT="${HUGIN_SOURCE_DEPS_DIR:-$ROOT_DIR/build/source}"
PREFIX="${HUGIN_DEPS_PREFIX:-$ROOT_DIR/build/deps/macos-$ARCHITECTURE}"
VIGRA_REPO="${HUGIN_VIGRA_REPO:-https://github.com/ukoethe/vigra.git}"
VIGRA_REF="${HUGIN_VIGRA_REF:-Version-1-12-4}"
VIGRA_COMMIT="${HUGIN_VIGRA_COMMIT:-de98f930b66d461360a2d5dc8f9adfa84bb01058}"
VIGRA_SOURCE_DIR="${HUGIN_VIGRA_SOURCE_DIR:-$SOURCE_ROOT/vigra}"
VIGRA_BUILD_DIR="${HUGIN_VIGRA_BUILD_DIR:-$ROOT_DIR/build/vigra-macos-$ARCHITECTURE}"
VIGRA_PATCH="${HUGIN_VIGRA_PATCH:-$ROOT_DIR/deps/macos/patches/vigra-1.12.4-package-src-doc-target.patch}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script supports macOS only." >&2
  exit 1
fi

for tool in git cmake ninja; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing required tool: $tool" >&2
    exit 1
  fi
done

mkdir -p "$SOURCE_ROOT" "$PREFIX"

if [[ ! -d "$VIGRA_SOURCE_DIR/.git" ]]; then
  git clone --depth 1 --branch "$VIGRA_REF" "$VIGRA_REPO" "$VIGRA_SOURCE_DIR"
fi

if ! git -C "$VIGRA_SOURCE_DIR" rev-parse --verify "$VIGRA_COMMIT^{commit}" >/dev/null 2>&1; then
  git -C "$VIGRA_SOURCE_DIR" fetch --depth 1 origin "$VIGRA_REF"
fi

git -C "$VIGRA_SOURCE_DIR" checkout --detach "$VIGRA_COMMIT"

actual_commit="$(git -C "$VIGRA_SOURCE_DIR" rev-parse HEAD)"
if [[ "$actual_commit" != "$VIGRA_COMMIT" ]]; then
  echo "Unexpected VIGRA commit: $actual_commit" >&2
  echo "Expected: $VIGRA_COMMIT" >&2
  exit 1
fi

if [[ -f "$VIGRA_PATCH" ]]; then
  if git -C "$VIGRA_SOURCE_DIR" apply --check "$VIGRA_PATCH" >/dev/null 2>&1; then
    git -C "$VIGRA_SOURCE_DIR" apply "$VIGRA_PATCH"
  elif ! git -C "$VIGRA_SOURCE_DIR" apply --reverse --check "$VIGRA_PATCH" >/dev/null 2>&1; then
    echo "VIGRA patch does not apply cleanly: $VIGRA_PATCH" >&2
    exit 1
  fi
fi

cmake -S "$VIGRA_SOURCE_DIR" -B "$VIGRA_BUILD_DIR" -G Ninja \
  -DCMAKE_BUILD_TYPE=RelWithDebInfo \
  -DCMAKE_OSX_ARCHITECTURES="$ARCHITECTURE" \
  -DCMAKE_OSX_DEPLOYMENT_TARGET="$DEPLOYMENT_TARGET" \
  -DCMAKE_MACOSX_RPATH=ON \
  -DCMAKE_INSTALL_PREFIX="$PREFIX" \
  -DBUILD_DOCS=OFF \
  -DBUILD_TESTS=OFF \
  -DWITH_VIGRANUMPY=OFF \
  -DWITH_HDF5=OFF \
  -DWITH_OPENEXR=ON

cmake --build "$VIGRA_BUILD_DIR" --parallel
cmake --install "$VIGRA_BUILD_DIR"

mkdir -p "$PREFIX/share/hugin-deps"
{
  echo "name=vigra"
  echo "repository=$VIGRA_REPO"
  echo "ref=$VIGRA_REF"
  echo "commit=$VIGRA_COMMIT"
  echo "architecture=$ARCHITECTURE"
  echo "deployment_target=$DEPLOYMENT_TARGET"
} > "$PREFIX/share/hugin-deps/vigra.provenance"

if [[ ! -f "$PREFIX/include/vigra/gaborfilter.hxx" ]]; then
  echo "VIGRA headers were not installed under $PREFIX/include" >&2
  exit 1
fi

if [[ ! -f "$PREFIX/lib/libvigraimpex.dylib" && ! -f "$PREFIX/lib/libvigraimpex.a" ]]; then
  echo "VIGRA library was not installed under $PREFIX/lib" >&2
  exit 1
fi

echo "VIGRA installed into $PREFIX"
