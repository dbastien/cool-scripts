# PhotonToaster bash AWS SSO helpers

if ! declare -p _pt_config &>/dev/null; then
  declare -gA _pt_config
fi
[[ -z "${_pt_config[state_dir]:-}" ]] &&
  _pt_config[state_dir]="${XDG_STATE_HOME:-$HOME/.local/state}/photontoaster"
[[ -z "${_pt_config[sso_ttl_seconds]:-}" ]] &&
  _pt_config[sso_ttl_seconds]=$((8 * 60 * 60))

: "${C_BLUE:=110;155;245}"
: "${C_VIOLET:=150;125;255}"

_pt_epoch() {
  if [[ -n "${EPOCHSECONDS:+x}" ]]; then
    printf '%s' "$EPOCHSECONDS"
  else
    date +%s
  fi
}

awsp() {
  printf '%s\n' "${AWS_PROFILE:-default}"
}

_pt_aws_stamp_file() {
  local profile="${AWS_PROFILE:-default}"
  mkdir -p "${_pt_config[state_dir]}" || return
  printf '%s/aws-sso-%s.stamp' "${_pt_config[state_dir]}" "$profile"
}

_pt_aws_profile_has_sso() {
  [[ -f "$HOME/.aws/config" ]] || return 1
  local profile="${AWS_PROFILE:-default}" header
  if [[ "$profile" == default ]]; then
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
    _pt_epoch >"$(_pt_aws_stamp_file)"
  fi
}

awswho() {
  command aws sts get-caller-identity --profile "${AWS_PROFILE:-default}" "$@"
}

_pt_aws_startup_login() {
  command -v aws >/dev/null 2>&1 || return 0
  _pt_aws_profile_has_sso || return 0
  local stamp_file last_check=0 now
  stamp_file="$(_pt_aws_stamp_file)"
  last_check=0
  [[ -f "$stamp_file" ]] && read -r last_check <"$stamp_file"
  [[ "$last_check" =~ ^[0-9]+$ ]] || last_check=0
  now="$(_pt_epoch)"
  if ((now - last_check > _pt_config[sso_ttl_seconds])); then
    printf '\033[38;2;%smaws sso login\033[0m for profile \033[38;2;%sm%s\033[0m\n' \
      "$C_BLUE" "$C_VIOLET" "${AWS_PROFILE:-default}"
    awsl
  fi
}

if [[ -n "${PS1:-}" ]]; then
  PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND;}_pt_aws_startup_login"
fi
