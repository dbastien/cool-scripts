#!/usr/bin/env bash
set -euo pipefail

# Generates aliases.sh from aliases.toml (zsh sources this file).
# Output: aliases.sh

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
toml_file="$script_dir/aliases.toml"

[[ -f "$toml_file" ]] || { echo "Error: $toml_file not found"; exit 1; }

# Parse aliases.toml into tab-separated lines: section<TAB>name<TAB>command
parse_aliases() {
  awk '
    /^[[:space:]]*#/  { next }
    /^[[:space:]]*$/  { next }
    /^\[/ {
      gsub(/[\[\][:space:]]/, "")
      section = $0
      next
    }
    /=/ {
      name = $0; sub(/[[:space:]]*=.*/, "", name)
      gsub(/^[[:space:]]+/, "", name)
      gsub(/^"/, "", name); gsub(/"$/, "", name)
      val = $0; sub(/[^=]*=[[:space:]]*/, "", val)
      gsub(/^"/, "", val); gsub(/"$/, "", val)
      printf "%s\t%s\t%s\n", section, name, val
    }
  ' "$toml_file"
}

generate_posix() {
  local out="$script_dir/aliases.sh"
  {
    echo '# Zsh-compatible aliases (POSIX alias syntax).'
    echo '# AUTO-GENERATED from aliases.toml — do not edit directly.'
    echo ''
    local prev_section=""
    while IFS=$'\t' read -r section name cmd; do
      if [[ "$section" != "$prev_section" ]]; then
        [[ -n "$prev_section" ]] && echo ''
        prev_section="$section"
      fi
      echo "alias ${name}='${cmd}'"
    done < <(parse_aliases)
  } > "$out"
}

echo "Generating alias files from $toml_file..."
generate_posix
echo "Done: aliases.sh"
