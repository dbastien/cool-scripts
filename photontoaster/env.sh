# Environment exports for zsh (source from ~/.zshrc after PhotonToaster paths exist).

export PATH="$HOME/.local/bin:$PATH"

# Homebrew
if [ -x /home/linuxbrew/.linuxbrew/bin/brew ]; then
  eval "$(/home/linuxbrew/.linuxbrew/bin/brew shellenv)"
elif [ -x "$HOME/.linuxbrew/bin/brew" ]; then
  eval "$("$HOME/.linuxbrew/bin/brew" shellenv)"
fi

# Editor / pager
export EDITOR=micro
export VISUAL=micro
export PAGER=less
export LESS='-FRX'
export CLICOLOR=1
export COLORTERM=truecolor

# Let PhotonToaster handle virtualenv prompt display
export VIRTUAL_ENV_DISABLE_PROMPT=1

# Prevent atuin from binding keys (we bind manually per-shell)
export ATUIN_NOBIND=true

# Suppress Homebrew shell-init hints
export HOMEBREW_NO_ENV_HINTS=1

# PhotonToaster paths
export PHOTONTOASTER_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/photontoaster"
export PHOTONTOASTER_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/photontoaster"
export PHOTONTOASTER_QUOTES_FILE="$PHOTONTOASTER_CONFIG_DIR/quotes.txt"

# --- Color scheme -----------------------------------------------------------
# Presets are applied once at shell startup. Individual overrides in
# config.toml [colors] section take precedence over the preset.

_pt_scheme="default"
if [ -x "$PHOTONTOASTER_CONFIG_DIR/pt-config-read" ]; then
  _pt_scheme_val="$("$PHOTONTOASTER_CONFIG_DIR/pt-config-read" | while IFS='=' read -r k v; do
    [ "$k" = "colors.scheme" ] && printf '%s' "$v" && break
  done)"
  [ -n "$_pt_scheme_val" ] && _pt_scheme="$_pt_scheme_val"
fi

case "$_pt_scheme" in
  catppuccin)
    _PT_D_BLUE='137;180;250'  _PT_D_VIOLET='203;166;247' _PT_D_OK='166;227;161'
    _PT_D_ERR='243;139;168'   _PT_D_WARN='249;226;175'   _PT_D_WHITE='205;214;244'
    _PT_D_DARK='30;30;46'     _PT_D_ACCENT='245;194;231'  _PT_D_SSH='250;179;135'
    _PT_D_VENV='148;226;213'
    ;;
  pastels)
    _PT_D_BLUE='162;196;255'  _PT_D_VIOLET='200;182;255' _PT_D_OK='176;228;175'
    _PT_D_ERR='255;179;186'   _PT_D_WARN='255;234;167'   _PT_D_WHITE='240;240;248'
    _PT_D_DARK='40;42;54'     _PT_D_ACCENT='255;182;225'  _PT_D_SSH='255;204;153'
    _PT_D_VENV='167;230;210'
    ;;
  solarized)
    _PT_D_BLUE='38;139;210'   _PT_D_VIOLET='108;113;196' _PT_D_OK='133;153;0'
    _PT_D_ERR='220;50;47'     _PT_D_WARN='181;137;0'     _PT_D_WHITE='238;232;213'
    _PT_D_DARK='0;43;54'      _PT_D_ACCENT='211;54;130'   _PT_D_SSH='203;75;22'
    _PT_D_VENV='42;161;152'
    ;;
  dracula)
    _PT_D_BLUE='139;233;253'  _PT_D_VIOLET='189;147;249' _PT_D_OK='80;250;123'
    _PT_D_ERR='255;85;85'     _PT_D_WARN='241;250;140'   _PT_D_WHITE='248;248;242'
    _PT_D_DARK='40;42;54'     _PT_D_ACCENT='255;121;198'  _PT_D_SSH='255;184;108'
    _PT_D_VENV='139;233;253'
    ;;
  astra)
    _PT_D_BLUE='120;170;255'  _PT_D_VIOLET='190;130;255' _PT_D_OK='100;220;140'
    _PT_D_ERR='255;80;100'    _PT_D_WARN='255;190;70'    _PT_D_WHITE='215;220;240'
    _PT_D_DARK='12;12;24'     _PT_D_ACCENT='220;100;255'  _PT_D_SSH='255;160;90'
    _PT_D_VENV='90;210;180'
    ;;
  cracktro)
    _PT_D_BLUE='0;255;255'    _PT_D_VIOLET='255;0;128'   _PT_D_OK='0;255;0'
    _PT_D_ERR='255;0;0'       _PT_D_WARN='255;255;0'     _PT_D_WHITE='255;255;255'
    _PT_D_DARK='0;0;0'        _PT_D_ACCENT='255;0;255'    _PT_D_SSH='255;128;0'
    _PT_D_VENV='0;255;128'
    ;;
  terminal)
    _PT_D_BLUE='0;120;255'    _PT_D_VIOLET='160;32;240'  _PT_D_OK='0;200;0'
    _PT_D_ERR='255;0;0'       _PT_D_WARN='255;255;0'     _PT_D_WHITE='255;255;255'
    _PT_D_DARK='0;0;0'        _PT_D_ACCENT='255;0;255'    _PT_D_SSH='255;165;0'
    _PT_D_VENV='0;128;0'
    ;;
  *)
    _PT_D_BLUE='110;155;245'  _PT_D_VIOLET='150;125;255' _PT_D_OK='80;250;120'
    _PT_D_ERR='255;90;90'     _PT_D_WARN='255;220;60'    _PT_D_WHITE='245;245;255'
    _PT_D_DARK='24;28;40'     _PT_D_ACCENT='255;100;255'  _PT_D_SSH='255;165;0'
    _PT_D_VENV='60;180;75'
    ;;
esac

# Apply individual color overrides from config.toml [colors] section
if [ -x "$PHOTONTOASTER_CONFIG_DIR/pt-config-read" ]; then
  eval "$("$PHOTONTOASTER_CONFIG_DIR/pt-config-read" | while IFS='=' read -r k v; do
    case "$k" in
      colors.blue)   printf '_PT_D_BLUE=%s\n'   "$v" ;;
      colors.violet) printf '_PT_D_VIOLET=%s\n' "$v" ;;
      colors.ok)     printf '_PT_D_OK=%s\n'     "$v" ;;
      colors.err)    printf '_PT_D_ERR=%s\n'    "$v" ;;
      colors.warn)   printf '_PT_D_WARN=%s\n'   "$v" ;;
      colors.white)  printf '_PT_D_WHITE=%s\n'  "$v" ;;
      colors.dark)   printf '_PT_D_DARK=%s\n'   "$v" ;;
      colors.accent) printf '_PT_D_ACCENT=%s\n' "$v" ;;
      colors.ssh)    printf '_PT_D_SSH=%s\n'    "$v" ;;
      colors.venv)   printf '_PT_D_VENV=%s\n'   "$v" ;;
    esac
  done)"
fi

export PHOTONTOASTER_C_BLUE="$_PT_D_BLUE"
export PHOTONTOASTER_C_VIOLET="$_PT_D_VIOLET"
export PHOTONTOASTER_C_OK="$_PT_D_OK"
export PHOTONTOASTER_C_ERR="$_PT_D_ERR"
export PHOTONTOASTER_C_WARN="$_PT_D_WARN"
export PHOTONTOASTER_C_WHITE="$_PT_D_WHITE"
export PHOTONTOASTER_C_DARK="$_PT_D_DARK"
export PHOTONTOASTER_C_ACCENT="$_PT_D_ACCENT"
export PHOTONTOASTER_C_SSH="$_PT_D_SSH"
export PHOTONTOASTER_C_VENV="$_PT_D_VENV"

unset _pt_scheme _pt_scheme_val _PT_D_BLUE _PT_D_VIOLET _PT_D_OK _PT_D_ERR
unset _PT_D_WARN _PT_D_WHITE _PT_D_DARK _PT_D_ACCENT _PT_D_SSH _PT_D_VENV

# GCC colored diagnostics
export GCC_COLORS="error=01;38;2;${PHOTONTOASTER_C_ERR}:warning=01;38;2;${PHOTONTOASTER_C_WARN}:note=01;38;2;${PHOTONTOASTER_C_ACCENT}:caret=01;38;2;${PHOTONTOASTER_C_ERR}:locus=01;38;2;140;140;160:quote=01;38;2;${PHOTONTOASTER_C_BLUE}"

# grep colors
export GREP_COLORS="ms=01;38;2;${PHOTONTOASTER_C_ERR}:mc=01;38;2;${PHOTONTOASTER_C_ERR}:fn=38;2;${PHOTONTOASTER_C_BLUE}:ln=38;2;${PHOTONTOASTER_C_ACCENT}:bn=38;2;${PHOTONTOASTER_C_ACCENT}:se=38;2;140;140;160"

# eza colors
export EZA_COLORS="da=38;2;${PHOTONTOASTER_C_ACCENT}:ur=38;2;${PHOTONTOASTER_C_BLUE}:uw=38;2;${PHOTONTOASTER_C_BLUE}:ux=38;2;${PHOTONTOASTER_C_OK}:ue=38;2;${PHOTONTOASTER_C_OK}:gr=38;2;${PHOTONTOASTER_C_WARN}:gw=38;2;${PHOTONTOASTER_C_WARN}:gx=38;2;${PHOTONTOASTER_C_WARN}:tr=38;2;${PHOTONTOASTER_C_ERR}:tw=38;2;${PHOTONTOASTER_C_ERR}:tx=38;2;${PHOTONTOASTER_C_ERR}:sn=38;2;${PHOTONTOASTER_C_ACCENT}:sb=38;2;${PHOTONTOASTER_C_ACCENT}"

# fzf theme — derives from palette
_pt_fzf_blue=$(printf '%02x%02x%02x' $(echo "$PHOTONTOASTER_C_BLUE" | tr ';' ' '))
_pt_fzf_accent=$(printf '%02x%02x%02x' $(echo "$PHOTONTOASTER_C_ACCENT" | tr ';' ' '))
_pt_fzf_dark=$(printf '%02x%02x%02x' $(echo "$PHOTONTOASTER_C_DARK" | tr ';' ' '))
_pt_fzf_white=$(printf '%02x%02x%02x' $(echo "$PHOTONTOASTER_C_WHITE" | tr ';' ' '))
_pt_fzf_warn=$(printf '%02x%02x%02x' $(echo "$PHOTONTOASTER_C_WARN" | tr ';' ' '))
_pt_fzf_ok=$(printf '%02x%02x%02x' $(echo "$PHOTONTOASTER_C_OK" | tr ';' ' '))
export FZF_DEFAULT_OPTS="--ansi --height=40% --layout=reverse --border=rounded --color=fg:#${_pt_fzf_white},bg:-1,hl:#${_pt_fzf_accent},fg+:#${_pt_fzf_dark},bg+:#${_pt_fzf_blue},hl+:#${_pt_fzf_accent},info:#${_pt_fzf_accent},prompt:#${_pt_fzf_blue},pointer:#${_pt_fzf_warn},marker:#${_pt_fzf_ok},spinner:#${_pt_fzf_accent},header:#${_pt_fzf_accent}"
unset _pt_fzf_blue _pt_fzf_accent _pt_fzf_dark _pt_fzf_white _pt_fzf_warn _pt_fzf_ok

# man page colors via less termcap
export LESS_TERMCAP_md=$'\e[1;38;2;'"${PHOTONTOASTER_C_BLUE}"'m'
export LESS_TERMCAP_me=$'\e[0m'
export LESS_TERMCAP_so=$'\e[38;2;'"${PHOTONTOASTER_C_DARK}"';48;2;'"${PHOTONTOASTER_C_ACCENT}"'m'
export LESS_TERMCAP_se=$'\e[0m'
export LESS_TERMCAP_us=$'\e[1;38;2;'"${PHOTONTOASTER_C_WARN}"'m'
export LESS_TERMCAP_ue=$'\e[0m'

# vivid LS_COLORS (if available)
if command -v vivid >/dev/null 2>&1; then
  export LS_COLORS="$(vivid generate molokai 2>/dev/null || true)"
elif command -v dircolors >/dev/null 2>&1; then
  eval "$(dircolors -b)"
fi
