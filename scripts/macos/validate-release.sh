#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail

usage() {
  cat >&2 <<'USAGE'
Usage: scripts/macos/validate-release.sh [path/to/Application.app ...] [path/to/artifact.dmg]

Environment:
  HUGIN_RELEASE_MODE   developer or distribution

Developer mode accepts ad-hoc signatures and validates bundle closure.
Distribution mode requires Developer ID signatures, hardened runtime,
Gatekeeper assessment and notarization stapling.
USAGE
}

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This validation entry point supports macOS only." >&2
  exit 1
fi

for tool in codesign file hdiutil otool spctl xcrun; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing required tool: $tool" >&2
    exit 1
  fi
done

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MODE="${HUGIN_RELEASE_MODE:-developer}"

case "$MODE" in
  developer|distribution) ;;
  *)
    echo "Unsupported HUGIN_RELEASE_MODE: $MODE" >&2
    usage
    exit 64
    ;;
esac

apps=()
dmg=""

if [[ $# -gt 0 ]]; then
  for artifact in "$@"; do
    case "$artifact" in
      *.app) apps+=("$artifact") ;;
      *.dmg) dmg="$artifact" ;;
      *)
        echo "Unsupported artifact type: $artifact" >&2
        usage
        exit 64
        ;;
    esac
  done
else
  while IFS= read -r app; do
    apps+=("$app")
  done < <("$ROOT_DIR/scripts/macos/list-app-bundles.sh")
  default_dmg="$ROOT_DIR/build/artifacts/hugin-macos-community.dmg"
  if [[ -f "$default_dmg" ]]; then
    dmg="$default_dmg"
  fi
fi

if [[ "${#apps[@]}" -eq 0 && -z "$dmg" ]]; then
  usage
  exit 64
fi

is_macho() {
  local path="$1"
  file -b "$path" | grep -Eq 'Mach-O|universal binary'
}

section_is_none() {
  local header="$1"
  local report="$2"
  awk -v header="$header" '
    $0 == header {
      getline
      found = 1
      ok = ($0 == "  none")
      exit
    }
    END {
      exit(found && ok ? 0 : 1)
    }
  ' "$report"
}

validate_no_rpath_references() {
  local app="$1"
  local refs_file
  refs_file="$(mktemp)"

  while IFS= read -r -d '' path; do
    if is_macho "$path"; then
      otool -L "$path" | sed '1d' | awk '$1 ~ /^@rpath\// { print $1 }' >> "$refs_file"
    fi
  done < <(find "$app" -type f -print0)

  if [[ -s "$refs_file" ]]; then
    echo "Remaining @rpath dependencies in $app:" >&2
    sort -u "$refs_file" >&2
    rm -f "$refs_file"
    return 1
  fi

  rm -f "$refs_file"
}

validate_app() {
  local app="$1"
  local report
  local signature

  if [[ ! -d "$app/Contents" ]]; then
    echo "Not an application bundle: $app" >&2
    return 1
  fi

  codesign --verify --deep --strict --verbose=1 "$app"

  report="$(mktemp)"
  "$ROOT_DIR/scripts/macos/inspect-app-deps.sh" "$app" > "$report"

  section_is_none "External absolute dependencies:" "$report" || {
    echo "External absolute dependencies remain in $app" >&2
    awk '/^External absolute dependencies:/,/^External absolute RPATHs:/' "$report" >&2
    rm -f "$report"
    return 1
  }

  section_is_none "External absolute RPATHs:" "$report" || {
    echo "External absolute rpaths remain in $app" >&2
    awk '/^External absolute RPATHs:/,/^Code signature:/' "$report" >&2
    rm -f "$report"
    return 1
  }

  if ! validate_no_rpath_references "$app"; then
    rm -f "$report"
    return 1
  fi

  signature="$(codesign -dvvv "$app" 2>&1 || true)"
  if [[ "$MODE" == "distribution" ]]; then
    if grep -q 'Signature=adhoc' <<< "$signature"; then
      echo "Distribution app is ad-hoc signed: $app" >&2
      rm -f "$report"
      return 1
    fi
    if grep -q 'TeamIdentifier=not set' <<< "$signature"; then
      echo "Distribution app has no Team Identifier: $app" >&2
      rm -f "$report"
      return 1
    fi
    if ! grep -q 'flags=.*runtime' <<< "$signature"; then
      echo "Distribution app is missing hardened runtime: $app" >&2
      rm -f "$report"
      return 1
    fi
    spctl -a -vv -t exec "$app"
  fi

  rm -f "$report"
  echo "Validated app: $app"
}

validate_dmg_contents() {
  local image="$1"
  local mount_dir
  local app_count
  local mounted_app
  local mounted=0

  mount_dir="$(mktemp -d "$ROOT_DIR/build/dmg-mount.XXXXXX")"

  hdiutil attach -nobrowse -readonly -mountpoint "$mount_dir" "$image" >/dev/null
  mounted=1

  app_count="$(find "$mount_dir" -maxdepth 1 -name '*.app' -type d | wc -l | tr -d ' ')"
  if [[ "$app_count" -lt 1 ]]; then
    echo "DMG contains no app bundles: $image" >&2
    hdiutil detach "$mount_dir" >/dev/null
    rm -rf "$mount_dir"
    return 1
  fi

  if [[ ! -e "$mount_dir/Applications" ]]; then
    echo "DMG is missing Applications shortcut: $image" >&2
    hdiutil detach "$mount_dir" >/dev/null
    rm -rf "$mount_dir"
    return 1
  fi

  while IFS= read -r -d '' mounted_app; do
    codesign --verify --deep --strict --verbose=1 "$mounted_app"
  done < <(find "$mount_dir" -maxdepth 1 -name '*.app' -type d -print0)

  if [[ "$mounted" -eq 1 ]]; then
    hdiutil detach "$mount_dir" >/dev/null
  fi
  rm -rf "$mount_dir"
}

validate_dmg() {
  local image="$1"

  if [[ ! -f "$image" ]]; then
    echo "DMG not found: $image" >&2
    return 1
  fi

  hdiutil verify "$image"
  validate_dmg_contents "$image"

  if codesign --verify --verbose=1 "$image" >/dev/null 2>&1; then
    codesign --verify --verbose=1 "$image"
  elif [[ "$MODE" == "distribution" ]]; then
    echo "Distribution DMG is not code signed: $image" >&2
    return 1
  fi

  if [[ "$MODE" == "distribution" ]]; then
    xcrun stapler validate "$image"
    spctl -a -vv -t open --context context:primary-signature "$image"
  fi

  echo "Validated DMG: $image"
}

for app in "${apps[@]}"; do
  validate_app "$app"
done

if [[ -n "$dmg" ]]; then
  validate_dmg "$dmg"
fi

echo "Release validation completed in $MODE mode."
