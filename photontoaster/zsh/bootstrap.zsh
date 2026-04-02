# PhotonToaster zsh bootstrap
# Loads zsh modules in canonical order with safe .zwc acceleration.

# Suppress job notifications during startup so deferred plugins don't spam.
setopt no_monitor

typeset -ga _pt_zsh_modules=(
  aws
  init
  prompt
  integrations
  flags
  completions
  hooks
  did-you-mean
)

_pt_source_zsh_module() {
  local src="$1" zwc="${1}.zwc"

  if [[ -r "$zwc" && "$zwc" -nt "$src" ]]; then
    # If a stale/corrupt cache fails to load, drop it and fall back to source.
    if source "$zwc" 2>/dev/null; then
      return
    fi
    rm -f -- "$zwc" 2>/dev/null || true
  fi

  source "$src"

  if [[ -r "$src" && ( ! -e "$zwc" || "$src" -nt "$zwc" ) ]]; then
    zcompile "$src" 2>/dev/null || true
  fi
}

for _pt_mod in "${_pt_zsh_modules[@]}"; do
  _pt_source_zsh_module "$PHOTONTOASTER_CONFIG_DIR/zsh/${_pt_mod}.zsh"
done

unset _pt_mod
unset _pt_zsh_modules
unfunction _pt_source_zsh_module 2>/dev/null || true

setopt monitor 2>/dev/null || true
