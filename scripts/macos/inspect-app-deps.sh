#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail

usage() {
  echo "Usage: $0 path/to/Application.app" >&2
}

if [[ $# -ne 1 ]]; then
  usage
  exit 64
fi

APP_BUNDLE="$1"

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script supports macOS only." >&2
  exit 1
fi

if [[ ! -d "$APP_BUNDLE/Contents" ]]; then
  echo "Not an application bundle: $APP_BUNDLE" >&2
  exit 1
fi

for tool in codesign file otool; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing required tool: $tool" >&2
    exit 1
  fi
done

is_macho() {
  local path="$1"
  file -b "$path" | grep -Eq 'Mach-O|universal binary'
}

print_relative() {
  local path="$1"
  printf '%s' "${path#"$APP_BUNDLE"/}"
}

external_deps_file="$(mktemp)"
external_rpaths_file="$(mktemp)"
codesign_file="$(mktemp)"
trap 'rm -f "$external_deps_file" "$external_rpaths_file" "$codesign_file"' EXIT

macho_files=()
while IFS= read -r -d '' path; do
  if is_macho "$path"; then
    macho_files+=("$path")
  fi
done < <(find "$APP_BUNDLE" -type f -print0)

echo "Bundle: $APP_BUNDLE"
echo
echo "Mach-O files:"
if [[ "${#macho_files[@]}" -eq 0 ]]; then
  echo "  none"
else
  for macho in "${macho_files[@]}"; do
    printf '  %s\n' "$(print_relative "$macho")"
  done
fi

for macho in "${macho_files[@]}"; do
  echo
  printf 'File: %s\n' "$(print_relative "$macho")"

  echo "  Dependencies:"
  while IFS= read -r dependency; do
    [[ -n "$dependency" ]] || continue
    printf '    %s\n' "$dependency"

    case "$dependency" in
      /System/Library/*|/usr/lib/*) ;;
      /*) printf '%s\n' "$dependency" >> "$external_deps_file" ;;
    esac
  done < <(otool -L "$macho" | sed '1d' | awk '{ print $1 }')

  echo "  RPATHs:"
  rpath_count=0
  while IFS= read -r rpath; do
    [[ -n "$rpath" ]] || continue
    rpath_count=$((rpath_count + 1))
    printf '    %s\n' "$rpath"

    case "$rpath" in
      @*|/System/Library/*|/usr/lib/*) ;;
      /*) printf '%s\n' "$rpath" >> "$external_rpaths_file" ;;
    esac
  done < <(otool -l "$macho" | awk '
    $1 == "cmd" && $2 == "LC_RPATH" { in_rpath = 1; next }
    in_rpath && $1 == "path" { print $2; in_rpath = 0 }
  ')

  if [[ "$rpath_count" -eq 0 ]]; then
    echo "    none"
  fi
done

echo
echo "External absolute dependencies:"
if [[ -s "$external_deps_file" ]]; then
  sort -u "$external_deps_file" | sed 's/^/  /'
else
  echo "  none"
fi

echo
echo "External absolute RPATHs:"
if [[ -s "$external_rpaths_file" ]]; then
  sort -u "$external_rpaths_file" | sed 's/^/  /'
else
  echo "  none"
fi

echo
echo "Code signature:"
if codesign -dvvv "$APP_BUNDLE" > /dev/null 2> "$codesign_file"; then
  sed 's/^/  /' "$codesign_file"
else
  echo "  codesign inspection failed"
  sed 's/^/  /' "$codesign_file"
fi
