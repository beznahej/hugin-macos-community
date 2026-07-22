#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_DIR="${HUGIN_BUILD_DIR:-$ROOT_DIR/build/macos-dev}"
SOURCE_ROOT="${HUGIN_APP_SOURCE_ROOT:-$BUILD_DIR/src/hugin1}"
ARTIFACT_DIR="${HUGIN_ARTIFACT_DIR:-$ROOT_DIR/build/artifacts}"
OUTPUT_TAR="${HUGIN_UNSIGNED_APPS_TAR:-$ARTIFACT_DIR/hugin-macos-unsigned-apps.tar}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This packaging entry point supports macOS only." >&2
  exit 1
fi

if [[ ! -d "$SOURCE_ROOT" ]]; then
  echo "Built app source root not found: $SOURCE_ROOT" >&2
  echo "Run ./scripts/macos/build-dev.sh first." >&2
  exit 1
fi

apps=(
  hugin/Hugin.app
  calibrate_lens/calibrate_lens_gui.app
  ptbatcher/PTBatcherGUI.app
  stitch_project/HuginStitchProject.app
  toolbox/hugin_toolbox.app
)

for app in "${apps[@]}"; do
  if [[ ! -d "$SOURCE_ROOT/$app" ]]; then
    echo "Missing app bundle: $SOURCE_ROOT/$app" >&2
    exit 1
  fi
done

mkdir -p "$ARTIFACT_DIR"
tar -C "$SOURCE_ROOT" -cf "$OUTPUT_TAR" "${apps[@]}"

echo "Packaged unsigned app bundles: $OUTPUT_TAR"
