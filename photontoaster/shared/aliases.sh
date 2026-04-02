# POSIX-compatible aliases — sourced by bash and zsh.
# AUTO-GENERATED from config/aliases.toml — do not edit directly.

alias bat='bat --color=always --hyperlink=auto'
alias diff='diff --color=always'
alias eza='eza --icons=always --group-directories-first --git --color=always --hyperlink'
alias fd='fd --color=always --hyperlink'
alias grep='grep --color=always'
alias ip='ip -c'
alias jq='jq -C'
alias rg='rg --color=always --hyperlink-format=default'

alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias cd.='cd ..'
alias cd..='cd ..'
alias cls='clear'
alias mkd='mkdir -pv'
alias reload='exec $SHELL -l'
alias v='$EDITOR'

alias ga='git add'
alias gc='git commit'
alias gcb='git checkout -b'
alias gcm='git commit -m'
alias gco='git checkout'
alias gd='git diff'
alias gl='git log --oneline --decorate --graph -20'
alias glog='git log --graph --pretty=format:%C(auto)%h%d%x20%s%x20%C(dim)%cr%x20%C(blue)<%an>%C(reset) --all -30'
alias gp='git pull'
alias gs='git status'
alias gst='git status -sb'

if command -v bandwhich >/dev/null 2>&1; then
  alias bw='bandwhich'
fi
if command -v hyperfine >/dev/null 2>&1; then
  alias bench='hyperfine'
fi
if command -v broot >/dev/null 2>&1; then
  alias br='broot'
fi
if command -v cheat >/dev/null 2>&1; then
  alias ch='cheat'
fi
if command -v qalc >/dev/null 2>&1; then
  alias calc='qalc'
fi
if command -v delta >/dev/null 2>&1; then
  alias d='delta --hyperlinks'
fi
if command -v yazi >/dev/null 2>&1; then
  alias fm='yazi'
fi
if command -v eget >/dev/null 2>&1; then
  alias getgh='eget'
fi
if command -v nvtop >/dev/null 2>&1; then
  alias gpu='nvtop'
fi
if command -v hexyl >/dev/null 2>&1; then
  alias hex='hexyl'
fi
if command -v xh >/dev/null 2>&1; then
  alias http='xh'
fi
if command -v helix >/dev/null 2>&1; then
  alias hx='helix'
fi
if command -v jless >/dev/null 2>&1; then
  alias jl='jless'
fi
if command -v tldr >/dev/null 2>&1; then
  alias kb='tldr'
  alias tl='tldr'
fi
if command -v lazygit >/dev/null 2>&1; then
  alias lg='lazygit'
fi
if command -v mcp-probe >/dev/null 2>&1; then
  alias mcpp='mcp-probe'
fi
if command -v glow >/dev/null 2>&1; then
  alias md='glow'
fi
if command -v navi >/dev/null 2>&1; then
  alias nav='navi'
fi
if command -v rich >/dev/null 2>&1; then
  alias richcsv='rich --csv'
  alias richj='rich --json'
  alias richmd='rich --markdown'
fi
if command -v sampler >/dev/null 2>&1; then
  alias samp='sampler'
fi
if command -v pet >/dev/null 2>&1; then
  alias snippets='pet'
fi
if command -v task >/dev/null 2>&1; then
  alias todo='task'
fi
if command -v television >/dev/null 2>&1; then
  alias tv='television'
fi
if command -v xplr >/dev/null 2>&1; then
  alias xp='xplr'
fi

if command -v duf >/dev/null 2>&1; then
  alias df='duf'
fi
if command -v doggo >/dev/null 2>&1; then
  alias dig='doggo --color'
fi
if command -v dust >/dev/null 2>&1; then
  alias du='dust --color=always'
fi
if command -v procs >/dev/null 2>&1; then
  alias ps='procs --color=always'
fi
if command -v btop >/dev/null 2>&1; then
  alias top='btop'
fi
if command -v ouch >/dev/null 2>&1; then
  alias x='ouch decompress'
fi

alias t='tmux -2'
alias ta='tmux attach -t'
alias tls='tmux ls'
alias tn='tmux new -s'

alias ccat='bat --color=always --hyperlink=auto --paging=never --style=header,grid,numbers,changes'
alias cronview='cronboard'
alias fda='fd -HI --color=always --hyperlink'
alias ff='plocate'
alias ipbrief='ip -c -br a'
alias j='z'
alias jqp='jq -C .'
alias ports='ss -tulpn'
alias rgf='rg -n --color=always --hyperlink-format=default'
