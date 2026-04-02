# PhotonToaster bash prompt — segment-driven, theme-aware rendering
# Mirrors the zsh prompt architecture: configurable segments + theme renderers.

C_BLUE="${PHOTONTOASTER_C_BLUE:-110;155;245}"
C_VIOLET="${PHOTONTOASTER_C_VIOLET:-150;125;255}"
C_OK="${PHOTONTOASTER_C_OK:-80;250;120}"
C_ERR="${PHOTONTOASTER_C_ERR:-255;90;90}"
C_WARN="${PHOTONTOASTER_C_WARN:-255;220;60}"
C_WHITE="${PHOTONTOASTER_C_WHITE:-245;245;255}"
C_DARK="${PHOTONTOASTER_C_DARK:-24;28;40}"
C_ACCENT="${PHOTONTOASTER_C_ACCENT:-255;100;255}"
C_SSH="${PHOTONTOASTER_C_SSH:-255;165;0}"
C_VENV="${PHOTONTOASTER_C_VENV:-60;180;75}"

_pt_cap_l=$'\uE0B6'
_pt_cap_r=$'\uE0B4'
_pt_icon_user=$'\uF007'
_pt_icon_folder=$'\uF07B'
_pt_icon_home=$'\uF015'
_pt_icon_ok=$'\uF00C'
_pt_icon_err=$'\uF00D'
_pt_icon_warn=$'\uF071'
_pt_icon_git=$'\uE0A0'
_pt_icon_python=$'\uE73C'
_pt_icon_gear=$'\uF013'
_pt_icon_ssh=$'\uF0C2'
_pt_icon_clock=$'\uF017'

_pt_last_exit=0
_pt_cmd_start=0
_pt_cmd_duration=0

# Segment output: sets _seg_bg, _seg_fg, _seg_text
_pt_seg_bg="" _pt_seg_fg="" _pt_seg_text=""

_pt_seg_set() {
  _pt_seg_bg="$1"; _pt_seg_fg="$2"
  local text="$3" icon="${4:-}"
  local colored_icons="${_pt_config[prompt.colored_icons]:-false}"
  if [[ "$colored_icons" == "true" && -n "$icon" ]]; then
    local IFS=';' bg_parts=($1)
    local icon_fg="$(( (bg_parts[0] + 128) % 256 ));$(( (bg_parts[1] + 128) % 256 ));$(( (bg_parts[2] + 128) % 256 ))"
    if [[ -n "$text" ]]; then
      text="\[\e[38;2;${icon_fg}m\]${icon}\[\e[38;2;${_pt_seg_fg}m\] ${text}"
    else
      text="\[\e[38;2;${icon_fg}m\]${icon}\[\e[38;2;${_pt_seg_fg}m\]"
    fi
  elif [[ -n "$icon" && -n "$text" ]]; then
    text="${icon} ${text}"
  elif [[ -n "$icon" ]]; then
    text="$icon"
  fi
  _pt_seg_text="$text"
}

_pt_segment_user() {
  local icon="" color="$C_BLUE" label="${USER:-?}"
  local show_icon="${_pt_config[prompt.icon_user]:-true}"
  [[ "$show_icon" != "false" ]] && icon="$_pt_icon_user"
  if [[ -n "${SSH_TTY:-}" || -n "${SSH_CONNECTION:-}" ]]; then
    color="$C_SSH"; label="${USER}@${HOSTNAME%%.*}"
  fi
  _pt_seg_set "$color" "$C_DARK" "$label" "$icon"
}

_pt_segment_ssh() {
  [[ -n "${SSH_TTY:-}" || -n "${SSH_CONNECTION:-}" ]] || return 1
  _pt_seg_set "$C_SSH" "$C_DARK" "ssh" "$_pt_icon_ssh"
}

_pt_segment_path() {
  local icon="" show_icon="${_pt_config[prompt.icon_path]:-true}"
  if [[ "$show_icon" != "false" ]]; then
    [[ "$PWD" == "$HOME" ]] && icon="$_pt_icon_home" || icon="$_pt_icon_folder"
  fi
  local p="$PWD" rel prefix="" path_label out
  if [[ "$p" == "$HOME" ]]; then
    path_label='~'
  else
    if [[ "$p" == "$HOME/"* ]]; then
      prefix='~'; rel="${p#$HOME/}"
    else
      rel="${p#/}"
    fi
    if [[ -z "$rel" ]]; then
      path_label="${prefix:-/}"
    else
      local IFS='/'
      local -a parts=($rel)
      local n=${#parts[@]}
      if ((n > 2)); then
        out="${parts[n-2]}/${parts[n-1]}"
      else
        out="$rel"
      fi
      [[ "$prefix" == '~' ]] && path_label="~/$out" || path_label="/$out"
    fi
  fi
  _pt_seg_set "$C_VIOLET" "$C_DARK" "$path_label" "$icon"
}

_pt_segment_git() {
  local branch; branch="$(git rev-parse --abbrev-ref HEAD 2>/dev/null)" || return 1
  local color="$C_BLUE" label="$branch"
  if ! git diff --quiet HEAD 2>/dev/null; then
    label="${label}*"; color="$C_WARN"
  fi
  _pt_seg_set "$color" "$C_DARK" "$label" "$_pt_icon_git"
}

_pt_segment_venv() {
  [[ -n "${VIRTUAL_ENV:-}" ]] || return 1
  _pt_seg_set "$C_VENV" "$C_DARK" "${VIRTUAL_ENV##*/}" "$_pt_icon_python"
}

_pt_segment_jobs() {
  local -a job_pids
  job_pids=($(jobs -p 2>/dev/null))
  local njobs=${#job_pids[@]}
  ((njobs > 0)) || return 1
  _pt_seg_set "$C_WARN" "$C_DARK" "$njobs" "$_pt_icon_gear"
}

_pt_segment_status() {
  local code=$_pt_last_exit
  if ((code == 0)); then
    _pt_seg_set "$C_OK" "$C_DARK" "$_pt_icon_ok"
  elif ((code == 130 || code == 131 || code == 148)); then
    _pt_seg_set "$C_WARN" "$C_DARK" "$_pt_icon_warn"
  else
    _pt_seg_set "$C_ERR" "$C_WHITE" "$_pt_icon_err $code"
  fi
}

_pt_segment_duration() {
  ((_pt_cmd_duration > 0)) || return 1
  local threshold="${_pt_config[prompt.duration_threshold]:-3}"
  ((_pt_cmd_duration >= threshold)) || return 1
  local d=$_pt_cmd_duration label
  if ((d >= 3600)); then label="$((d/3600))h$((d%3600/60))m"
  elif ((d >= 60)); then label="$((d/60))m$((d%60))s"
  else label="${d}s"
  fi
  _pt_seg_set "$C_ACCENT" "$C_DARK" "$label" "$_pt_icon_clock"
}

_pt_segment_time() {
  local now
  printf -v now '%(%T)T' -1
  _pt_seg_set "$C_VIOLET" "$C_DARK" "$now"
}

_pt_render_segments() {
  local side="$1" theme="${_pt_config[prompt.style]:-pills}"
  local cfg_key="prompt.${side}"
  local default_left="user,path,git,venv,jobs"
  local default_right="status,duration,time"
  local cfg="${_pt_config[$cfg_key]:-}"
  [[ -z "$cfg" ]] && { [[ "$side" == "left" ]] && cfg="$default_left" || cfg="$default_right"; }

  local -a bgs=() fgs=() texts=()
  local IFS=',' seg
  for seg in $cfg; do
    if type -t "_pt_segment_${seg}" &>/dev/null; then
      if "_pt_segment_${seg}"; then
        bgs+=("$_pt_seg_bg"); fgs+=("$_pt_seg_fg"); texts+=("$_pt_seg_text")
      fi
    fi
  done

  local n=${#bgs[@]} i result=""
  ((n > 0)) || { REPLY=""; return; }

  case "$theme" in
    pills-merged)
      for ((i=0; i<n; i++)); do
        local bg="${bgs[$i]}" fg="${fgs[$i]}" text="${texts[$i]}"
        if ((i == 0)); then
          result+="\[\e[0m\e[38;2;${bg}m\]${_pt_cap_l}"
        fi
        result+="\[\e[0m\e[48;2;${bg}m\e[38;2;${fg}m\]"
        ((i > 0)) && result+=" "
        result+="${text}"
        ((i < n-1)) && result+=" "
        if ((i == n-1)); then
          result+="\[\e[0m\e[38;2;${bg}m\]${_pt_cap_r}\[\e[0m\]"
        fi
      done
      ;;
    plain)
      for ((i=0; i<n; i++)); do
        local bg="${bgs[$i]}" fg="${fgs[$i]}" text="${texts[$i]}"
        ((i > 0)) && result+=" "
        result+="\[\e[0m\e[48;2;${bg}m\e[38;2;${fg}m\]${text}\[\e[0m\]"
      done
      ;;
    minimal)
      for ((i=0; i<n; i++)); do
        result+="\[\e[0m\e[38;2;${bgs[$i]}m\]${texts[$i]}\[\e[0m\] "
      done
      ;;
    *)
      for ((i=0; i<n; i++)); do
        local bg="${bgs[$i]}" fg="${fgs[$i]}" text="${texts[$i]}"
        result+="\[\e[0m\e[38;2;${bg}m\]${_pt_cap_l}\[\e[48;2;${bg}m\e[38;2;${fg}m\]${text}\[\e[0m\e[38;2;${bg}m\]${_pt_cap_r}\[\e[0m\]"
      done
      ;;
  esac
  REPLY="$result"
}

_pt_preexec_trap() {
  _pt_cmd_start=$SECONDS
}
trap '_pt_preexec_trap' DEBUG

_pt_prompt_command() {
  _pt_last_exit=$?
  if ((_pt_cmd_start > 0)); then
    _pt_cmd_duration=$((SECONDS - _pt_cmd_start))
    _pt_cmd_start=0
  else
    _pt_cmd_duration=0
  fi

  local left right
  _pt_render_segments left
  left="$REPLY"
  _pt_render_segments right
  right="$REPLY"
  PS1="${left} ${right}\n\$ "
}

if [[ -n "${PS1:-}" ]]; then
  PROMPT_COMMAND="_pt_prompt_command${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
fi
