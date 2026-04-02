# PhotonToaster zsh init — options, history, config parser, session startup

zmodload zsh/datetime 2>/dev/null

HISTFILE=~/.zsh_history
HISTSIZE=20000
SAVEHIST=40000

setopt auto_cd
setopt interactive_comments
setopt hist_ignore_all_dups
setopt hist_reduce_blanks
setopt hist_ignore_space
setopt hist_verify
setopt share_history
setopt extended_history
setopt inc_append_history
setopt complete_in_word
setopt auto_menu
setopt no_beep
setopt no_check_jobs
setopt no_hup
unsetopt correct
unsetopt correct_all
setopt list_packed
setopt auto_list
setopt auto_param_slash
setopt auto_param_keys

autoload -Uz add-zsh-hook
autoload -Uz edit-command-line
zle -N edit-command-line
bindkey -M emacs '^[v' edit-command-line
bindkey -M viins '^[v' edit-command-line
bindkey -M vicmd '^[v' edit-command-line

# Terminal keys: Delete, Home, End
bindkey '^[[3~' delete-char
bindkey '^[[H'  beginning-of-line
bindkey '^[[F'  end-of-line
bindkey '^[[1~' beginning-of-line
bindkey '^[[4~' end-of-line

# Config: delegates to shared pt-config-read, populates _pt_config associative array
typeset -gA _pt_config

if [[ -x "$PHOTONTOASTER_CONFIG_DIR/shared/pt-config-read" ]]; then
  eval "$(
    "$PHOTONTOASTER_CONFIG_DIR/shared/pt-config-read" |
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

# Global aliases (zsh): reduce pipeline typing.
alias -g L='| less'
alias -g G='| grep'
alias -g C='| wc -l'
alias -g H='| head'
alias -g S='| sort'
alias -g U='| uniq'
alias -g J='| jq .'
alias -g NE='2>/dev/null'

# Ctrl-Z toggle: empty buffer resumes fg, otherwise push current input.
_pt_ctrl_z_toggle() {
  if [[ $#BUFFER -eq 0 ]]; then
    BUFFER="fg"
    zle accept-line
  else
    zle push-input
    zle clear-screen
  fi
}
zle -N _pt_ctrl_z_toggle
bindkey '^Z' _pt_ctrl_z_toggle

# Double-Esc prepends sudo to current command line.
_pt_prepend_sudo() {
  [[ "$BUFFER" == sudo\ * ]] && return 0
  BUFFER="sudo $BUFFER"
  CURSOR=$(( CURSOR + 5 ))
}
zle -N _pt_prepend_sudo
bindkey '\e\e' _pt_prepend_sudo

# Dynamic ls aliases based on general.ls_tool config
case "${_pt_config[general.ls_tool]:-eza}" in
  lsd)
    alias l='lsd -lAh'
    alias ls='lsd'
    alias lsa='lsd -a'
    alias la='lsd -a'
    alias ll='lsd -lh'
    alias lla='lsd -lAh'
    alias lt='lsd --tree --depth=2'
    alias tree='lsd --tree'
    ;;
  broot)
    alias l='broot --sizes --dates --permissions'
    alias ls='broot --sizes --dates --permissions'
    alias lsa='broot --sizes --dates --permissions --hidden'
    alias la='broot --sizes --dates --permissions --hidden'
    alias ll='broot --sizes --dates --permissions'
    alias lla='broot --sizes --dates --permissions --hidden'
    alias lt='broot --sizes'
    alias tree='broot --sizes'
    ;;
  ls)
    alias l='ls -lAH --color=auto'
    alias ls='ls --color=auto'
    alias lsa='ls -a --color=auto'
    alias la='ls -a --color=auto'
    alias ll='ls -lAh --color=auto'
    alias lla='ls -lAh --color=auto'
    alias lt='tree -L 2'
    alias tree='tree'
    ;;
  *)
    alias l='eza -lah'
    alias ls='eza'
    alias lsa='eza -a'
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

# Optional auto-ls on directory change.
if [[ "${_pt_config[general.auto_ls]:-true}" == "true" ]]; then
  _pt_auto_ls() {
    eza --icons=always --group-directories-first --color=always 2>/dev/null || ls
  }
  add-zsh-hook chpwd _pt_auto_ls
fi

# Auto-activate/deactivate python venvs on cd (only when enabled and a venv segment is active).
if [[ "${_pt_config[general.auto_venv]:-true}" == "true" ]] &&
   [[ "${_pt_config[prompt.left]:-},${_pt_config[prompt.right]:-}" == *venv* ]]; then
  _pt_auto_venv() {
    if [[ -z "$VIRTUAL_ENV" ]]; then
      if [[ -f .venv/bin/activate ]]; then
        source .venv/bin/activate
      elif [[ -f venv/bin/activate ]]; then
        source venv/bin/activate
      fi
    elif [[ ! "$PWD" == "${VIRTUAL_ENV%/*}"* ]]; then
      deactivate 2>/dev/null || unset VIRTUAL_ENV
    fi
  }
  add-zsh-hook chpwd _pt_auto_venv
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

# Everything search integration (Windows Everything from WSL).
if [[ "${_pt_config[general.everything_integration]:-true}" == "true" ]]; then
  _pt_everything_cli() {
    if (( $+commands[es.exe] )); then
      print -r -- "$(command -v es.exe)"
      return 0
    fi
    local -a candidates=(
      "/mnt/c/Program Files/Everything/es.exe"
      "/mnt/c/Program Files (x86)/Everything/es.exe"
    )
    local c
    for c in "${candidates[@]}"; do
      [[ -x "$c" ]] && { print -r -- "$c"; return 0; }
    done
    return 1
  }

  fe() {
    emulate -L zsh
    local es
    es="$(_pt_everything_cli)" || {
      print -u2 "Everything CLI not found. Install Everything (es.exe) or disable general.everything_integration."
      return 1
    }
    "$es" "$@"
  }
fi

# Suffix aliases (optional): type a filename to open/process by extension.
if [[ "${_pt_config[general.suffix_aliases]:-true}" == "true" ]]; then
  alias -s json='jq -C .'
  alias -s md='glow'
  alias -s txt='bat'
  alias -s log='bat --language=log'
  alias -s csv='bat --language=csv'
  alias -s yaml='bat --language=yaml'
  alias -s yml='bat --language=yaml'
  alias -s toml='bat --language=toml'
  alias -s py="$EDITOR"
  alias -s sh="$EDITOR"
  alias -s zsh="$EDITOR"
  alias -s rs="$EDITOR"
  alias -s ts="$EDITOR"
  alias -s js="$EDITOR"
  alias -s html="$EDITOR"
  alias -s css="$EDITOR"
fi

# Clipboard helpers
if (( $+commands[xclip] )); then
  clip()  { xclip -selection clipboard; }
  paste() { xclip -selection clipboard -o; }
elif (( $+commands[xsel] )); then
  clip()  { xsel --clipboard --input; }
  paste() { xsel --clipboard --output; }
elif [[ -n "$WSL_DISTRO_NAME" ]]; then
  clip()  { clip.exe; }
  paste() { powershell.exe -NoProfile -Command Get-Clipboard | tr -d '\r'; }
elif (( $+commands[pbcopy] )); then
  clip()  { pbcopy; }
  paste() { pbpaste; }
fi

# Quote of the day — delegates to shared pt-quote script
_photontoaster_show_quote_of_day() {
  [[ "${_pt_config[general.quote_of_the_day]:-true}" == "true" ]] || return 0
  [[ -x "$PHOTONTOASTER_CONFIG_DIR/shared/pt-quote" ]] || return 0
  "$PHOTONTOASTER_CONFIG_DIR/shared/pt-quote"
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

  if [[ "${_pt_config[general.fastfetch]:-true}" == "true" ]] && (( $+commands[fastfetch] )); then
    local _pt_logo="$PHOTONTOASTER_CONFIG_DIR/logo.ansi"
    if [[ -r "$_pt_logo" ]]; then
      fastfetch --file-raw "$_pt_logo" \
        --percent-type 6 \
        --bar-char-elapsed '█' --bar-char-total '░' \
        --bar-color-elapsed '38;2;95;220;150' \
        --bar-color-total '38;2;70;70;90' \
        --color-keys '38;2;190;130;255' \
        --color-title '38;2;220;100;255' \
        --color-separator '38;2;120;170;255'
    else
      fastfetch --logo small
    fi
  fi

  if [[ "${_pt_config[general.weather]:-true}" == "true" ]] && (( $+commands[curl] )); then
    local _pt_weather_cache="$PHOTONTOASTER_STATE_DIR/weather-cache-full"
    local _pt_weather_now_cache="$PHOTONTOASTER_STATE_DIR/weather-cache-now"
    local _pt_weather_ts=0
    if [[ -r "$_pt_weather_cache" ]]; then
      IFS= read -r _pt_weather_ts < "$_pt_weather_cache"
    fi
    if (( EPOCHSECONDS - _pt_weather_ts > 3600 )); then
      local _pt_weather_data _pt_weather_now
      _pt_weather_data="$(curl -s --max-time 3 'wttr.in/?Fnq' 2>/dev/null)" || _pt_weather_data=""
      _pt_weather_now="$(curl -s --max-time 3 'wttr.in/?0qnT' 2>/dev/null)" || _pt_weather_now=""
      if [[ -n "$_pt_weather_data" || -n "$_pt_weather_now" ]]; then
        mkdir -p "$PHOTONTOASTER_STATE_DIR"
      fi
      if [[ -n "$_pt_weather_data" ]]; then
        { printf '%s\n' "$EPOCHSECONDS"; printf '%s\n' "$_pt_weather_data"; } > "$_pt_weather_cache"
      fi
      if [[ -n "$_pt_weather_now" ]]; then
        { printf '%s\n' "$EPOCHSECONDS"; printf '%s\n' "$_pt_weather_now"; } > "$_pt_weather_now_cache"
      fi
    fi

    if [[ -r "$_pt_weather_cache" ]]; then
      tail -n +2 "$_pt_weather_cache"
    elif [[ -r "$_pt_weather_now_cache" ]]; then
      tail -n +2 "$_pt_weather_now_cache"
    fi
  fi

  if typeset -f _photontoaster_aws_startup_login >/dev/null 2>&1; then
    _photontoaster_aws_startup_login
  fi
  _photontoaster_show_quote_of_day
fi
