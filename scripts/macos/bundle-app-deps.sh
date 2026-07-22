#!/usr/bin/env bash
# SPDX-License-Identifier: GPL-2.0-or-later
set -euo pipefail

usage() {
  echo "Usage: $0 path/to/Application.app [path/to/Other.app ...]" >&2
}

if [[ $# -lt 1 ]]; then
  usage
  exit 64
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "This script supports macOS only." >&2
  exit 1
fi

for tool in codesign file install_name_tool otool; do
  if ! command -v "$tool" >/dev/null 2>&1; then
    echo "Missing required tool: $tool" >&2
    exit 1
  fi
done

contains_line() {
  local needle="$1"
  local file="$2"
  grep -Fqx "$needle" "$file"
}

add_line_once() {
  local line="$1"
  local file="$2"
  if ! contains_line "$line" "$file"; then
    printf '%s\n' "$line" >> "$file"
  fi
}

is_macho() {
  local path="$1"
  file -b "$path" | grep -Eq 'Mach-O|universal binary'
}

remove_signature() {
  local path="$1"
  codesign --remove-signature "$path" >/dev/null 2>&1 || true
}

is_system_dependency() {
  local dependency="$1"
  case "$dependency" in
    /System/Library/*|/usr/lib/*) return 0 ;;
    *) return 1 ;;
  esac
}

parse_dependencies() {
  local macho="$1"
  otool -L "$macho" | sed '1d' | awk 'NF { print $1 }'
}

parse_rpaths() {
  local macho="$1"
  otool -l "$macho" | awk '
    $1 == "cmd" && $2 == "LC_RPATH" { in_rpath = 1; next }
    in_rpath && $1 == "path" { print $2; in_rpath = 0 }
  '
}

normalize_existing_path() {
  local path="$1"
  local directory
  local basename
  directory="$(cd "$(dirname "$path")" && pwd -P)"
  basename="$(basename "$path")"
  printf '%s/%s\n' "$directory" "$basename"
}

expand_loader_path() {
  local path="$1"
  local macho="$2"
  local app_bundle="$3"

  case "$path" in
    @loader_path/*)
      printf '%s/%s\n' "$(dirname "$macho")" "${path#@loader_path/}"
      ;;
    @executable_path/*)
      printf '%s/Contents/MacOS/%s\n' "$app_bundle" "${path#@executable_path/}"
      ;;
    *)
      printf '%s\n' "$path"
      ;;
  esac
}

resolve_dependency() {
  local dependency="$1"
  local macho="$2"
  local app_bundle="$3"
  local suffix
  local rpath
  local expanded_rpath
  local candidate

  if is_system_dependency "$dependency"; then
    return 1
  fi

  case "$dependency" in
    /*|@loader_path/*|@executable_path/*)
      candidate="$(expand_loader_path "$dependency" "$macho" "$app_bundle")"
      if [[ -f "$candidate" ]]; then
        normalize_existing_path "$candidate"
        return 0
      fi
      ;;
    @rpath/*)
      suffix="${dependency#@rpath/}"
      while IFS= read -r rpath; do
        [[ -n "$rpath" ]] || continue
        expanded_rpath="$(expand_loader_path "$rpath" "$macho" "$app_bundle")"
        candidate="$expanded_rpath/$suffix"
        if [[ -f "$candidate" ]]; then
          normalize_existing_path "$candidate"
          return 0
        fi
      done < <(parse_rpaths "$macho")
      ;;
  esac

  return 1
}

is_inside_bundle() {
  local path="$1"
  local app_bundle="$2"
  case "$path" in
    "$app_bundle"/*) return 0 ;;
    *) return 1 ;;
  esac
}

replacement_for() {
  local macho="$1"
  local frameworks_dir="$2"
  local basename="$3"

  case "$macho" in
    "$frameworks_dir"/*) printf '@loader_path/%s\n' "$basename" ;;
    *) printf '@executable_path/../Frameworks/%s\n' "$basename" ;;
  esac
}

collect_macho_files() {
  local app_bundle="$1"
  local output_file="$2"
  : > "$output_file"

  while IFS= read -r -d '' path; do
    if is_macho "$path"; then
      printf '%s\n' "$(normalize_existing_path "$path")" >> "$output_file"
    fi
  done < <(find "$app_bundle" -type f -print0)
}

bundle_one_app() {
  local app_bundle="$1"
  local frameworks_dir="$app_bundle/Contents/Frameworks"
  local processed_file
  local copied_sources_file
  local copied_destinations_file
  local macho_file
  local queue=()
  local queue_index=0
  local macho
  local dependency
  local source
  local basename
  local destination
  local replacement
  local rpath

  if [[ ! -d "$app_bundle/Contents" ]]; then
    echo "Not an application bundle: $app_bundle" >&2
    exit 1
  fi

  app_bundle="$(normalize_existing_path "$app_bundle")"
  frameworks_dir="$app_bundle/Contents/Frameworks"
  mkdir -p "$frameworks_dir"

  processed_file="$(mktemp)"
  copied_sources_file="$(mktemp)"
  copied_destinations_file="$(mktemp)"
  macho_file="$(mktemp)"
  : > "$processed_file"
  : > "$copied_sources_file"
  : > "$copied_destinations_file"
  trap 'rm -f "$processed_file" "$copied_sources_file" "$copied_destinations_file" "$macho_file"' RETURN

  collect_macho_files "$app_bundle" "$macho_file"
  while IFS= read -r macho; do
    queue+=("$macho")
  done < "$macho_file"

  while [[ "$queue_index" -lt "${#queue[@]}" ]]; do
    macho="${queue[$queue_index]}"
    queue_index=$((queue_index + 1))

    if contains_line "$macho" "$processed_file"; then
      continue
    fi
    add_line_once "$macho" "$processed_file"

    while IFS= read -r dependency; do
      [[ -n "$dependency" ]] || continue
      if ! source="$(resolve_dependency "$dependency" "$macho" "$app_bundle")"; then
        continue
      fi
      if is_inside_bundle "$source" "$app_bundle"; then
        continue
      fi

      basename="$(basename "$source")"
      destination="$frameworks_dir/$basename"

      if [[ ! -e "$destination" ]]; then
        cp -p "$source" "$destination"
        chmod u+w "$destination"
        echo "Bundled $basename"
      fi

      add_line_once "$source" "$copied_sources_file"
      add_line_once "$destination" "$copied_destinations_file"
      queue+=("$source")
    done < <(parse_dependencies "$macho")
  done

  collect_macho_files "$app_bundle" "$macho_file"
  while IFS= read -r macho; do
    remove_signature "$macho"

    while IFS= read -r dependency; do
      [[ -n "$dependency" ]] || continue
      if source="$(resolve_dependency "$dependency" "$macho" "$app_bundle")"; then
        basename="$(basename "$source")"
      else
        basename="$(basename "$dependency")"
      fi

      destination="$frameworks_dir/$basename"
      if [[ ! -f "$destination" ]]; then
        continue
      fi

      replacement="$(replacement_for "$macho" "$frameworks_dir" "$basename")"
      if [[ "$dependency" != "$replacement" ]]; then
        install_name_tool -change "$dependency" "$replacement" "$macho"
      fi
    done < <(parse_dependencies "$macho")

    while IFS= read -r rpath; do
      [[ -n "$rpath" ]] || continue
      case "$rpath" in
        /*) install_name_tool -delete_rpath "$rpath" "$macho" ;;
      esac
    done < <(parse_rpaths "$macho")

    case "$macho" in
      "$frameworks_dir"/*)
        install_name_tool -id "@loader_path/$(basename "$macho")" "$macho"
        ;;
      *)
        if ! parse_rpaths "$macho" | grep -Fqx '@executable_path/../Frameworks'; then
          install_name_tool -add_rpath '@executable_path/../Frameworks' "$macho"
        fi
        ;;
    esac
  done < "$macho_file"

  echo "Bundled dependencies for $app_bundle"
  echo "Copied dependency count: $(wc -l < "$copied_destinations_file" | tr -d ' ')"
}

for app_bundle in "$@"; do
  bundle_one_app "$app_bundle"
done
