#!/usr/bin/env bash
# build-flag-cache.sh — Pre-build flag caches (flags + descriptions) for known tools.
# Run during install or manually: scripts/build-flag-cache.sh [cmd ...]
# With no args, processes all tools listed in config/tool-help.toml.
set -euo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/photontoaster/flags"
mkdir -p "$CACHE_DIR"

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_DIR="${PHOTONTOASTER_CONFIG_DIR:-${SCRIPT_DIR%/scripts}}"
if [[ -r "$CONFIG_DIR/tool-help.toml" ]]; then
  HELP_TOML="$CONFIG_DIR/tool-help.toml"
elif [[ -r "$CONFIG_DIR/config/tool-help.toml" ]]; then
  HELP_TOML="$CONFIG_DIR/config/tool-help.toml"
else
  HELP_TOML=""
fi

_read_toml_key() {
  local section="$1" key="$2" file="$3"
  awk -v sec="[$section]" -v k="$key" '
    $0 == sec { in_sec=1; next }
    /^\[/ { in_sec=0 }
    in_sec && match($0, "^" k " *= *\"?") {
      val = $0
      sub(/^[^=]*= *"?/, "", val)
      sub(/"? *$/, "", val)
      print val
      exit
    }
  ' "$file"
}

_extract_flags_with_desc() {
  awk '
    # Style A: "    -s, --long-flag[=VAL]" on its own line, desc on next lines
    # Style B: "  -s, --long-flag[=VAL]   Description text" on one line
    function flush() {
      if (cur_short == "" && cur_long == "") return
      gsub(/^[[:space:]]+/, "", cur_desc)
      gsub(/[[:space:]]+$/, "", cur_desc)
      if (length(cur_desc) > 80) cur_desc = substr(cur_desc, 1, 77) "..."
      if (cur_desc == "") cur_desc = "(no description)"
      if (cur_short != "") printf "%s\t%s\n", cur_short, cur_desc
      if (cur_long != "")  printf "%s\t%s\n", cur_long, cur_desc
      cur_short = ""; cur_long = ""; cur_desc = ""
    }

    BEGIN { cur_short = ""; cur_long = ""; cur_desc = "" }

    /^[[:space:]]+-[A-Za-z0-9]/ || /^[[:space:]]+--[A-Za-z0-9]/ {
      flush()
      line = $0
      gsub(/\t/, "    ", line)

      # Extract short flag (-X)
      if (match(line, /-[A-Za-z0-9](,| )/)) {
        cur_short = substr(line, RSTART, 2)
      }
      # Extract long flag (--foo-bar)
      if (match(line, /--[A-Za-z0-9][-A-Za-z0-9]*/)) {
        cur_long = substr(line, RSTART, RLENGTH)
      }

      # Check if description is on same line (Style B: flag  desc)
      n = split(line, parts, /  +/)
      if (n >= 2) {
        desc_candidate = ""
        for (j = 2; j <= n; j++) {
          if (desc_candidate != "") desc_candidate = desc_candidate " "
          desc_candidate = desc_candidate parts[j]
        }
        gsub(/^[[:space:]]+/, "", desc_candidate)
        if (desc_candidate !~ /^-/ && length(desc_candidate) >= 3) {
          cur_desc = desc_candidate
        }
      }
      next
    }

    # Continuation line for description (indented text after a flag line)
    (cur_short != "" || cur_long != "") && /^[[:space:]][[:space:]][[:space:]][[:space:]]/ {
      if (cur_desc == "") {
        line = $0
        gsub(/^[[:space:]]+/, "", line)
        gsub(/[[:space:]]+$/, "", line)
        if (length(line) >= 3) cur_desc = line
      }
      next
    }

    # Non-continuation line: flush any pending flag
    { if (cur_short != "" || cur_long != "") flush() }

    END { flush() }
  '
}

_build_one() {
  local cmd="$1"
  local cache_file="$CACHE_DIR/${cmd}.flags"
  local desc_file="$CACHE_DIR/${cmd}.desc"

  command -v "$cmd" >/dev/null 2>&1 || return 0

  local help_cmd help_alt help_text=""
  if [[ -r "$HELP_TOML" ]]; then
    help_cmd="$(_read_toml_key "$cmd" "help_cmd" "$HELP_TOML")"
    help_alt="$(_read_toml_key "$cmd" "help_alt" "$HELP_TOML")"
  fi

  if [[ -n "${help_cmd:-}" ]]; then
    help_text="$(eval "$help_cmd" 2>/dev/null)" || help_text=""
  fi

  if [[ -z "$help_text" && -n "${help_alt:-}" ]]; then
    help_text="$(eval "$help_alt" 2>/dev/null)" || help_text=""
  fi

  if [[ -z "$help_text" ]]; then
    help_text="$("$cmd" --help 2>/dev/null)" || help_text=""
  fi

  if [[ -z "$help_text" ]] && command -v man >/dev/null 2>&1; then
    help_text="$(MANPAGER=cat man "$cmd" 2>/dev/null | col -bx 2>/dev/null)" || help_text=""
  fi

  [[ -n "$help_text" ]] || return 0

  # plain flag list (for the highlighter)
  local flags
  flags="$(printf '%s\n' "$help_text" | awk '
    {
      gsub(/[(),\[\]]/, " ", $0)
      for (i = 1; i <= NF; i++) {
        t = $i
        sub(/[:;,]+$/, "", t)
        if (t ~ /^--[A-Za-z0-9][A-Za-z0-9-]*(=.*)?$/) {
          sub(/=.*/, "", t)
          print t
        } else if (t ~ /^-[A-Za-z0-9]$/) {
          print t
        }
      }
    }
  ' | sort -u | tr '\n' ' ')"

  if [[ -n "$flags" ]]; then
    {
      printf '%s\n' "$(date +%s)"
      printf '%s\n' "$flags"
    } > "$cache_file"
  fi

  # descriptions file (for intellisense)
  local descs
  descs="$(printf '%s\n' "$help_text" | _extract_flags_with_desc | sort -t$'\t' -k1,1 -u)"
  if [[ -n "$descs" ]]; then
    printf '%s\n' "$descs" > "$desc_file"
  fi
}

_progress() {
  local cur="$1" total="$2" cmd="$3"
  local pct=$(( cur * 100 / total ))
  local filled=$(( pct / 5 ))
  local empty=$(( 20 - filled ))
  local bar="" i
  for (( i = 0; i < filled; i++ )); do bar+="#"; done
  for (( i = 0; i < empty; i++ )); do bar+="."; done
  printf '\r  [%s] %d/%d %s\e[K' "$bar" "$cur" "$total" "$cmd"
}

if (( $# > 0 )); then
  total=$#
  cur=0
  for cmd in "$@"; do
    cur=$(( cur + 1 ))
    _progress "$cur" "$total" "$cmd"
    _build_one "$cmd"
  done
  printf '\r\e[K'
else
  if [[ -r "$HELP_TOML" ]]; then
    tools=()
    while IFS= read -r section; do
      tools+=("$section")
    done < <(grep --color=never -oP '^\[\K[a-zA-Z0-9_-]+(?=\])' "$HELP_TOML")
    total=${#tools[@]}
    cur=0
    for cmd in "${tools[@]}"; do
      cur=$(( cur + 1 ))
      _progress "$cur" "$total" "$cmd"
      _build_one "$cmd"
    done
    printf '\r\e[K'
  fi
fi

# Emit compiled zsh file for fast startup loading
_compiled="$CACHE_DIR/flags-compiled.zsh"
{
  echo "# Auto-generated by build-flag-cache.sh — do not edit"
  for f in "$CACHE_DIR"/*.flags; do
    [[ -f "$f" ]] || continue
    base="${f##*/}"
    base="${base%.flags}"
    name="${base%%_*}"
    flags="$(tail -n +2 "$f" 2>/dev/null | tr '\n' ' ')"
    [[ -n "$flags" ]] || continue
    printf "_pt_flag_specs[%s]='%s'\n" "$name" "$flags"
  done
} > "$_compiled" 2>/dev/null || true

cached=$(find "$CACHE_DIR" -name '*.flags' 2>/dev/null | wc -l)
descs=$(find "$CACHE_DIR" -name '*.desc' 2>/dev/null | wc -l)
echo "Flag cache built: $cached flag files, $descs description files in $CACHE_DIR"
