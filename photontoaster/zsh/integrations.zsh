# PhotonToaster zsh integrations — tool initialization
# Slow plugins (syntax-highlighting, thefuck, atuin) are deferred via zsh-defer
# to avoid blocking shell startup. Immediate tools (zoxide, fzf, direnv) load
# synchronously since they're needed right away.

# zsh-defer (~150 lines, <1ms to load)
[[ -f "$HOME/.local/share/zsh-defer/zsh-defer.plugin.zsh" ]] && \
  source "$HOME/.local/share/zsh-defer/zsh-defer.plugin.zsh"

typeset -g _pt_has_defer=0
(( $+functions[zsh-defer] )) && _pt_has_defer=1
typeset -g _pt_lazy_integrations=1
[[ "${_pt_config[general.lazy_integrations]:-true}" == "false" ]] && _pt_lazy_integrations=0

# zoxide (smarter cd) — synchronous, needed immediately for cd alias
if (( $+commands[zoxide] )); then
  if (( _pt_lazy_integrations && _pt_has_defer )); then
    zsh-defer -c 'eval "$(zoxide init zsh 2>/dev/null)" 2>/dev/null'
  else
    eval "$(zoxide init zsh)"
  fi
fi

# direnv (per-directory env) — only on chpwd, not every precmd
if (( $+commands[direnv] )); then
  _photontoaster_direnv_hook() {
    eval "$(direnv export zsh 2>/dev/null)"
  }
  add-zsh-hook chpwd _photontoaster_direnv_hook
  if (( _pt_lazy_integrations && _pt_has_defer )); then
    zsh-defer _photontoaster_direnv_hook
  else
    _photontoaster_direnv_hook
  fi
fi

# fzf keybindings and completion — synchronous, needed for tab completion
if (( $+commands[fzf] )); then
  _pt_fzf_init() {
    local _pt_fzf_init_code
    _pt_fzf_init_code="$(fzf --zsh 2>/dev/null)"
    if [[ -n "$_pt_fzf_init_code" ]]; then
      eval "$_pt_fzf_init_code"
    else
      [[ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh
      [[ -f /usr/share/doc/fzf/examples/completion.zsh ]] && source /usr/share/doc/fzf/examples/completion.zsh
    fi
    unset _pt_fzf_init_code
  }
  if (( _pt_lazy_integrations && _pt_has_defer )); then
    zsh-defer _pt_fzf_init
  else
    _pt_fzf_init
    unfunction _pt_fzf_init 2>/dev/null || true
  fi

  # Alt-k: fuzzy pick and kill a process.
  _pt_fzf_kill_widget() {
    local pick pid
    pick="$(ps -eo pid,comm,args --sort=-%cpu 2>/dev/null | sed '1d' | fzf --height=40% --layout=reverse --prompt='kill> ')" || return 0
    pid="${pick%% *}"
    [[ -n "$pid" ]] || return 0
    kill "$pid" 2>/dev/null || true
    zle reset-prompt
  }
  zle -N _pt_fzf_kill_widget
  bindkey '^[k' _pt_fzf_kill_widget

  # Alt-g: fuzzy pick and checkout a git branch.
  _pt_fzf_branch_widget() {
    command git rev-parse --is-inside-work-tree >/dev/null 2>&1 || return 0
    local branch
    branch="$(git for-each-ref --format='%(refname:short)' refs/heads refs/remotes 2>/dev/null | fzf --height=40% --layout=reverse --prompt='branch> ')" || return 0
    [[ -n "$branch" ]] || return 0
    command git checkout "$branch" >/dev/null 2>&1 || return 0
    zle reset-prompt
  }
  zle -N _pt_fzf_branch_widget
  bindkey '^[g' _pt_fzf_branch_widget

  # Alt-f: fuzzy pick a directory and cd into it.
  _pt_fzf_cd_widget() {
    local dir
    if (( $+commands[fd] )); then
      dir="$(fd -t d . 2>/dev/null | fzf --height=40% --layout=reverse --prompt='cd> ')" || return 0
    else
      dir="$(print -rl -- ./**/*(/N) | fzf --height=40% --layout=reverse --prompt='cd> ')" || return 0
    fi
    [[ -n "$dir" ]] || return 0
    BUFFER="cd -- ${(q)dir}"
    zle accept-line
  }
  zle -N _pt_fzf_cd_widget
  bindkey '^[f' _pt_fzf_cd_widget
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
  zsh-defer -c 'eval "$(atuin init zsh 2>/dev/null)" 2>/dev/null'
elif (( $+commands[atuin] )); then
  eval "$(atuin init zsh 2>/dev/null)" 2>/dev/null
fi

# thefuck (command correction) — forks a Python process
if (( _pt_has_defer && $+commands[thefuck] )); then
  zsh-defer -c 'eval "$(thefuck --alias 2>/dev/null)" 2>/dev/null'
elif (( $+commands[thefuck] )); then
  eval "$(thefuck --alias 2>/dev/null)" 2>/dev/null
fi

# zsh-syntax-highlighting (must be near last) — heaviest per-keystroke plugin
# Pre-set highlighters array so the plugin preserves our pt_flag entry on load.
ZSH_HIGHLIGHT_HIGHLIGHTERS=( main pt_flag )
if (( _pt_has_defer )); then
  if [[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]]; then
    zsh-defer source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
  elif [[ -f "$HOME/.local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]]; then
    zsh-defer source "$HOME/.local/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
  fi
else
  [[ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# zsh-history-substring-search
typeset -g _pt_brew_prefix="${HOMEBREW_PREFIX:-}"
if [[ -n "$_pt_brew_prefix" ]] && [[ -f "$_pt_brew_prefix/share/zsh-history-substring-search/zsh-history-substring-search.zsh" ]]; then
  source "$_pt_brew_prefix/share/zsh-history-substring-search/zsh-history-substring-search.zsh"
elif [[ -f "$HOME/.local/share/zsh-history-substring-search/zsh-history-substring-search.zsh" ]]; then
  source "$HOME/.local/share/zsh-history-substring-search/zsh-history-substring-search.zsh"
fi

if (( $+functions[history-substring-search-up] && $+functions[history-substring-search-down] )); then
  bindkey '^[[A' history-substring-search-up
  bindkey '^[[B' history-substring-search-down
  bindkey '^P' history-substring-search-up
  bindkey '^N' history-substring-search-down
else
  bindkey '^[[A' history-beginning-search-backward
  bindkey '^[[B' history-beginning-search-forward
  bindkey '^P' history-beginning-search-backward
  bindkey '^N' history-beginning-search-forward
fi
