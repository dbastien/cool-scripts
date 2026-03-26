# PhotonToaster zsh init — options, history, config parser, session startup

HISTFILE=~/.zsh_history
HISTSIZE=20000
SAVEHIST=40000

setopt auto_cd
setopt interactive_comments
setopt hist_ignore_all_dups
setopt hist_reduce_blanks
setopt share_history
setopt extended_history
setopt complete_in_word
setopt auto_menu
setopt no_beep
unsetopt correct
unsetopt correct_all
setopt list_packed
setopt auto_list
setopt auto_param_slash
setopt auto_param_keys

autoload -Uz colors add-zsh-hook
colors

# Config: delegates to shared pt-config-read, populates _pt_config associative array
typeset -gA _pt_config

if [[ -x "$PHOTONTOASTER_CONFIG_DIR/pt-config-read" ]]; then
  eval "$(
    "$PHOTONTOASTER_CONFIG_DIR/pt-config-read" |
    while IFS='=' read -r _k _v; do
      printf '_pt_config[%s]=%s\n' "$_k" "$_v"
    done
  )"
fi

# Window title hooks — only register if enabled (avoids stomping on
# Windows Terminal's profile name with an unwanted OSC 0 sequence)
if [[ "${_pt_config[prompt.show_window_title]:-false}" != "false" ]]; then
  add-zsh-hook preexec _photontoaster_preexec_title
  add-zsh-hook precmd  _photontoaster_precmd_title
fi

# Typo aliases (optional)
if [[ "${_pt_config[general.typo_aliases]:-true}" == "true" ]]; then
  alias gti='git'
  alias got='git'
  alias gi='git'
  alias sl='ls'
  alias sls='ls'
  alias lss='ls'
  alias claer='clear'
  alias clera='clear'
  alias clare='clear'
  alias cler='clear'
  alias clr='clear'
  alias grpe='grep'
  alias gerp='grep'
  alias suod='sudo'
  alias sudp='sudo'
  alias mkdri='mkdir'
  alias mkdier='mkdir'
fi

# Dynamic ls aliases based on general.ls_tool config
case "${_pt_config[general.ls_tool]:-eza}" in
  lsd)
    alias l='lsd'
    alias ls='lsd -A'
    alias la='lsd -A'
    alias ll='lsd -lAh'
    alias lla='lsd -lAh'
    alias lt='lsd --tree --depth=2'
    alias tree='lsd --tree'
    ;;
  broot)
    alias l='broot --sizes --dates --permissions'
    alias ls='broot --sizes --dates --permissions'
    alias la='broot --sizes --dates --permissions --hidden'
    alias ll='broot --sizes --dates --permissions'
    alias lla='broot --sizes --dates --permissions --hidden'
    alias lt='broot --sizes'
    alias tree='broot --sizes'
    ;;
  ls)
    alias l='ls --color=auto'
    alias ls='ls -A --color=auto'
    alias la='ls -A --color=auto'
    alias ll='ls -lAh --color=auto'
    alias lla='ls -lAh --color=auto'
    alias lt='tree -L 2'
    alias tree='tree'
    ;;
  *)
    alias l='eza'
    alias ls='eza -a'
    alias la='eza -a'
    alias ll='eza -lh'
    alias lla='eza -lah'
    alias lt='eza --tree --level=2'
    alias tree='eza --tree'
    ;;
esac

# zoxide: alias cd to z for frecency-based directory jumping
if [[ "${_pt_config[general.cd_to_z]:-true}" == "true" ]] && (( $+commands[zoxide] )); then
  alias cd='z'
fi

# Utility functions
mkcd() {
  mkdir -p -- "$1" && cd -- "$1"
}

extract() {
  [[ $# -eq 1 ]] || { echo "usage: extract <archive>"; return 2; }
  [[ -f "$1" ]] || { echo "not a file: $1"; return 1; }

  if command -v ouch >/dev/null 2>&1; then
    ouch decompress "$1"
    return $?
  fi

  case "$1" in
    *.tar.bz2|*.tbz2)     tar xjf "$1" ;;
    *.tar.gz|*.tgz)       tar xzf "$1" ;;
    *.tar.xz|*.txz)       tar xJf "$1" ;;
    *.tar.zst|*.tzst)     tar --zstd -xf "$1" ;;
    *.tar)                tar xf "$1" ;;
    *.bz2)                bunzip2 "$1" ;;
    *.gz)                 gunzip "$1" ;;
    *.xz)                 unxz "$1" ;;
    *.zip)                unzip "$1" ;;
    *.7z)                 7z x "$1" ;;
    *) echo "don't know how to extract: $1"; return 1 ;;
  esac
}

dush() {
  emulate -L zsh
  setopt local_options null_glob
  du -sh -- ./* ./.??* 2>/dev/null | sort -h
}

ndu() { command ncdu --color dark "${1:-.}"; }
jsonview() { command jq -C . "$@" | less -R; }
kg() { command kate "$@" >/dev/null 2>&1 &!; }

# Quote of the day — delegates to shared pt-quote script
_photontoaster_show_quote_of_day() {
  [[ "${_pt_config[general.quote_of_the_day]:-true}" == "true" ]] || return 0
  [[ -x "$PHOTONTOASTER_CONFIG_DIR/pt-quote" ]] || return 0
  "$PHOTONTOASTER_CONFIG_DIR/pt-quote"
}

# Startup profiling
if [[ "${_pt_config[debug.profile_startup]:-false}" == "true" ]]; then
  if [[ -n "${_PT_PROFILE_START:-}" ]]; then
    zmodload zsh/datetime 2>/dev/null
    local _end=$EPOCHREALTIME
    local _elapsed=$(( _end - _PT_PROFILE_START ))
    printf "\e[38;2;200;100;255m⏱ Shell startup: %.0fms\e[0m\n" $(( _elapsed * 1000 ))
    unset _PT_PROFILE_START
  fi
fi

# Session init (runs once per session)
if [[ -z "${PHOTONTOASTER_SESSION_INIT:-}" ]]; then
  export PHOTONTOASTER_SESSION_INIT=1

  local version_file="$PHOTONTOASTER_CONFIG_DIR/version"
  if [[ -r "$version_file" ]]; then
    local ver
    read -r ver < "$version_file"
    print "\e[38;2;${C_ACCENT}m\uF120 PhotonToaster v${ver}\e[0m"
  fi

  _photontoaster_aws_startup_login
  _photontoaster_show_quote_of_day
fi
