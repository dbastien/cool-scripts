# Shell-agnostic environment — sourced by all shells (bash/zsh/fish via wrapper)

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

# Better formatted man pages with bat (when available).
if command -v bat >/dev/null 2>&1; then
  export MANPAGER="sh -c 'col -bx | bat -l man -p --color=always'"
  export MANROFFOPT='-c'
fi

# Let PhotonToaster handle virtualenv prompt display
export VIRTUAL_ENV_DISABLE_PROMPT=1

# Prevent atuin from binding keys (we bind manually per-shell)
export ATUIN_NOBIND=true

# Suppress Homebrew shell-init hints
export HOMEBREW_NO_ENV_HINTS=1

# Git colors and pager without touching ~/.gitconfig
export GIT_CONFIG_COUNT=2
export GIT_CONFIG_KEY_0="color.ui"
export GIT_CONFIG_VALUE_0="always"
export GIT_CONFIG_KEY_1="core.pager"
export GIT_CONFIG_VALUE_1="delta --dark 2>/dev/null || less -FRX"

# PhotonToaster paths
export PHOTONTOASTER_CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/photontoaster"
export PHOTONTOASTER_STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/photontoaster"
export PHOTONTOASTER_QUOTES_FILE="$PHOTONTOASTER_CONFIG_DIR/quotes.txt"

# --- Color scheme -----------------------------------------------------------
# Presets are applied once at shell startup. Individual overrides in
# config.toml [colors] section take precedence over the preset.

_pt_scheme="default"
_pt_ov_blue=""
_pt_ov_violet=""
_pt_ov_ok=""
_pt_ov_err=""
_pt_ov_warn=""
_pt_ov_white=""
_pt_ov_dark=""
_pt_ov_accent=""
_pt_ov_ssh=""
_pt_ov_venv=""
_pt_ov_aws_profile=""
if [ -x "$PHOTONTOASTER_CONFIG_DIR/shared/pt-config-read" ]; then
  while IFS='=' read -r k v; do
    case "$k" in
      colors.scheme) _pt_scheme="$v" ;;
      colors.blue) _pt_ov_blue="$v" ;;
      colors.violet) _pt_ov_violet="$v" ;;
      colors.ok) _pt_ov_ok="$v" ;;
      colors.err) _pt_ov_err="$v" ;;
      colors.warn) _pt_ov_warn="$v" ;;
      colors.white) _pt_ov_white="$v" ;;
      colors.dark) _pt_ov_dark="$v" ;;
      colors.accent) _pt_ov_accent="$v" ;;
      colors.ssh) _pt_ov_ssh="$v" ;;
      colors.venv) _pt_ov_venv="$v" ;;
      aws.profile) _pt_ov_aws_profile="$v" ;;
    esac
  done <<EOF
$("$PHOTONTOASTER_CONFIG_DIR/shared/pt-config-read")
EOF
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
[ -n "$_pt_ov_blue" ] && _PT_D_BLUE="$_pt_ov_blue"
[ -n "$_pt_ov_violet" ] && _PT_D_VIOLET="$_pt_ov_violet"
[ -n "$_pt_ov_ok" ] && _PT_D_OK="$_pt_ov_ok"
[ -n "$_pt_ov_err" ] && _PT_D_ERR="$_pt_ov_err"
[ -n "$_pt_ov_warn" ] && _PT_D_WARN="$_pt_ov_warn"
[ -n "$_pt_ov_white" ] && _PT_D_WHITE="$_pt_ov_white"
[ -n "$_pt_ov_dark" ] && _PT_D_DARK="$_pt_ov_dark"
[ -n "$_pt_ov_accent" ] && _PT_D_ACCENT="$_pt_ov_accent"
[ -n "$_pt_ov_ssh" ] && _PT_D_SSH="$_pt_ov_ssh"
[ -n "$_pt_ov_venv" ] && _PT_D_VENV="$_pt_ov_venv"

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

[ -n "$_pt_ov_aws_profile" ] && export AWS_PROFILE="$_pt_ov_aws_profile"

unset _pt_scheme _pt_ov_blue _pt_ov_violet _pt_ov_ok _pt_ov_err _pt_ov_warn
unset _pt_ov_white _pt_ov_dark _pt_ov_accent _pt_ov_ssh _pt_ov_venv _pt_ov_aws_profile
unset _PT_D_BLUE _PT_D_VIOLET _PT_D_OK _PT_D_ERR
unset _PT_D_WARN _PT_D_WHITE _PT_D_DARK _PT_D_ACCENT _PT_D_SSH _PT_D_VENV

# GCC colored diagnostics
export GCC_COLORS="error=01;38;2;${PHOTONTOASTER_C_ERR}:warning=01;38;2;${PHOTONTOASTER_C_WARN}:note=01;38;2;${PHOTONTOASTER_C_ACCENT}:caret=01;38;2;${PHOTONTOASTER_C_ERR}:locus=01;38;2;140;140;160:quote=01;38;2;${PHOTONTOASTER_C_BLUE}"

# grep colors
export GREP_COLORS="ms=01;38;2;${PHOTONTOASTER_C_ERR}:mc=01;38;2;${PHOTONTOASTER_C_ERR}:fn=38;2;${PHOTONTOASTER_C_BLUE}:ln=38;2;${PHOTONTOASTER_C_ACCENT}:bn=38;2;${PHOTONTOASTER_C_ACCENT}:se=38;2;140;140;160"

# eza colors
export EZA_COLORS="da=38;2;${PHOTONTOASTER_C_ACCENT}:ur=38;2;${PHOTONTOASTER_C_BLUE}:uw=38;2;${PHOTONTOASTER_C_BLUE}:ux=38;2;${PHOTONTOASTER_C_OK}:ue=38;2;${PHOTONTOASTER_C_OK}:gr=38;2;${PHOTONTOASTER_C_WARN}:gw=38;2;${PHOTONTOASTER_C_WARN}:gx=38;2;${PHOTONTOASTER_C_WARN}:tr=38;2;${PHOTONTOASTER_C_ERR}:tw=38;2;${PHOTONTOASTER_C_ERR}:tx=38;2;${PHOTONTOASTER_C_ERR}:sn=38;2;${PHOTONTOASTER_C_ACCENT}:sb=38;2;${PHOTONTOASTER_C_ACCENT}"

# fzf theme — derives from palette
_pt_rgb_to_hex() {
  local rgb="$1" r g b
  IFS=';' read -r r g b <<EOF
$rgb
EOF
  REPLY="$(printf '%02x%02x%02x' "$r" "$g" "$b")"
}
_pt_rgb_to_hex "$PHOTONTOASTER_C_BLUE"; _pt_fzf_blue="$REPLY"
_pt_rgb_to_hex "$PHOTONTOASTER_C_ACCENT"; _pt_fzf_accent="$REPLY"
_pt_rgb_to_hex "$PHOTONTOASTER_C_DARK"; _pt_fzf_dark="$REPLY"
_pt_rgb_to_hex "$PHOTONTOASTER_C_WHITE"; _pt_fzf_white="$REPLY"
_pt_rgb_to_hex "$PHOTONTOASTER_C_WARN"; _pt_fzf_warn="$REPLY"
_pt_rgb_to_hex "$PHOTONTOASTER_C_OK"; _pt_fzf_ok="$REPLY"
export FZF_DEFAULT_OPTS="--ansi --height=40% --layout=reverse --border=rounded --color=fg:#${_pt_fzf_white},bg:-1,hl:#${_pt_fzf_accent},fg+:#${_pt_fzf_dark},bg+:#${_pt_fzf_blue},hl+:#${_pt_fzf_accent},info:#${_pt_fzf_accent},prompt:#${_pt_fzf_blue},pointer:#${_pt_fzf_warn},marker:#${_pt_fzf_ok},spinner:#${_pt_fzf_accent},header:#${_pt_fzf_accent}"
unset _pt_fzf_blue _pt_fzf_accent _pt_fzf_dark _pt_fzf_white _pt_fzf_warn _pt_fzf_ok _pt_rgb_to_hex

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
