#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BUILD_DIR="${HUGIN_BUILD_DIR:-$ROOT_DIR/build/macos-dev}"
FIXTURE_DIR="${HUGIN_SMOKE_DIR:-$ROOT_DIR/build/smoke-cli-fixture}"

PTO_GEN="$BUILD_DIR/src/tools/pto_gen"
CPFIND="$BUILD_DIR/src/hugin_cpfind/cpfind/cpfind"
CPCLEAN="$BUILD_DIR/src/tools/cpclean"
AUTOOPTIMISER="$BUILD_DIR/src/tools/autooptimiser"
CHECKPTO="$BUILD_DIR/src/tools/checkpto"
NONA="$BUILD_DIR/src/tools/nona"

for tool in "$PTO_GEN" "$CPFIND" "$CPCLEAN" "$AUTOOPTIMISER" "$CHECKPTO" "$NONA"; do
  if [[ ! -x "$tool" ]]; then
    echo "Missing executable: $tool" >&2
    exit 1
  fi
done

mkdir -p "$FIXTURE_DIR"

generate_ppm() {
  local output="$1"
  local xoffset="$2"

  awk -v xoffset="$xoffset" '
    BEGIN {
      width = 160
      height = 100
      print "P3"
      print width, height
      print 255

      for (y = 0; y < height; y++) {
        for (x = 0; x < width; x++) {
          X = x + xoffset
          Y = y
          r = (int(X / 11) + int(Y / 13)) % 2 ? 210 : 35
          g = (int((X + 17) / 19) + int(Y / 7)) % 2 ? 180 : 45
          b = (int(X / 5) + int((Y + 23) / 17)) % 2 ? 160 : 65

          if ((X - 45) * (X - 45) + (Y - 32) * (Y - 32) < 160) {
            r = 255
            g = 80
            b = 40
          }

          if ((X - 105) * (X - 105) + (Y - 65) * (Y - 65) < 220) {
            r = 40
            g = 220
            b = 255
          }

          print r, g, b
        }
      }
    }
  ' > "$output"
}

left_image="$FIXTURE_DIR/left.ppm"
right_image="$FIXTURE_DIR/right.ppm"
generated_project="$FIXTURE_DIR/generated.pto"
matched_project="$FIXTURE_DIR/matched.pto"
cleaned_project="$FIXTURE_DIR/cleaned.pto"
optimized_project="$FIXTURE_DIR/optimized.pto"
render_prefix="$FIXTURE_DIR/rendered"

generate_ppm "$left_image" 0
generate_ppm "$right_image" 32

"$PTO_GEN" -o "$generated_project" -p 0 -f 55 "$left_image" "$right_image"
"$CPFIND" --allpairs --sieve1size=30 --sieve2size=5 --minmatches=3 \
  -o "$matched_project" "$generated_project"
"$CPCLEAN" -o "$cleaned_project" "$matched_project"
"$AUTOOPTIMISER" -a -l -s -o "$optimized_project" "$cleaned_project"

check_output="$("$CHECKPTO" --print-output-info "$optimized_project")"
printf '%s\n' "$check_output"

if ! grep -q "All images are connected." <<< "$check_output"; then
  echo "Fixture project images are not connected." >&2
  exit 1
fi

control_point_count="$(grep -c '^c ' "$optimized_project" || true)"
if [[ "$control_point_count" -lt 1 ]]; then
  echo "Fixture project has no control points." >&2
  exit 1
fi

"$NONA" -m PNG -o "$render_prefix" "$optimized_project"

if [[ ! -s "$render_prefix.png" ]]; then
  echo "nona did not produce $render_prefix.png" >&2
  exit 1
fi

echo "CLI smoke fixture completed: $render_prefix.png"
