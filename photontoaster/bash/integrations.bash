# PhotonToaster bash third-party integrations

if command -v zoxide >/dev/null 2>&1; then
  eval "$(zoxide init bash)"
fi

# direnv — only on cd, not every prompt
if command -v direnv >/dev/null 2>&1; then
  _photontoaster_direnv_hook() {
    eval "$(direnv export bash 2>/dev/null)"
  }
  _photontoaster_direnv_hook
  _photontoaster_last_dir="$PWD"
  _photontoaster_direnv_cd_check() {
    if [[ "$PWD" != "$_photontoaster_last_dir" ]]; then
      _photontoaster_last_dir="$PWD"
      _photontoaster_direnv_hook
    fi
  }
  PROMPT_COMMAND="_photontoaster_direnv_cd_check${PROMPT_COMMAND:+;$PROMPT_COMMAND}"
fi

if command -v atuin >/dev/null 2>&1; then
  eval "$(atuin init bash)"
fi

if command -v thefuck >/dev/null 2>&1; then
  eval "$(thefuck --alias)"
fi

if command -v fzf >/dev/null 2>&1; then
  if fzf_out="$(fzf --bash 2>/dev/null)" && [[ -n "$fzf_out" ]]; then
    eval "$fzf_out"
  else
    if [[ -r /usr/share/doc/fzf/examples/key-bindings.bash ]]; then
      # shellcheck source=/dev/null
      . /usr/share/doc/fzf/examples/key-bindings.bash
    fi
    if [[ -r /usr/share/doc/fzf/examples/completion.bash ]]; then
      # shellcheck source=/dev/null
      . /usr/share/doc/fzf/examples/completion.bash
    fi
  fi
fi
