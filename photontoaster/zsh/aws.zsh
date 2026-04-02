# PhotonToaster AWS SSO helpers for zsh

awsp() {
  print -r -- "${AWS_PROFILE:-default}"
}

_photontoaster_aws_stamp_file() {
  local profile="${AWS_PROFILE:-default}"
  mkdir -p "$PHOTONTOASTER_STATE_DIR"
  print -r -- "$PHOTONTOASTER_STATE_DIR/aws-sso-${profile}.stamp"
}

_photontoaster_aws_profile_has_sso() {
  [[ -f "$HOME/.aws/config" ]] || return 1

  local profile="${AWS_PROFILE:-default}"
  local header

  if [[ "$profile" == "default" ]]; then
    header='[default]'
  else
    header="[profile ${profile}]"
  fi

  awk -v header="$header" '
    $0 == header { in_section = 1; next }
    in_section && /^\[/ { exit }
    in_section && $1 ~ /^(sso_session|sso_start_url)$/ { found = 1; exit }
    END { exit !found }
  ' "$HOME/.aws/config"
}

awsl() {
  local profile="${AWS_PROFILE:-default}"
  if command aws sso login --profile "$profile" "$@"; then
    print -r -- "$EPOCHSECONDS" > "$(_photontoaster_aws_stamp_file)"
  fi
}

awswho() {
  command aws sts get-caller-identity --profile "${AWS_PROFILE:-default}" "$@"
}

typeset -g _pt_aws_prompt_connected=-1
typeset -g _pt_aws_prompt_checked_at=0
typeset -g _pt_aws_prompt_profile=""

_photontoaster_aws_prompt_status_file() {
  mkdir -p "$PHOTONTOASTER_STATE_DIR"
  print -r -- "$PHOTONTOASTER_STATE_DIR/aws-prompt-status"
}

_photontoaster_aws_prompt_status_ttl() {
  local ttl="${_pt_config[aws.prompt_status_interval_seconds]:-21600}"
  (( ttl > 0 )) || ttl=21600
  print -r -- "$ttl"
}

_photontoaster_aws_probe_connected() {
  command aws sts get-caller-identity --profile "${AWS_PROFILE:-default}" >/dev/null 2>&1
}

_photontoaster_aws_refresh_prompt_status() {
  local now=$EPOCHSECONDS
  local profile="${AWS_PROFILE:-default}"
  local ttl
  ttl="$(_photontoaster_aws_prompt_status_ttl)"

  if (( _pt_aws_prompt_checked_at > 0 )) &&
     [[ "$_pt_aws_prompt_profile" == "$profile" ]] &&
     (( now - _pt_aws_prompt_checked_at <= ttl )); then
    return 0
  fi

  local cache_file
  cache_file="$(_photontoaster_aws_prompt_status_file)"

  if [[ -r "$cache_file" ]]; then
    local cached_ts=0 cached_profile="" cached_status=0
    IFS=' ' read -r cached_ts cached_profile cached_status < "$cache_file" || true
    if [[ "$cached_profile" == "$profile" ]] &&
       (( now - cached_ts <= ttl )) &&
       [[ "$cached_status" == "0" || "$cached_status" == "1" ]]; then
      _pt_aws_prompt_checked_at=$cached_ts
      _pt_aws_prompt_profile="$cached_profile"
      _pt_aws_prompt_connected=$cached_status
      return 0
    fi
  fi

  local connected=0
  if command -v aws >/dev/null 2>&1 && _photontoaster_aws_probe_connected; then
    connected=1
  fi

  _pt_aws_prompt_checked_at=$now
  _pt_aws_prompt_profile="$profile"
  _pt_aws_prompt_connected=$connected

  print -r -- "${now} ${profile} ${connected}" > "$cache_file" 2>/dev/null || true
}

_photontoaster_aws_prompt_connected() {
  _photontoaster_aws_refresh_prompt_status
  (( _pt_aws_prompt_connected == 1 ))
}

_photontoaster_aws_startup_login() {
  [[ "${_pt_config[aws.auto_login]:-true}" == "true" ]] || return 0
  command -v aws >/dev/null 2>&1 || return 0
  _photontoaster_aws_profile_has_sso || return 0

  local stamp_file last_check=0
  local interval_hours="${_pt_config[aws.auto_login_interval_hours]:-8}"
  local interval_seconds=$(( interval_hours * 3600 ))

  stamp_file="$(_photontoaster_aws_stamp_file)"

  if [[ -f "$stamp_file" ]]; then
    read -r last_check < "$stamp_file" || last_check=0
  fi

  if (( EPOCHSECONDS - last_check > interval_seconds )); then
    print -P "%F{81}\uF0C2 aws sso login%f for profile %F{141}${AWS_PROFILE:-default}%f"
    awsl
  fi
}
