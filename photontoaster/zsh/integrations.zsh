# PhotonToaster zsh integrations — tool initialization
# Slow plugins (syntax-highlighting, thefuck, atuin) are deferred via zsh-defer
# to avoid blocking shell startup. Immediate tools (zoxide, fzf, direnv) load
# synchronously since they're needed right away.

# zsh-defer (~150 lines, <1ms to load)
[[ -f "$HOME/.local/share/zsh-defer/zsh-defer.plugin.zsh" ]] && \
  source "$HOME/.local/share/zsh-defer/zsh-defer.plugin.zsh"

typeset -g _pt_has_defer=0
(( $+functions[zsh-defer] )) && _pt_has_defer=1

# zoxide (smarter cd) — synchronous, needed immediately for cd alias
if (( $+commands[zoxide] )); then
  eval "$(zoxide init zsh)"
fi

# direnv (per-directory env) — only on chpwd, not every precmd
if (( $+commands[direnv] )); then
  _photontoaster_direnv_hook() {
    eval "$(direnv export zsh 2>/dev/null)"
  }
  add-zsh-hook chpwd _photontoaster_direnv_hook
  _photontoaster_direnv_hook
fi

# fzf keybindings and completion — synchronous, needed for tab completion
if (( $+commands[fzf] )); then
  if fzf --zsh >/dev/null 2>&1 </dev/null; then
    source <(fzf --zsh)
  else
    [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh
    [[ -f /usr/share/doc/fzf/examples/completion.zsh ]] && source /usr/share/doc/fzf/examples/completion.zsh
  fi
fi

# zsh-autosuggestions
ZSH_AUTOSUGGEST_USE_ASYNC=true
ZSH_AUTOSUGGEST_MANUAL_REBIND=true
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=20
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=244'
if [[ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]]; then
  source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
elif [[ -f "$HOME/.local/share/zsh-autosuggestions/zsh-autosuggestions.zsh" ]]; then
  source "$HOME/.local/share/zsh-autosuggestions/zsh-autosuggestions.zsh"
fi

# --- Deferred plugins (load after prompt appears) ---

# atuin (shell history) — forks a Rust binary to generate init code
if (( _pt_has_defer && $+commands[atuin] )); then
  zsh-defer eval "$(atuin init zsh)"
elif (( $+commands[atuin] )); then
  eval "$(atuin init zsh)"
fi

# thefuck (command correction) — forks a Python process
if (( _pt_has_defer && $+commands[thefuck] )); then
  zsh-defer eval "$(thefuck --alias)"
elif (( $+commands[thefuck] )); then
  eval "$(thefuck --alias)"
fi

# zsh-syntax-highlighting (must be near last) — heaviest per-keystroke plugin
if (( _pt_has_defer )); then
  if [[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
    zsh-defer source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
  elif [[ -f "$HOME/.local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
    zsh-defer source "$HOME/.local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  fi
else
  [[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# zsh-history-substring-search (Debian/Ubuntu apt, then Homebrew, then ~/.local)
typeset -g _pt_hist_sub=/usr/share/zsh-history-substring-search/zsh-history-substring-search.zsh
typeset -g _pt_brew_prefix="${HOMEBREW_PREFIX:-}"
if [[ -f "$_pt_hist_sub" ]]; then
  source "$_pt_hist_sub"
elif [[ -n "$_pt_brew_prefix" ]] && [[ -f "$_pt_brew_prefix/share/zsh-history-substring-search/zsh-history-substring-search.zsh" ]]; then
  source "$_pt_brew_prefix/share/zsh-history-substring-search/zsh-history-substring-search.zsh"
elif [[ -f "$HOME/.local/share/zsh-history-substring-search/zsh-history-substring-search.zsh" ]]; then
  source "$HOME/.local/share/zsh-history-substring-search/zsh-history-substring-search.zsh"
fi

bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^P' history-substring-search-up
bindkey '^N' history-substring-search-down

# Debian/Ubuntu: suggest packages for unknown commands (requires command-not-found package)
if (( ${+_pt_config} )) && [[ "${_pt_config[general.command_not_found_hints]:-false}" == "true" ]]; then
  [[ -r /etc/zsh_command_not_found ]] && source /etc/zsh_command_not_found
fi
