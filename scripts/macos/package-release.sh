#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: scripts/macos/package-release.sh

Environment:
  HUGIN_RELEASE_MODE       developer or distribution
  HUGIN_SKIP_BUILD         set to 1 to reuse an existing build directory
  HUGIN_SIGN_IDENTITY      required for distribution, '-' for developer
  HUGIN_NOTARY_PROFILE     preferred notarytool keychain profile for distribution
  HUGIN_DMG_PATH           optional output DMG path

Developer mode builds a closed, ad-hoc signed DMG for local validation.
Distribution mode requires Developer ID and notarization credentials.
USAGE
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This release packaging entry point supports macOS only." >&2
  exit 1
fi

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MODE="${HUGIN_RELEASE_MODE:-developer}"
SKIP_BUILD="${HUGIN_SKIP_BUILD:-0}"

case "$MODE" in
  developer|distribution) ;;
  *)
    echo "Unsupported HUGIN_RELEASE_MODE: $MODE" >&2
    usage
    exit 64
    ;;
esac

if [[ "$MODE" == "distribution" ]]; then
  if [[ -z "${HUGIN_SIGN_IDENTITY:-}" || "${HUGIN_SIGN_IDENTITY:-}" == "-" ]]; then
    echo "Distribution mode requires HUGIN_SIGN_IDENTITY with a Developer ID Application certificate." >&2
    exit 1
  fi

  if ! security find-identity -p codesigning -v | grep -F "$HUGIN_SIGN_IDENTITY" >/dev/null; then
    echo "Signing identity is not available in the current keychain: $HUGIN_SIGN_IDENTITY" >&2
    exit 1
  fi

  if [[ -z "${HUGIN_NOTARY_PROFILE:-}" ]]; then
    missing=()
    [[ -n "${HUGIN_NOTARY_APPLE_ID:-}" ]] || missing+=(HUGIN_NOTARY_APPLE_ID)
    [[ -n "${HUGIN_NOTARY_PASSWORD:-}" ]] || missing+=(HUGIN_NOTARY_PASSWORD)
    [[ -n "${HUGIN_NOTARY_TEAM_ID:-}" ]] || missing+=(HUGIN_NOTARY_TEAM_ID)
    if [[ "${#missing[@]}" -gt 0 ]]; then
      echo "Distribution mode requires notarization credentials." >&2
      printf '  missing: %s\n' "${missing[@]}" >&2
      exit 1
    fi
  fi
else
  export HUGIN_SIGN_IDENTITY="${HUGIN_SIGN_IDENTITY:--}"
fi

if [[ "$SKIP_BUILD" != "1" ]]; then
  "$ROOT_DIR/scripts/macos/bootstrap-deps.sh"
  "$ROOT_DIR/scripts/macos/build-vigra.sh"
  "$ROOT_DIR/scripts/macos/build-dev.sh"
  "$ROOT_DIR/scripts/macos/smoke-cli-fixture.sh"
fi

apps=()
while IFS= read -r app; do
  apps+=("$app")
done < <("$ROOT_DIR/scripts/macos/list-app-bundles.sh")

"$ROOT_DIR/scripts/macos/bundle-app-deps.sh" "${apps[@]}"
"$ROOT_DIR/scripts/macos/sign-app.sh" "${apps[@]}"

if [[ "$MODE" == "distribution" ]]; then
  export HUGIN_DMG_SIGN_IDENTITY="${HUGIN_DMG_SIGN_IDENTITY:-$HUGIN_SIGN_IDENTITY}"
fi

"$ROOT_DIR/scripts/macos/package-dmg.sh" "${apps[@]}"

dmg_path="${HUGIN_DMG_PATH:-$ROOT_DIR/build/artifacts/hugin-macos-community.dmg}"
if [[ "$MODE" == "distribution" ]]; then
  "$ROOT_DIR/scripts/macos/notarize-release.sh" "$dmg_path"
fi

"$ROOT_DIR/scripts/macos/validate-release.sh" "${apps[@]}" "$dmg_path"

echo "Phase 2 release package completed in $MODE mode: $dmg_path"
