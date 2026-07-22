#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: scripts/macos/sign-app.sh path/to/Application.app

Environment:
  HUGIN_SIGN_IDENTITY   codesign identity, or '-' for ad-hoc signing
  HUGIN_ENTITLEMENTS    optional entitlements plist for the final app bundle

Examples:
  HUGIN_SIGN_IDENTITY=- scripts/macos/sign-app.sh build/.../Hugin.app
  HUGIN_SIGN_IDENTITY="Developer ID Application: Example, Inc. (TEAMID)" \
    scripts/macos/sign-app.sh build/.../Hugin.app
USAGE
}

if [[ $# -ne 1 ]]; then
  usage
  exit 64
fi

APP_BUNDLE="$1"
SIGN_IDENTITY="${HUGIN_SIGN_IDENTITY:--}"
ENTITLEMENTS="${HUGIN_ENTITLEMENTS:-}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This signing entry point supports macOS only." >&2
  exit 1
fi

if [[ ! -d "$APP_BUNDLE/Contents" ]]; then
  echo "Not an application bundle: $APP_BUNDLE" >&2
  exit 1
fi

for tool in codesign file; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing required tool: $tool" >&2
    exit 1
  fi
done

if [[ -n "$ENTITLEMENTS" && ! -f "$ENTITLEMENTS" ]]; then
  echo "Entitlements file not found: $ENTITLEMENTS" >&2
  exit 1
fi

is_macho() {
  local path="$1"
  file -b "$path" | grep -Eq 'Mach-O|universal binary'
}

sign_args=(--force --sign "$SIGN_IDENTITY")
if [[ "$SIGN_IDENTITY" != "-" ]]; then
  sign_args+=(--options runtime --timestamp)
fi

bundle_args=("${sign_args[@]}")
if [[ -n "$ENTITLEMENTS" ]]; then
  bundle_args+=(--entitlements "$ENTITLEMENTS")
fi

macho_files=()
while IFS= read -r -d '' path; do
  if is_macho "$path"; then
    macho_files+=("$path")
  fi
done < <(find "$APP_BUNDLE" -type f -print0)

for macho in "${macho_files[@]}"; do
  codesign "${sign_args[@]}" "$macho"
done

codesign "${bundle_args[@]}" "$APP_BUNDLE"
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

echo "Signed and verified: $APP_BUNDLE"
