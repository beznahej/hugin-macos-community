#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_DIR="${HUGIN_BUILD_DIR:-$ROOT_DIR/build/macos-dev}"
SOURCE_ROOT="${HUGIN_APP_SOURCE_ROOT:-$BUILD_DIR/src/hugin1}"

apps=(
  hugin/Hugin.app
  calibrate_lens/calibrate_lens_gui.app
  ptbatcher/PTBatcherGUI.app
  stitch_project/HuginStitchProject.app
  toolbox/hugin_toolbox.app
)

if [[ ! -d "$SOURCE_ROOT" ]]; then
  echo "Built app source root not found: $SOURCE_ROOT" >&2
  echo "Run ./scripts/macos/build-dev.sh first." >&2
  exit 1
fi

for app in "${apps[@]}"; do
  path="$SOURCE_ROOT/$app"
  if [[ ! -d "$path" ]]; then
    echo "Missing app bundle: $path" >&2
    exit 1
  fi
  printf '%s\n' "$path"
done
