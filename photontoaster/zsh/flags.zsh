# PhotonToaster flag highlighter + intellisense
# Single-pass module: validates flags, colors valid/invalid, shows descriptions.
# Integrates with zsh-syntax-highlighting when available, falls back to line-pre-redraw.

autoload -Uz add-zle-hook-widget

typeset -gA _pt_flag_specs
typeset -gA _pt_flag_checked
typeset -gA _pt_flag_descs
typeset -gA _pt_desc_loaded
typeset -ga _pt_good_flag_ranges
typeset -ga _pt_bad_flag_ranges
typeset -g  _pt_cursor_flag_desc=""
typeset -g  _pt_flag_cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/photontoaster/flags"
typeset -g  _pt_flag_scan_seq=""

_pt_flag_specs=(
  rg '--help --version -h -V -e -f -i -S -s -w -x -v -n -N -H --line-number --no-line-number --with-filename --no-filename --color --colors --glob -g --iglob --hidden --no-ignore -u -t --type -T --type-not -A -B -C -m --max-count -l --files-with-matches -c --count --stats --json --pcre2 -P --multiline -U'
  fd '--help --version -H -I -u -L -a -0 -l -x -X -e -E -t -d --hidden --no-ignore --follow --absolute-path --print0 --list-details --exec --exec-batch --extension --exclude --type --max-depth'
  curl '--help --version -I -i -L -s -S -f -o -O -H -A -X -d -F -u -k -v --head --include --location --silent --show-error --fail --output --remote-name --header --user-agent --request --data --form --user --insecure --verbose --connect-timeout --max-time --retry'
  bat '--help --version -n -p -A -l -r -L -f --style --paging --color --theme --language --line-range --highlight-line --plain --number --show-all'
  eza '--help --version -a -l -h -T -R -L -s -r -x --all --long --header --tree --recurse --level --sort --reverse --across --group-directories-first --icons --color'
  ls '--help -a -A -l -h -R -d -t -r -S -1 --all --almost-all --long --human-readable --recursive --directory --sort'
)

local _pt_compiled="${_pt_flag_cache_dir}/flags-compiled.zsh"
if [[ -r "$_pt_compiled" ]]; then
  source "$_pt_compiled"
fi
unset _pt_compiled

_pt_is_simple_line() {
  [[ "$BUFFER" == *$'\n'* ]] && return 1
  [[ "$BUFFER" == *'|'* ]] && return 1
  [[ "$BUFFER" == *';'* ]] && return 1
  [[ "$BUFFER" == *'&&'* ]] && return 1
  [[ "$BUFFER" == *'||'* ]] && return 1
  [[ "$BUFFER" == *'<'* ]] && return 1
  [[ "$BUFFER" == *'>'* ]] && return 1
  [[ "$BUFFER" == *'$('* ]] && return 1
  [[ "$BUFFER" == *'`'* ]] && return 1
  return 0
}

_pt_flag_known() {
  local cmd="$1" flag="$2" spec
  spec=" ${_pt_flag_specs[$cmd]:-} "
  [[ -n "${_pt_flag_specs[$cmd]:-}" ]] || return 1

  if [[ "$flag" == --* ]]; then
    local long="${flag%%=*}"
    [[ "$spec" == *" $long "* ]]
    return
  fi

  if [[ "$flag" == -[A-Za-z] && "$spec" == *" $flag "* ]]; then
    return 0
  fi

  if [[ "$flag" == -[A-Za-z][A-Za-z]* ]]; then
    local i short
    for (( i = 2; i <= ${#flag}; i++ )); do
      short="-${flag[i]}"
      [[ "$spec" == *" $short "* ]] || return 1
    done
    return 0
  fi

  if [[ "$flag" == -[A-Za-z][0-9]## ]]; then
    local head="-${flag[2]}"
    [[ "$spec" == *" $head "* ]]
    return
  fi

  return 1
}

_pt_merge_flag_spec() {
  local cmd="$1" extra="$2" tok existing
  existing="${_pt_flag_specs[$cmd]:-}"
  typeset -A seen
  local -a merged
  for tok in ${=existing} ${=extra}; do
    [[ "$tok" == -* ]] || continue
    [[ -n "${seen[$tok]:-}" ]] && continue
    seen[$tok]=1
    merged+=("$tok")
  done
  _pt_flag_specs[$cmd]="${(j: :)merged}"
}

_pt_extract_flags_from_text() {
  awk '
    {
      gsub(/[(),\[\]]/, " ", $0)
      for (i = 1; i <= NF; i++) {
        token = $i
        sub(/[:;,]+$/, "", token)
        if (token ~ /^--[A-Za-z0-9][A-Za-z0-9-]*(=.*)?$/) {
          sub(/=.*/, "", token)
          print token
        } else if (token ~ /^-[A-Za-z0-9]$/) {
          print token
        }
      }
    }
  ' | sort -u | tr '\n' ' '
}

_pt_cache_key() {
  local cmd="$1" bin_path
  bin_path="${commands[$cmd]:-$cmd}"
  local hash="${$(printf '%s' "$bin_path" | cksum)%% *}"
  printf '%s_%s' "$cmd" "$hash"
}

_pt_refresh_flag_spec_cache() {
  local cmd="$1" out flags cache_file key
  key="$(_pt_cache_key "$cmd")"
  cache_file="${_pt_flag_cache_dir}/${key}.flags"
  out="$("$cmd" --help 2>/dev/null)" || out=""
  if [[ -z "$out" ]] && (( $+commands[man] )); then
    out="$(MANPAGER=cat man "$cmd" 2>/dev/null | col -bx 2>/dev/null)" || out=""
  fi
  [[ -n "$out" ]] || return 1
  flags="$(printf '%s\n' "$out" | _pt_extract_flags_from_text)"
  [[ -n "$flags" ]] || return 1
  mkdir -p "$_pt_flag_cache_dir" 2>/dev/null || true
  {
    printf '%s\n' "$EPOCHSECONDS"
    printf '%s\n' "$flags"
  } > "$cache_file" 2>/dev/null || true
  _pt_merge_flag_spec "$cmd" "$flags"
  return 0
}

_pt_load_flag_spec_cache() {
  local cmd="$1" cache_file bin_path flags key
  key="$(_pt_cache_key "$cmd")"
  cache_file="${_pt_flag_cache_dir}/${key}.flags"
  [[ -r "$cache_file" ]] || return 1
  bin_path="${commands[$cmd]:-}"
  [[ -z "$bin_path" || ! "$bin_path" -nt "$cache_file" ]] || return 1
  flags="$(tail -n +2 "$cache_file" 2>/dev/null | tr '\n' ' ')"
  [[ -n "$flags" ]] || return 1
  _pt_merge_flag_spec "$cmd" "$flags"
  return 0
}

_pt_maybe_autolearn_flags() {
  local cmd="$1"
  [[ "${_pt_config[general.flag_autolearn]:-true}" == "true" ]] || return 0
  [[ -n "${_pt_flag_checked[$cmd]:-}" ]] && return 0
  _pt_flag_checked[$cmd]=1
  (( $+commands[$cmd] )) || return 0
  _pt_load_flag_spec_cache "$cmd" && return 0
  _pt_refresh_flag_spec_cache "$cmd" >/dev/null 2>&1 || true
}

_pt_load_desc_file() {
  local cmd="$1" desc_file bin_path key line flag desc
  [[ -n "${_pt_desc_loaded[$cmd]:-}" ]] && return 0
  _pt_desc_loaded[$cmd]=1
  key="$(_pt_cache_key "$cmd")"
  desc_file="${_pt_flag_cache_dir}/${key}.desc"
  if [[ ! -r "$desc_file" ]]; then
    desc_file="${_pt_flag_cache_dir}/${cmd}.desc"
  fi
  [[ -r "$desc_file" ]] || return 1
  bin_path="${commands[$cmd]:-}"
  if [[ -n "$bin_path" && "$bin_path" -nt "$desc_file" ]]; then
    return 1
  fi
  while IFS=$'\t' read -r flag desc; do
    [[ -n "$flag" && -n "$desc" ]] || continue
    _pt_flag_descs[${cmd}:${flag}]="$desc"
  done < "$desc_file"
  return 0
}

# --- Single-pass scanner ---

_pt_flag_scan() {
  [[ "${_pt_config[general.flag_highlight]:-true}" == "true" ]] || return 1

  local seq="${BUFFER}:${CURSOR}"
  if [[ "$seq" == "$_pt_flag_scan_seq" ]]; then
    return 0
  fi
  _pt_flag_scan_seq="$seq"

  _pt_good_flag_ranges=()
  _pt_bad_flag_ranges=()
  _pt_cursor_flag_desc=""

  _pt_is_simple_line || return 1

  local -a words
  words=(${(z)BUFFER})
  (( ${#words} > 0 )) || return 1

  local -a starts ends
  local scan_pos=1 w rest prefix start end
  for w in "${words[@]}"; do
    rest="${BUFFER[scan_pos,-1]}"
    [[ -n "$rest" ]] || break
    [[ "$rest" == *"$w"* ]] || continue
    prefix="${rest%%$w*}"
    start=$(( scan_pos + ${#prefix} ))
    end=$(( start + ${#w} - 1 ))
    starts+=("$start")
    ends+=("$end")
    scan_pos=$(( end + 1 ))
  done

  local cmd="${words[1]}"
  local cmd_index=1
  while [[ "$cmd" == [A-Za-z_][A-Za-z0-9_]*=* ]] && (( cmd_index < ${#words} )); do
    (( cmd_index++ ))
    cmd="${words[$cmd_index]}"
  done
  cmd="${cmd:t}"

  (( $+commands[$cmd] )) || return 1
  _pt_maybe_autolearn_flags "$cmd"
  [[ -n "${_pt_flag_specs[$cmd]:-}" ]] || return 1
  _pt_load_desc_file "$cmd"

  local i
  for (( i = cmd_index + 1; i <= ${#words}; i++ )); do
    w="${words[i]}"
    [[ "$w" == "--" ]] && break
    [[ "$w" == "-" ]] && continue
    [[ "$w" == -[0-9]* ]] && continue
    [[ "$w" == -* ]] || continue
    (( i <= ${#starts} )) || continue

    local range="$(( starts[i] - 1 )) ${ends[i]}"

    if _pt_flag_known "$cmd" "$w"; then
      _pt_good_flag_ranges+=("$range")
    else
      _pt_bad_flag_ranges+=("$range")
    fi

    if (( CURSOR + 1 >= starts[i] && CURSOR + 1 <= ends[i] + 1 )); then
      local lookup="${w%%=*}"
      _pt_cursor_flag_desc="${_pt_flag_descs[${cmd}:${lookup}]:-}"
      if [[ -n "$_pt_cursor_flag_desc" ]]; then
        _pt_cursor_flag_desc=" ${lookup}  ${_pt_cursor_flag_desc}"
      fi
    fi
  done

  return 0
}

# --- zsh-syntax-highlighting custom highlighter ---

_zsh_highlight_highlighter_pt_flag_predicate() {
  return 0
}

_zsh_highlight_highlighter_pt_flag_paint() {
  _pt_flag_scan || return 0

  local range
  for range in "${_pt_good_flag_ranges[@]}"; do
    region_highlight+=("${range} fg=78,bold")
  done
  for range in "${_pt_bad_flag_ranges[@]}"; do
    region_highlight+=("${range} fg=196,bold,underline")
  done
}

# --- Fallback highlighter (when zsh-syntax-highlighting not loaded) ---

_pt_flag_highlight_fallback() {
  local -a keep
  local item
  for item in "${region_highlight[@]}"; do
    [[ "$item" == *"memo=pt-flag"* ]] || keep+=("$item")
  done
  region_highlight=("${keep[@]}")

  _pt_flag_scan || return 0

  local range
  for range in "${_pt_good_flag_ranges[@]}"; do
    region_highlight+=("${range} fg=78,bold memo=pt-flag")
  done
  for range in "${_pt_bad_flag_ranges[@]}"; do
    region_highlight+=("${range} fg=196,bold,underline memo=pt-flag")
  done
}

# --- Intellisense popup ---

_pt_flag_intellisense() {
  _pt_flag_scan || { zle -M ""; return 0; }

  if [[ -n "$_pt_cursor_flag_desc" ]]; then
    zle -M "$_pt_cursor_flag_desc"
  else
    zle -M ""
  fi
}

add-zle-hook-widget line-pre-redraw _pt_flag_intellisense

# Use fallback highlighter only if zsh-syntax-highlighting won't handle it.
# The pt_flag highlighter is pre-registered in integrations.zsh via
# ZSH_HIGHLIGHT_HIGHLIGHTERS before zsh-syntax-highlighting loads.
if ! (( ${+functions[_zsh_highlight]} )) && [[ " ${ZSH_HIGHLIGHT_HIGHLIGHTERS[*]} " != *" pt_flag "* ]]; then
  add-zle-hook-widget line-pre-redraw _pt_flag_highlight_fallback
fi
