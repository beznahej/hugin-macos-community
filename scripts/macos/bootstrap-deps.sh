#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
FORMULA_FILE="${HUGIN_HOMEBREW_FORMULAE:-$ROOT_DIR/deps/macos/homebrew-formulae.txt}"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script supports macOS only." >&2
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required for the initial developer bootstrap." >&2
  echo "Release builds will move to a locked self-contained dependency build." >&2
  exit 1
fi

if [[ ! -f "$FORMULA_FILE" ]]; then
  echo "Homebrew formula manifest not found: $FORMULA_FILE" >&2
  exit 1
fi

formulae=()
while IFS= read -r formula; do
  formulae+=("$formula")
done < <(awk 'NF && $1 !~ /^#/ { print $1 }' "$FORMULA_FILE")

if [[ "${#formulae[@]}" -eq 0 ]]; then
  echo "No Homebrew formulae found in $FORMULA_FILE" >&2
  exit 1
fi

echo "Installing Homebrew formulae from $FORMULA_FILE:"
printf '  %s\n' "${formulae[@]}"

# Avoid upgrading unrelated installed dependents while bootstrapping this repo.
HOMEBREW_NO_INSTALLED_DEPENDENTS_CHECK=1 \
  brew install "${formulae[@]}"

echo "Base development tools installed."
echo "Hugin runtime dependencies will be pinned after the Apple Silicon audit."
