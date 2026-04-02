# PhotonToaster bash init — config loading, typo aliases, session startup

declare -A _pt_config 2>/dev/null || true

_pt_config_dir="${PHOTONTOASTER_CONFIG_DIR:-$HOME/.config/photontoaster}"

if [[ -x "$_pt_config_dir/shared/pt-config-read" ]]; then
  while IFS='=' read -r _k _v; do
    _pt_config[$_k]="$_v"
  done < <("$_pt_config_dir/shared/pt-config-read")
fi

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
if [[ "${_pt_config[general.cd_to_z]:-true}" == "true" ]] && command -v zoxide &>/dev/null; then
  alias cd='z'
fi

if [[ -z "${PHOTONTOASTER_SESSION_INIT:-}" ]]; then
  export PHOTONTOASTER_SESSION_INIT=1

  _pt_version_file="$_pt_config_dir/version"
  if [[ -r "$_pt_version_file" ]]; then
    read -r _pt_ver < "$_pt_version_file"
    printf '\033[38;2;255;100;255m\uF120 PhotonToaster v%s\033[0m\n' "$_pt_ver"
  fi

  if [[ -x "$_pt_config_dir/shared/pt-quote" ]]; then
    if [[ "${_pt_config[general.quote_of_the_day]:-true}" == "true" ]]; then
      "$_pt_config_dir/shared/pt-quote"
    fi
  fi
fi

# Auto-ls on directory change (same idea as PowerShell prompt + zsh chpwd: compare PWD each prompt).
if [[ "${_pt_config[general.auto_ls]:-true}" == "true" ]]; then
  _pt_auto_ls_run() {
    if command -v eza &>/dev/null; then
      eza --icons=always --group-directories-first --color=always 2>/dev/null || command ls -A 2>/dev/null || command ls
    else
      command ls -A --color=auto 2>/dev/null || command ls -A 2>/dev/null || command ls
    fi
  }
  _pt_auto_ls_prompt() {
    if [[ -z "${_pt_auto_ls_initialized:-}" ]]; then
      _pt_auto_ls_initialized=1
      _pt_last_pwd_auto_ls="$PWD"
      return
    fi
    if [[ "$PWD" != "$_pt_last_pwd_auto_ls" ]]; then
      _pt_last_pwd_auto_ls="$PWD"
      _pt_auto_ls_run
    fi
  }
  if [[ -n "${PROMPT_COMMAND:-}" ]]; then
    PROMPT_COMMAND="_pt_auto_ls_prompt;${PROMPT_COMMAND}"
  else
    PROMPT_COMMAND="_pt_auto_ls_prompt"
  fi
fi
