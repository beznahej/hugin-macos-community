#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: scripts/macos/package-dmg.sh [path/to/Application.app ...]

Environment:
  HUGIN_DMG_PATH            output DMG path
  HUGIN_DMG_VOLUME_NAME     mounted volume name
  HUGIN_DMG_STAGING_DIR     temporary staging directory
  HUGIN_DMG_SIGN_IDENTITY   optional codesign identity for the DMG
USAGE
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This DMG packaging entry point supports macOS only." >&2
  exit 1
fi

for tool in codesign ditto hdiutil; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing required tool: $tool" >&2
    exit 1
  fi
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARTIFACT_DIR="${HUGIN_ARTIFACT_DIR:-$ROOT_DIR/build/artifacts}"
DMG_PATH="${HUGIN_DMG_PATH:-$ARTIFACT_DIR/hugin-macos-community.dmg}"
VOLUME_NAME="${HUGIN_DMG_VOLUME_NAME:-Hugin macOS Community}"
STAGING_DIR="${HUGIN_DMG_STAGING_DIR:-$ROOT_DIR/build/dmg-staging}"
DMG_SIGN_IDENTITY="${HUGIN_DMG_SIGN_IDENTITY:-}"

apps=()
if [[ $# -gt 0 ]]; then
  apps=("$@")
else
  while IFS= read -r app; do
    apps+=("$app")
  done < <("$ROOT_DIR/scripts/macos/list-app-bundles.sh")
fi

if [[ "${#apps[@]}" -eq 0 ]]; then
  usage
  exit 64
fi

for app in "${apps[@]}"; do
  if [[ ! -d "$app/Contents" ]]; then
    echo "Not an application bundle: $app" >&2
    exit 1
  fi
done

rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR" "$ARTIFACT_DIR"

for app in "${apps[@]}"; do
  ditto "$app" "$STAGING_DIR/$(basename "$app")"
done

ln -s /Applications "$STAGING_DIR/Applications"

hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -ov \
  -format UDZO \
  "$DMG_PATH"

if [[ -n "$DMG_SIGN_IDENTITY" ]]; then
  codesign --force --sign "$DMG_SIGN_IDENTITY" "$DMG_PATH"
  codesign --verify --verbose=1 "$DMG_PATH"
fi

hdiutil verify "$DMG_PATH"
echo "Created DMG: $DMG_PATH"
