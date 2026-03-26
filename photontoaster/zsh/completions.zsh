# PhotonToaster zsh completions

autoload -Uz compinit
zmodload zsh/complist
compinit -d "$HOME/.zcompdump"
[[ "$HOME/.zcompdump" -nt "$HOME/.zcompdump.zwc" ]] && zcompile "$HOME/.zcompdump"

[[ -n "${LS_COLORS:-}" ]] && zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

zstyle ':completion:*' menu select
zstyle ':completion:*' group-name ''
zstyle ':completion:*' matcher-list 'm:{a-z}={A-Za-z}' 'r:|[._-]=* r:|=*' 'l:|=* r:|=*'
zstyle ':completion:*' completer _extensions _complete _match _approximate
zstyle ':completion:*:approximate:*' max-errors 2 numeric
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*' use-cache on
typeset -g _pt_compcache="${XDG_RUNTIME_DIR:-/dev/shm}/zcompcache-${UID}"
[[ -d "$_pt_compcache" ]] || mkdir -p "$_pt_compcache"
zstyle ':completion:*' cache-path "$_pt_compcache"
zstyle ':completion:*' list-prompt '%S%M matches%s'
zstyle ':completion:*' select-prompt '%Sscrolling: current selection at %p%s'

# Tab triggers completion menu; shift-tab reverses through it
bindkey '^I' expand-or-complete
bindkey '^[[Z' reverse-menu-complete

# fzf-tab (enhances completion with fzf popup)
[[ -f "$HOME/.local/share/fzf-tab/fzf-tab.plugin.zsh" ]] && source "$HOME/.local/share/fzf-tab/fzf-tab.plugin.zsh"
zstyle ':fzf-tab:*' use-fzf-default-opts yes
zstyle ':fzf-tab:*' fzf-flags --ansi
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --color=always --icons=always $realpath 2>/dev/null || ls -1 --color=always $realpath'
zstyle ':fzf-tab:complete:z:*' fzf-preview 'eza -1 --color=always --icons=always $realpath 2>/dev/null || ls -1 --color=always $realpath'
