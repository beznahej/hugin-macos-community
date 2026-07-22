#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DESTINATION="${1:-$ROOT_DIR/vendor/hugin}"
UPSTREAM_URL="${HUGIN_UPSTREAM_URL:-https://hg.code.sf.net/p/hugin/hugin}"

if ! command -v hg >/dev/null 2>&1; then
  echo "Mercurial (hg) is required." >&2
  echo "On macOS with Homebrew: brew install mercurial" >&2
  exit 1
fi

if [[ -e "$DESTINATION/.hg" ]]; then
  echo "Updating existing upstream checkout at $DESTINATION"
  hg --cwd "$DESTINATION" pull
  hg --cwd "$DESTINATION" update default
else
  if [[ -e "$DESTINATION" ]] && [[ -n "$(ls -A "$DESTINATION" 2>/dev/null || true)" ]]; then
    echo "Destination exists and is not empty: $DESTINATION" >&2
    exit 1
  fi
  mkdir -p "$(dirname "$DESTINATION")"
  hg clone -u default "$UPSTREAM_URL" "$DESTINATION"
fi

REVISION="$(hg --cwd "$DESTINATION" id -i)"
DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
printf 'url=%s\nrevision=%s\nfetched_at=%s\n' \
  "$UPSTREAM_URL" "$REVISION" "$DATE" \
  > "$DESTINATION/.hugin-macos-community-upstream"

echo "Fetched Hugin upstream revision: $REVISION"
