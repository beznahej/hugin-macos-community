#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: scripts/macos/notarize-release.sh path/to/artifact.dmg

Environment, choose one:
  HUGIN_NOTARY_PROFILE      xcrun notarytool keychain profile

or:
  HUGIN_NOTARY_APPLE_ID     Apple ID for notarytool
  HUGIN_NOTARY_PASSWORD     app-specific password or keychain item reference
  HUGIN_NOTARY_TEAM_ID      Apple Developer Team ID
USAGE
}

if [[ $# -ne 1 ]]; then
  usage
  exit 64
fi

ARTIFACT="$1"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This notarization entry point supports macOS only." >&2
  exit 1
fi

if [[ ! -f "$ARTIFACT" ]]; then
  echo "Artifact not found: $ARTIFACT" >&2
  exit 1
fi

if ! command -v xcrun >/dev/null 2>&1; then
  echo "Missing required tool: xcrun" >&2
  exit 1
fi

submit_args=()
if [[ -n "${HUGIN_NOTARY_PROFILE:-}" ]]; then
  submit_args+=(--keychain-profile "$HUGIN_NOTARY_PROFILE")
else
  missing=()
  [[ -n "${HUGIN_NOTARY_APPLE_ID:-}" ]] || missing+=(HUGIN_NOTARY_APPLE_ID)
  [[ -n "${HUGIN_NOTARY_PASSWORD:-}" ]] || missing+=(HUGIN_NOTARY_PASSWORD)
  [[ -n "${HUGIN_NOTARY_TEAM_ID:-}" ]] || missing+=(HUGIN_NOTARY_TEAM_ID)
  if [[ "${#missing[@]}" -gt 0 ]]; then
    echo "Missing notarization configuration:" >&2
    printf '  %s\n' "${missing[@]}" >&2
    usage
    exit 1
  fi
  submit_args+=(
    --apple-id "$HUGIN_NOTARY_APPLE_ID"
    --password "$HUGIN_NOTARY_PASSWORD"
    --team-id "$HUGIN_NOTARY_TEAM_ID"
  )
fi

xcrun notarytool submit "$ARTIFACT" --wait "${submit_args[@]}"
xcrun stapler staple "$ARTIFACT"
xcrun stapler validate "$ARTIFACT"

echo "Notarized and stapled: $ARTIFACT"
