# PhotonToaster zsh prompt — segment-driven, theme-aware, zero-fork rendering

zmodload zsh/datetime 2>/dev/null

# --- Color palette ----------------------------------------------------------

typeset -g C_BLUE="${PHOTONTOASTER_C_BLUE:-110;155;245}"
typeset -g C_VIOLET="${PHOTONTOASTER_C_VIOLET:-150;125;255}"
typeset -g C_OK="${PHOTONTOASTER_C_OK:-80;250;120}"
typeset -g C_ERR="${PHOTONTOASTER_C_ERR:-255;90;90}"
typeset -g C_WARN="${PHOTONTOASTER_C_WARN:-255;220;60}"
typeset -g C_WHITE="${PHOTONTOASTER_C_WHITE:-245;245;255}"
typeset -g C_DARK="${PHOTONTOASTER_C_DARK:-24;28;40}"
typeset -g C_ACCENT="${PHOTONTOASTER_C_ACCENT:-255;100;255}"
typeset -g C_SSH="${PHOTONTOASTER_C_SSH:-255;165;0}"
typeset -g C_VENV="${PHOTONTOASTER_C_VENV:-60;180;75}"

# --- State variables --------------------------------------------------------

typeset -g _photontoaster_last_exit=0
typeset -g _pt_cmd_start=0
typeset -g _pt_cmd_duration=0
typeset -g _pt_git_branch=""
typeset -g _pt_git_dirty=0

# --- Pre-expanded glyphs ---------------------------------------------------

typeset -g _PT_ESC=$'\e'
typeset -g _PT_ROUND_L=$'\uE0B6'
typeset -g _PT_ROUND_R=$'\uE0B4'

typeset -g _PT_ICON_USER=$'\uF007'
typeset -g _PT_ICON_FOLDER=$'\uF07B'
typeset -g _PT_ICON_HOME=$'\uF015'
typeset -g _PT_ICON_OK=$'\uF00C'
typeset -g _PT_ICON_WARN=$'\uF071'
typeset -g _PT_ICON_ERR=$'\uF00D'
typeset -g _PT_ICON_GIT=$'\uE0A0'
typeset -g _PT_ICON_PYTHON=$'\uE73C'
typeset -g _PT_ICON_GEAR=$'\uF013'
typeset -g _PT_ICON_SSH=$'\uF0C2'
typeset -g _PT_ICON_CLOCK=$'\uF017'
typeset -g _PT_ICON_AWS=$'\uF0C2'

# --- Theme + colored icons --------------------------------------------------

typeset -g _PT_THEME="pills"
typeset -g _PT_COLORED_ICONS=0
_pt_apply_theme() {
  _PT_THEME="${_pt_config[prompt.style]:-pills}"
  [[ "${_pt_config[prompt.colored_icons]:-false}" == "true" ]] && _PT_COLORED_ICONS=1 || _PT_COLORED_ICONS=0
}

(( ${+_pt_config} )) && _pt_apply_theme

# --- Segment data output ----------------------------------------------------
# Segment functions set these globals then return 0 (show) or 1 (hide).

typeset -g _PT_SEG_BG _PT_SEG_FG _PT_SEG_DISPLAY

_pt_seg_set() {
  local bg="$1" fg="$2" text="$3" icon="${4:-}"
  text="${text//\%/%%}"
  if (( _PT_COLORED_ICONS )) && [[ -n "$icon" ]]; then
    local r1=${bg%%;*} rest="${bg#*;}" g1=${rest%%;*} b1=${rest#*;}
    local icon_fg="$(( (r1 + 128) % 256 ));$(( (g1 + 128) % 256 ));$(( (b1 + 128) % 256 ))"
    if [[ -n "$text" ]]; then
      text="%{${_PT_ESC}[38;2;${icon_fg}m%}${icon}%{${_PT_ESC}[38;2;${fg}m%} ${text}"
    else
      text="%{${_PT_ESC}[38;2;${icon_fg}m%}${icon}%{${_PT_ESC}[38;2;${fg}m%}"
    fi
  elif [[ -n "$icon" && -n "$text" ]]; then
    text="${icon} ${text}"
  elif [[ -n "$icon" ]]; then
    text="${icon}"
  fi
  _PT_SEG_BG="$bg"
  _PT_SEG_FG="$fg"
  _PT_SEG_DISPLAY="$text"
}

# --- Git info ---------------------------------------------------------------

_pt_update_git_info() {
  _pt_git_branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" || {
    _pt_git_branch=""
    _pt_git_dirty=0
    return 1
  }
  git diff --quiet HEAD 2>/dev/null
  _pt_git_dirty=$?
}

# --- Segment functions ------------------------------------------------------

_pt_segment_user() {
  local icon=""
  if (( ! ${+_pt_config} )) || [[ "${_pt_config[prompt.icon_user]:-true}" != "false" ]]; then
    icon="$_PT_ICON_USER"
  fi
  local color="$C_BLUE" label="${USER}"
  if [[ -n "$SSH_TTY" || -n "$SSH_CONNECTION" ]]; then
    color="$C_SSH"
    label="${USER}@${HOST%%.*}"
  fi
  _pt_seg_set "$color" "$C_DARK" "$label" "$icon"
}

_pt_segment_ssh() {
  [[ -n "$SSH_TTY" || -n "$SSH_CONNECTION" ]] || return 1
  _pt_seg_set "$C_SSH" "$C_DARK" "ssh" "$_PT_ICON_SSH"
}

_pt_segment_path() {
  local icon=""
  if (( ! ${+_pt_config} )) || [[ "${_pt_config[prompt.icon_path]:-true}" != "false" ]]; then
    if [[ "$PWD" == "$HOME" ]]; then
      icon="$_PT_ICON_HOME"
    else
      icon="$_PT_ICON_FOLDER"
    fi
  fi
  local collapsed="${PWD/#$HOME/~}" path_label
  if [[ "$collapsed" == "~" ]]; then
    path_label="~"
  else
    local -a parts
    parts=(${(s:/:)collapsed})
    if (( ${#parts[@]} <= 3 )); then
      path_label="$collapsed"
    elif [[ "$collapsed" == ~/* ]]; then
      path_label="~/${parts[-2]}/${parts[-1]}"
    else
      path_label="${parts[-2]}/${parts[-1]}"
    fi
  fi
  _pt_seg_set "$C_VIOLET" "$C_DARK" "$path_label" "$icon"
}

_pt_segment_git() {
  [[ -n "$_pt_git_branch" ]] || return 1
  local label="$_pt_git_branch" color="$C_BLUE"
  if (( _pt_git_dirty )); then
    label="${label}*"
    color="$C_WARN"
  fi
  _pt_seg_set "$color" "$C_DARK" "$label" "$_PT_ICON_GIT"
}

_pt_segment_git-short() {
  [[ -n "$_pt_git_branch" ]] || return 1
  local color="$C_BLUE"
  (( _pt_git_dirty )) && color="$C_WARN"
  _pt_seg_set "$color" "$C_DARK" "" "$_PT_ICON_GIT"
}

_pt_segment_venv() {
  [[ -n "$VIRTUAL_ENV" ]] || return 1
  _pt_seg_set "$C_VENV" "$C_DARK" "${VIRTUAL_ENV:t}" "$_PT_ICON_PYTHON"
}

_pt_segment_venv-short() {
  [[ -n "$VIRTUAL_ENV" ]] || return 1
  _pt_seg_set "$C_VENV" "$C_DARK" "" "$_PT_ICON_PYTHON"
}

_pt_segment_jobs() {
  local njobs=${#jobstates}
  (( njobs > 0 )) || return 1
  _pt_seg_set "$C_WARN" "$C_DARK" "$njobs" "$_PT_ICON_GEAR"
}

_pt_segment_status() {
  local code=$_photontoaster_last_exit
  if (( code == 0 )); then
    _pt_seg_set "$C_OK" "$C_DARK" "$_PT_ICON_OK"
  elif (( code == 130 || code == 131 || code == 148 )); then
    _pt_seg_set "$C_WARN" "$C_DARK" "$_PT_ICON_WARN"
  else
    _pt_seg_set "$C_ERR" "$C_WHITE" "$_PT_ICON_ERR $code"
  fi
}

_pt_segment_aws() {
  command -v aws >/dev/null 2>&1 || return 1
  local profile="${AWS_PROFILE:-default}"
  if typeset -f _photontoaster_aws_prompt_connected >/dev/null 2>&1 &&
     _photontoaster_aws_prompt_connected; then
    _pt_seg_set "$C_OK" "$C_DARK" "$profile" "$_PT_ICON_AWS"
  else
    _pt_seg_set "$C_ERR" "$C_WHITE" "$profile" "$_PT_ICON_AWS"
  fi
}

_pt_segment_aws-short() {
  command -v aws >/dev/null 2>&1 || return 1
  if typeset -f _photontoaster_aws_prompt_connected >/dev/null 2>&1 &&
     _photontoaster_aws_prompt_connected; then
    _pt_seg_set "$C_OK" "$C_DARK" "" "$_PT_ICON_AWS"
  else
    _pt_seg_set "$C_ERR" "$C_WHITE" "" "$_PT_ICON_AWS"
  fi
}

_pt_segment_duration() {
  (( _pt_cmd_duration > 0 )) || return 1
  local threshold="${_pt_config[prompt.duration_threshold]:-3}"
  (( _pt_cmd_duration >= threshold )) || return 1
  local d=$_pt_cmd_duration label
  if (( d >= 3600 )); then
    label="$((d / 3600))h$((d % 3600 / 60))m"
  elif (( d >= 60 )); then
    label="$((d / 60))m$((d % 60))s"
  else
    label="${d}s"
  fi
  _pt_seg_set "$C_ACCENT" "$C_DARK" "$label" "$_PT_ICON_CLOCK"
}

_pt_segment_time() {
  _pt_seg_set "$C_VIOLET" "$C_DARK" "${(%):-%*}"
}

_pt_segment_time-short() {
  local _ts
  print -v _ts -P '%D{%H:%M}'
  _pt_seg_set "$C_VIOLET" "$C_DARK" "$_ts"
}

# --- Renderers --------------------------------------------------------------
# !! PILL SPACING CONTRACT (pills-merged) !!
#
# Each segment gets:
#   - A TRAILING space when i < n  (on the OUTGOING segment's bg color)
#   - A LEADING space when i > 1   (on the INCOMING segment's bg color)
#
# This creates a double-width colored gap between adjacent segments:
#   ...text1(space on bg1)(space on bg2)text2(space on bg2)(space on bg3)text3...
#
# Endcaps are TIGHT — NO space between (L) and first text, NO space
# between last text and (R).  i==1 skips leading; i==n skips trailing.
#
# Visual result:  (L)text1  text2  text3(R)
#                     ^^gap^^  ^^gap^^
#
# DO NOT REMOVE the (( i > 1 )) leading space. It is the only thing that
# puts a visible gap on the NEW segment's background before its content.
#
_pt_render_left() {
  local n=${#_pt_l_bgs[@]}
  (( n > 0 )) || { REPLY=""; return; }
  local result="" i bg fg text

  case "$_PT_THEME" in
    pills-merged)
      for (( i=1; i<=n; i++ )); do
        bg="${_pt_l_bgs[$i]}" fg="${_pt_l_fgs[$i]}" text="${_pt_l_displays[$i]}"
        if (( i == 1 )); then
          result+="%{${_PT_ESC}[0m${_PT_ESC}[38;2;${bg}m%}${_PT_ROUND_L}"
        fi
        result+="%{${_PT_ESC}[0m${_PT_ESC}[48;2;${bg}m${_PT_ESC}[38;2;${fg}m%}"
        (( i > 1 )) && result+=" "
        result+="${text}"
        (( i < n )) && result+=" "
        if (( i == n )); then
          result+="%{${_PT_ESC}[0m${_PT_ESC}[38;2;${bg}m%}${_PT_ROUND_R}%{${_PT_ESC}[0m%}"
        fi
      done
      ;;
    plain)
      for (( i=1; i<=n; i++ )); do
        bg="${_pt_l_bgs[$i]}" fg="${_pt_l_fgs[$i]}" text="${_pt_l_displays[$i]}"
        (( i > 1 )) && result+=" "
        result+="%{${_PT_ESC}[0m${_PT_ESC}[48;2;${bg}m${_PT_ESC}[38;2;${fg}m%}${text}%{${_PT_ESC}[0m%}"
      done
      ;;
    minimal)
      for (( i=1; i<=n; i++ )); do
        result+="%{${_PT_ESC}[0m${_PT_ESC}[38;2;${_pt_l_bgs[$i]}m%}${_pt_l_displays[$i]}%{${_PT_ESC}[0m%} "
      done
      ;;
    *)
      for (( i=1; i<=n; i++ )); do
        bg="${_pt_l_bgs[$i]}" fg="${_pt_l_fgs[$i]}" text="${_pt_l_displays[$i]}"
        result+="%{${_PT_ESC}[0m${_PT_ESC}[38;2;${bg}m%}${_PT_ROUND_L}%{${_PT_ESC}[48;2;${bg}m${_PT_ESC}[38;2;${fg}m%}${text}%{${_PT_ESC}[0m${_PT_ESC}[38;2;${bg}m%}${_PT_ROUND_R}%{${_PT_ESC}[0m%}"
      done
      ;;
  esac
  REPLY="$result"
}

_pt_render_right() {
  local n=${#_pt_r_bgs[@]}
  (( n > 0 )) || { REPLY=""; return; }
  local result="" i bg fg text

  case "$_PT_THEME" in
    pills-merged)
      for (( i=1; i<=n; i++ )); do
        bg="${_pt_r_bgs[$i]}" fg="${_pt_r_fgs[$i]}" text="${_pt_r_displays[$i]}"
        if (( i == 1 )); then
          result+="%{${_PT_ESC}[0m${_PT_ESC}[38;2;${bg}m%}${_PT_ROUND_L}"
        fi
        result+="%{${_PT_ESC}[0m${_PT_ESC}[48;2;${bg}m${_PT_ESC}[38;2;${fg}m%}"
        (( i > 1 )) && result+=" "
        result+="${text}"
        (( i < n )) && result+=" "
        if (( i == n )); then
          result+="%{${_PT_ESC}[0m${_PT_ESC}[38;2;${bg}m%}${_PT_ROUND_R}%{${_PT_ESC}[0m%}"
        fi
      done
      ;;
    plain)
      for (( i=1; i<=n; i++ )); do
        bg="${_pt_r_bgs[$i]}" fg="${_pt_r_fgs[$i]}" text="${_pt_r_displays[$i]}"
        (( i > 1 )) && result+=" "
        result+="%{${_PT_ESC}[0m${_PT_ESC}[48;2;${bg}m${_PT_ESC}[38;2;${fg}m%}${text}%{${_PT_ESC}[0m%}"
      done
      ;;
    minimal)
      for (( i=1; i<=n; i++ )); do
        result+="%{${_PT_ESC}[0m${_PT_ESC}[38;2;${_pt_r_bgs[$i]}m%}${_pt_r_displays[$i]}%{${_PT_ESC}[0m%} "
      done
      ;;
    *)
      for (( i=1; i<=n; i++ )); do
        bg="${_pt_r_bgs[$i]}" fg="${_pt_r_fgs[$i]}" text="${_pt_r_displays[$i]}"
        result+="%{${_PT_ESC}[0m${_PT_ESC}[38;2;${bg}m%}${_PT_ROUND_L}%{${_PT_ESC}[48;2;${bg}m${_PT_ESC}[38;2;${fg}m%}${text}%{${_PT_ESC}[0m${_PT_ESC}[38;2;${bg}m%}${_PT_ROUND_R}%{${_PT_ESC}[0m%}"
      done
      ;;
  esac
  REPLY="$result"
}

# --- Prompt builder (precmd) ------------------------------------------------

_photontoaster_precmd_prompt() {
  emulate -L zsh

  if (( _pt_cmd_start > 0 )); then
    _pt_cmd_duration=$(( EPOCHSECONDS - _pt_cmd_start ))
    _pt_cmd_start=0
  else
    _pt_cmd_duration=0
  fi

  local preset="${_pt_config[prompt.preset]:-balanced}"
  local left_default="user,path,git,venv,jobs"
  local right_default="status,duration,time"
  case "$preset" in
    minimal)
      left_default="path,git-short"
      right_default="status,time-short"
      ;;
    maximal)
      left_default="aws-short,ssh,user,path,git,venv,jobs"
      right_default="status,duration,time"
      ;;
  esac

  local left_cfg="${_pt_config[prompt.left]:-$left_default}"
  local right_cfg="${_pt_config[prompt.right]:-$right_default}"

  # Only fork for git info when the git segment is actually configured
  if [[ "$left_cfg" == *git* || "$right_cfg" == *git* ]]; then
    _pt_update_git_info
  else
    _pt_git_branch=""
    _pt_git_dirty=0
  fi

  local -a _pt_l_bgs _pt_l_fgs _pt_l_displays
  local seg
  for seg in ${(s:,:)left_cfg}; do
    if typeset -f "_pt_segment_${seg}" >/dev/null 2>&1; then
      if "_pt_segment_${seg}"; then
        _pt_l_bgs+=("$_PT_SEG_BG")
        _pt_l_fgs+=("$_PT_SEG_FG")
        _pt_l_displays+=("$_PT_SEG_DISPLAY")
      fi
    fi
  done

  local -a _pt_r_bgs _pt_r_fgs _pt_r_displays
  for seg in ${(s:,:)right_cfg}; do
    if typeset -f "_pt_segment_${seg}" >/dev/null 2>&1; then
      if "_pt_segment_${seg}"; then
        _pt_r_bgs+=("$_PT_SEG_BG")
        _pt_r_fgs+=("$_PT_SEG_FG")
        _pt_r_displays+=("$_PT_SEG_DISPLAY")
      fi
    fi
  done

  _pt_render_left
  PROMPT="${REPLY} "

  if (( ! ${+_pt_config} )) || [[ "${_pt_config[prompt.show_rprompt]:-true}" != "false" ]]; then
    _pt_render_right
    RPROMPT="$REPLY"
  else
    RPROMPT=""
  fi
}

# --- Preexec for duration ---------------------------------------------------

_photontoaster_preexec_duration() {
  _pt_cmd_start=$EPOCHSECONDS
}

# --- Register hooks ---------------------------------------------------------

autoload -Uz add-zsh-hook
add-zsh-hook precmd  _photontoaster_precmd_prompt
add-zsh-hook preexec _photontoaster_preexec_duration

setopt prompt_subst
PROMPT_EOL_MARK=""
ZLE_RPROMPT_INDENT=0
