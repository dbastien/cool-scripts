# PhotonToaster zsh completions

autoload -Uz compinit
zmodload zsh/complist
typeset -g _pt_lazy_integrations=1
[[ "${_pt_config[general.lazy_integrations]:-true}" == "false" ]] && _pt_lazy_integrations=0
typeset -g _pt_zcompdump="$HOME/.zcompdump"
if [[ -s "$_pt_zcompdump" ]]; then
  compinit -C -d "$_pt_zcompdump"
else
  compinit -d "$_pt_zcompdump"
fi
if [[ "$_pt_zcompdump" -nt "${_pt_zcompdump}.zwc" ]]; then
  zcompile "$_pt_zcompdump" 2>/dev/null || true
fi

[[ -n "${LS_COLORS:-}" ]] && zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

zstyle ':completion:*' menu select
zstyle ':completion:*' accept-exact true
zstyle ':completion:*' group-name ''
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' completer _extensions _complete _match _approximate
zstyle ':completion:*:approximate:*' max-errors 'reply=($((($#PREFIX+$#SUFFIX)/3>7?7:($#PREFIX+$#SUFFIX)/3)))'
zstyle ':completion:*:corrections' format '%F{yellow}-- %d (errors: %e) --%f'
zstyle ':completion:*:descriptions' format '%F{cyan}-- %d --%f'
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*' use-cache on
typeset -g _pt_compcache="${XDG_RUNTIME_DIR:-${TMPDIR:-/tmp}}/zcompcache-${UID}"
[[ -d "$_pt_compcache" ]] || mkdir -p "$_pt_compcache"
zstyle ':completion:*' cache-path "$_pt_compcache"
zstyle ':completion:*' list-prompt '%S%M matches%s'
zstyle ':completion:*' select-prompt '%Sscrolling: current selection at %p%s'
setopt completealiases

# Tab triggers completion menu; shift-tab reverses through it
bindkey '^I' expand-or-complete
bindkey '^[[Z' reverse-menu-complete

# fzf-tab (enhances completion with fzf popup)
_pt_init_fzf_tab() {
  [[ -f "$HOME/.local/share/fzf-tab/fzf-tab.plugin.zsh" ]] || return 0
  source "$HOME/.local/share/fzf-tab/fzf-tab.plugin.zsh"
  zstyle ':fzf-tab:*' use-fzf-default-opts yes
  zstyle ':fzf-tab:*' fzf-flags --ansi
  zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always --icons=always $realpath 2>/dev/null || ls -1 --color=always $realpath'
  zstyle ':fzf-tab:complete:z:*' fzf-preview 'eza -1 --color=always --icons=always $realpath 2>/dev/null || ls -1 --color=always $realpath'
}

if (( _pt_lazy_integrations )) && (( $+functions[zsh-defer] )); then
  zsh-defer _pt_init_fzf_tab
else
  _pt_init_fzf_tab
  unfunction _pt_init_fzf_tab 2>/dev/null || true
fi
