#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script supports macOS only." >&2
  exit 1
fi

if ! command -v brew >/dev/null 2>&1; then
  echo "Homebrew is required for the initial developer bootstrap." >&2
  echo "Release builds will move to a locked self-contained dependency build." >&2
  exit 1
fi

# Keep this intentionally small until the upstream dependency audit is complete.
brew install cmake ninja mercurial pkg-config

echo "Base development tools installed."
echo "Hugin runtime dependencies will be pinned after the Apple Silicon audit."
