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
