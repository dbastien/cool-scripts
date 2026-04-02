#!/usr/bin/env bash
set -euo pipefail

# Generates per-shell alias files from config/aliases.toml
# Output: shared/aliases.sh, fish/aliases.fish, nushell/aliases.nu, powershell/aliases.ps1

script_dir="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
repo_root="$(cd -- "$script_dir/.." && pwd)"
toml_file="$repo_root/aliases.toml"
[[ -f "$toml_file" ]] || toml_file="$repo_root/config/aliases.toml"

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

# Sections where aliases are guarded by command existence checks
is_guarded_section() {
  case "$1" in
    tools|replacements) return 0 ;;
    *) return 1 ;;
  esac
}

# Commands that should always be guarded in PowerShell output because
# they are often Linux-only or not guaranteed on Windows.
is_powershell_always_guard_cmd() {
  case "$1" in
    cronboard|grep|ip|plocate|ss|tmux) return 0 ;;
    *) return 1 ;;
  esac
}

# Extract the base command name from an alias value for guard checks
guard_cmd() {
  local val="$1"
  echo "${val%% *}"
}

emit_posix_guarded_section() {
  local entries="$1"
  local -a guard_order=()
  declare -A guard_seen=()
  declare -A guard_aliases=()

  local entry_name entry_cmd
  while IFS=$'\t' read -r entry_name entry_cmd; do
    [[ -z "${entry_name:-}" ]] && continue
    local guard_name
    guard_name="$(guard_cmd "$entry_cmd")"
    if [[ -z "${guard_seen[$guard_name]+x}" ]]; then
      guard_seen["$guard_name"]=1
      guard_order+=("$guard_name")
    fi
    guard_aliases["$guard_name"]+=$"  alias ${entry_name}='${entry_cmd}'"$'\n'
  done <<< "$entries"

  local guard_name
  for guard_name in "${guard_order[@]}"; do
    echo "if command -v $guard_name >/dev/null 2>&1; then"
    printf '%s' "${guard_aliases[$guard_name]}"
    echo 'fi'
  done
}

emit_fish_guarded_section() {
  local entries="$1"
  local -a guard_order=()
  declare -A guard_seen=()
  declare -A guard_abbrs=()

  local entry_name entry_cmd
  while IFS=$'\t' read -r entry_name entry_cmd; do
    [[ -z "${entry_name:-}" ]] && continue
    local guard_name
    guard_name="$(guard_cmd "$entry_cmd")"
    if [[ -z "${guard_seen[$guard_name]+x}" ]]; then
      guard_seen["$guard_name"]=1
      guard_order+=("$guard_name")
    fi
    guard_abbrs["$guard_name"]+=$"  abbr -a $entry_name -- '$entry_cmd'"$'\n'
  done <<< "$entries"

  local guard_name
  for guard_name in "${guard_order[@]}"; do
    echo "if type -q $guard_name"
    printf '%s' "${guard_abbrs[$guard_name]}"
    echo 'end'
  done
}

emit_nushell_guarded_section() {
  local entries="$1"
  local -a guard_order=()
  declare -A guard_seen=()
  declare -A guard_aliases=()

  local entry_name entry_cmd
  while IFS=$'\t' read -r entry_name entry_cmd; do
    [[ -z "${entry_name:-}" ]] && continue
    local guard_name
    guard_name="$(guard_cmd "$entry_cmd")"
    if [[ -z "${guard_seen[$guard_name]+x}" ]]; then
      guard_seen["$guard_name"]=1
      guard_order+=("$guard_name")
    fi
    guard_aliases["$guard_name"]+=$"  alias $entry_name = $entry_cmd"$'\n'
  done <<< "$entries"

  local guard_name
  for guard_name in "${guard_order[@]}"; do
    echo "if not ((which $guard_name | is-empty)) {"
    printf '%s' "${guard_aliases[$guard_name]}"
    echo '}'
  done
}

emit_powershell_guarded_section() {
  local entries="$1"
  local -a guard_order=()
  declare -A guard_seen=()
  declare -A guard_funcs=()

  local entry_name entry_cmd
  while IFS=$'\t' read -r entry_name entry_cmd; do
    [[ -z "${entry_name:-}" ]] && continue
    local base_cmd
    base_cmd="$(guard_cmd "$entry_cmd")"
    local rest="${entry_cmd#"$base_cmd"}"
    rest="${rest# }"
    if [[ -z "${guard_seen[$base_cmd]+x}" ]]; then
      guard_seen["$base_cmd"]=1
      guard_order+=("$base_cmd")
    fi
    if [[ -n "$rest" ]]; then
      guard_funcs["$base_cmd"]+=$"function global:${entry_name} { & $base_cmd $rest @args }"$'\n'
    else
      guard_funcs["$base_cmd"]+=$"function global:${entry_name} { & $base_cmd @args }"$'\n'
    fi
  done <<< "$entries"

  local base_cmd
  for base_cmd in "${guard_order[@]}"; do
    echo "if (Get-Command '$base_cmd' -ErrorAction SilentlyContinue) {"
    while IFS= read -r line; do
      [[ -z "$line" ]] && continue
      echo "  $line"
    done <<< "${guard_funcs[$base_cmd]}"
    echo "}"
  done
}

generate_posix() {
  local out="$repo_root/shared/aliases.sh"
  {
    echo '# POSIX-compatible aliases — sourced by bash and zsh.'
    echo '# AUTO-GENERATED from config/aliases.toml — do not edit directly.'
    echo ''
    local prev_section=""
    local guarded_entries=""
    while IFS=$'\t' read -r section name cmd; do
      if [[ "$section" != "$prev_section" ]]; then
        if [[ -n "$prev_section" ]] && is_guarded_section "$prev_section" && [[ -n "$guarded_entries" ]]; then
          emit_posix_guarded_section "$guarded_entries"
          guarded_entries=""
        fi
        [[ -n "$prev_section" ]] && echo ''
        prev_section="$section"
      fi
      if is_guarded_section "$section"; then
        guarded_entries+="$name"$'\t'"$cmd"$'\n'
      else
        echo "alias ${name}='${cmd}'"
      fi
    done < <(parse_aliases)
    if [[ -n "$prev_section" ]] && is_guarded_section "$prev_section" && [[ -n "$guarded_entries" ]]; then
      emit_posix_guarded_section "$guarded_entries"
    fi
  } > "$out"
}

generate_fish() {
  local out="$repo_root/fish/aliases.fish"
  {
    echo '# PhotonToaster fish aliases (abbreviations)'
    echo '# AUTO-GENERATED from config/aliases.toml — do not edit directly.'
    echo ''
    local prev_section=""
    local guarded_entries=""
    while IFS=$'\t' read -r section name cmd; do
      if [[ "$section" != "$prev_section" ]]; then
        if [[ -n "$prev_section" ]] && is_guarded_section "$prev_section" && [[ -n "$guarded_entries" ]]; then
          emit_fish_guarded_section "$guarded_entries"
          guarded_entries=""
        fi
        [[ -n "$prev_section" ]] && echo ''
        prev_section="$section"
      fi
      local rendered_cmd="$cmd"
      case "$name" in
        reload) rendered_cmd="exec fish -l" ;;
      esac
      if is_guarded_section "$section"; then
        guarded_entries+="$name"$'\t'"$rendered_cmd"$'\n'
      else
        echo "abbr -a $name -- '$rendered_cmd'"
      fi
    done < <(parse_aliases)
    if [[ -n "$prev_section" ]] && is_guarded_section "$prev_section" && [[ -n "$guarded_entries" ]]; then
      emit_fish_guarded_section "$guarded_entries"
    fi
  } > "$out"
}

generate_nushell() {
  local out="$repo_root/nushell/aliases.nu"
  {
    echo '# PhotonToaster nushell aliases'
    echo '# AUTO-GENERATED from config/aliases.toml — do not edit directly.'
    echo ''
    local prev_section=""
    local guarded_entries=""
    while IFS=$'\t' read -r section name cmd; do
      if [[ "$section" != "$prev_section" ]]; then
        if [[ -n "$prev_section" ]] && is_guarded_section "$prev_section" && [[ -n "$guarded_entries" ]]; then
          emit_nushell_guarded_section "$guarded_entries"
          guarded_entries=""
        fi
        [[ -n "$prev_section" ]] && echo ''
        prev_section="$section"
      fi
      case "$name" in
        cd..|..|...|....)
          echo "def --env \"$name\" [] { $cmd }"
          ;;
        reload)
          echo 'def --env reload [] { exec nu -l }'
          ;;
        v)
          echo 'if "EDITOR" in $env { def --wrapped v [...args] { ^$env.EDITOR ...$args } }'
          ;;
        *)
          if is_guarded_section "$section"; then
            guarded_entries+="$name"$'\t'"$cmd"$'\n'
          else
            echo "alias $name = $cmd"
          fi
          ;;
      esac
    done < <(parse_aliases)
    if [[ -n "$prev_section" ]] && is_guarded_section "$prev_section" && [[ -n "$guarded_entries" ]]; then
      emit_nushell_guarded_section "$guarded_entries"
    fi
  } > "$out"
}

generate_powershell() {
  local out="$repo_root/powershell/aliases.ps1"
  {
    echo '# PhotonToaster PowerShell aliases/functions'
    echo '# AUTO-GENERATED from config/aliases.toml — do not edit directly.'
    echo ''
    local prev_section=""
    local guarded_entries=""
    while IFS=$'\t' read -r section name cmd; do
      if [[ "$section" != "$prev_section" ]]; then
        if [[ -n "$guarded_entries" ]]; then
          emit_powershell_guarded_section "$guarded_entries"
          guarded_entries=""
        fi
        [[ -n "$prev_section" ]] && echo ''
        prev_section="$section"
      fi
      case "$name" in
        cls)
          cat <<'PS1'
function global:cls { Clear-Host }
PS1
          ;;
        mkd)
          cat <<'PS1'
function global:mkd {
  param([Parameter(ValueFromRemainingArguments)][string[]]$Paths)
  foreach ($p in $Paths) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
}
PS1
          ;;
        reload)
          cat <<'PS1'
function global:reload {
  if (Test-Path $PROFILE) { . $PROFILE } else { Write-Warning 'No $PROFILE file found.' }
}
PS1
          ;;
        v)
          cat <<'PS1'
function global:v {
  if ($env:EDITOR) { & $env:EDITOR @args; return }
  foreach ($c in 'code', 'codium', 'nvim', 'vim', 'notepad') {
    if (Get-Command $c -ErrorAction SilentlyContinue) { & $c @args; return }
  }
  Write-Warning 'No editor found. Set $env:EDITOR.'
}
PS1
          ;;
        glog)
          cat <<'PS1'
function global:glog { & git log --graph '--pretty=format:%C(auto)%h%d%x20%s%x20%C(dim)%cr%x20%C(blue)<%an>%C(reset)' --all -30 @args }
PS1
          ;;
        cd..|..)
          echo "function global:${name} { Set-Location .. }"
          ;;
        ...)
          echo "function global:${name} { Set-Location ../.. }"
          ;;
        ....)
          echo "function global:${name} { Set-Location ../../.. }"
          ;;
        *)
          local base_cmd
          base_cmd="$(guard_cmd "$cmd")"
          if is_guarded_section "$section"; then
            guarded_entries+="$name"$'\t'"$cmd"$'\n'
          elif is_powershell_always_guard_cmd "$base_cmd"; then
            guarded_entries+="$name"$'\t'"$cmd"$'\n'
          else
            local rest="${cmd#"$base_cmd"}"
            rest="${rest# }"
            if [[ -n "$rest" ]]; then
              echo "function global:${name} { & $base_cmd $rest @args }"
            else
              echo "function global:${name} { & $base_cmd @args }"
            fi
          fi
          ;;
      esac
    done < <(parse_aliases)
    if [[ -n "$guarded_entries" ]]; then
      emit_powershell_guarded_section "$guarded_entries"
    fi
  } > "$out"
}

echo "Generating alias files from $toml_file..."
generate_posix
generate_fish
generate_nushell
generate_powershell
echo "Done: shared/aliases.sh, fish/aliases.fish, nushell/aliases.nu, powershell/aliases.ps1"
