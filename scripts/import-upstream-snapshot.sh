#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
UPSTREAM_URL="${HUGIN_UPSTREAM_URL:-http://hg.code.sf.net/p/hugin/hugin}"
UPSTREAM_BRANCH="${HUGIN_UPSTREAM_BRANCH:-default}"
CHECKOUT_DIR="${HUGIN_CHECKOUT_DIR:-$ROOT_DIR/vendor/hugin}"
SNAPSHOT_DIR="${HUGIN_SNAPSHOT_DIR:-$ROOT_DIR/upstream/hugin}"

if ! command -v hg >/dev/null 2>&1; then
  echo "Mercurial (hg) is required." >&2
  echo "On macOS with Homebrew: brew install mercurial" >&2
  exit 1
fi

case "$SNAPSHOT_DIR" in
  "$ROOT_DIR"/upstream/*) ;;
  *)
    echo "Refusing to overwrite snapshot outside $ROOT_DIR/upstream: $SNAPSHOT_DIR" >&2
    exit 1
    ;;
esac

if [[ -e "$CHECKOUT_DIR/.hg" ]]; then
  echo "Updating upstream checkout at $CHECKOUT_DIR"
  hg --cwd "$CHECKOUT_DIR" pull
  hg --cwd "$CHECKOUT_DIR" update "$UPSTREAM_BRANCH"
else
  if [[ -e "$CHECKOUT_DIR" ]] && [[ -n "$(ls -A "$CHECKOUT_DIR" 2>/dev/null || true)" ]]; then
    echo "Checkout destination exists and is not empty: $CHECKOUT_DIR" >&2
    exit 1
  fi
  mkdir -p "$(dirname "$CHECKOUT_DIR")"
  hg clone -u "$UPSTREAM_BRANCH" "$UPSTREAM_URL" "$CHECKOUT_DIR"
fi

REVISION="$(hg --cwd "$CHECKOUT_DIR" id -i)"
FULL_REVISION="$(hg --cwd "$CHECKOUT_DIR" id --debug -i)"
DATE="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
CHECKOUT_LABEL="${CHECKOUT_DIR#"$ROOT_DIR"/}"
SNAPSHOT_LABEL="${SNAPSHOT_DIR#"$ROOT_DIR"/}"

rm -rf "$SNAPSHOT_DIR"
mkdir -p "$SNAPSHOT_DIR"
hg --cwd "$CHECKOUT_DIR" archive -r "$UPSTREAM_BRANCH" "$SNAPSHOT_DIR"

cat > "$SNAPSHOT_DIR/UPSTREAM-SNAPSHOT" <<EOF
url=$UPSTREAM_URL
branch=$UPSTREAM_BRANCH
revision=$REVISION
full_revision=$FULL_REVISION
imported_at=$DATE
procedure=scripts/import-upstream-snapshot.sh
checkout_dir=$CHECKOUT_LABEL
snapshot_dir=$SNAPSHOT_LABEL
EOF

echo "Imported Hugin upstream snapshot:"
echo "  branch:   $UPSTREAM_BRANCH"
echo "  revision: $REVISION"
echo "  snapshot: $SNAPSHOT_DIR"
