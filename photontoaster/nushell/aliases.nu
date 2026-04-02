# PhotonToaster nushell aliases
# AUTO-GENERATED from config/aliases.toml — do not edit directly.

alias bat = bat --color=always --hyperlink=auto
alias diff = diff --color=always
alias eza = eza --icons=always --group-directories-first --git --color=always --hyperlink
alias fd = fd --color=always --hyperlink
alias grep = grep --color=always
alias ip = ip -c
alias jq = jq -C
alias rg = rg --color=always --hyperlink-format=default

def --env ".." [] { cd .. }
def --env "..." [] { cd ../.. }
def --env "...." [] { cd ../../.. }
alias cd. = cd ..
def --env "cd.." [] { cd .. }
alias cls = clear
alias mkd = mkdir -pv
def --env reload [] { exec nu -l }
if "EDITOR" in $env { def --wrapped v [...args] { ^$env.EDITOR ...$args } }

alias ga = git add
alias gc = git commit
alias gcb = git checkout -b
alias gcm = git commit -m
alias gco = git checkout
alias gd = git diff
alias gl = git log --oneline --decorate --graph -20
alias glog = git log --graph --pretty=format:%C(auto)%h%d%x20%s%x20%C(dim)%cr%x20%C(blue)<%an>%C(reset) --all -30
alias gp = git pull
alias gs = git status
alias gst = git status -sb

if not ((which bandwhich | is-empty)) {
  alias bw = bandwhich
}
if not ((which hyperfine | is-empty)) {
  alias bench = hyperfine
}
if not ((which broot | is-empty)) {
  alias br = broot
}
if not ((which cheat | is-empty)) {
  alias ch = cheat
}
if not ((which qalc | is-empty)) {
  alias calc = qalc
}
if not ((which delta | is-empty)) {
  alias d = delta --hyperlinks
}
if not ((which yazi | is-empty)) {
  alias fm = yazi
}
if not ((which eget | is-empty)) {
  alias getgh = eget
}
if not ((which nvtop | is-empty)) {
  alias gpu = nvtop
}
if not ((which hexyl | is-empty)) {
  alias hex = hexyl
}
if not ((which xh | is-empty)) {
  alias http = xh
}
if not ((which helix | is-empty)) {
  alias hx = helix
}
if not ((which jless | is-empty)) {
  alias jl = jless
}
if not ((which tldr | is-empty)) {
  alias kb = tldr
  alias tl = tldr
}
if not ((which lazygit | is-empty)) {
  alias lg = lazygit
}
if not ((which mcp-probe | is-empty)) {
  alias mcpp = mcp-probe
}
if not ((which glow | is-empty)) {
  alias md = glow
}
if not ((which navi | is-empty)) {
  alias nav = navi
}
if not ((which rich | is-empty)) {
  alias richcsv = rich --csv
  alias richj = rich --json
  alias richmd = rich --markdown
}
if not ((which sampler | is-empty)) {
  alias samp = sampler
}
if not ((which pet | is-empty)) {
  alias snippets = pet
}
if not ((which task | is-empty)) {
  alias todo = task
}
if not ((which television | is-empty)) {
  alias tv = television
}
if not ((which xplr | is-empty)) {
  alias xp = xplr
}

if not ((which duf | is-empty)) {
  alias df = duf
}
if not ((which doggo | is-empty)) {
  alias dig = doggo --color
}
if not ((which dust | is-empty)) {
  alias du = dust --color=always
}
if not ((which procs | is-empty)) {
  alias ps = procs --color=always
}
if not ((which btop | is-empty)) {
  alias top = btop
}
if not ((which ouch | is-empty)) {
  alias x = ouch decompress
}

alias t = tmux -2
alias ta = tmux attach -t
alias tls = tmux ls
alias tn = tmux new -s

alias ccat = bat --color=always --hyperlink=auto --paging=never --style=header,grid,numbers,changes
alias cronview = cronboard
alias fda = fd -HI --color=always --hyperlink
alias ff = plocate
alias ipbrief = ip -c -br a
alias j = z
alias jqp = jq -C .
alias ports = ss -tulpn
alias rgf = rg -n --color=always --hyperlink-format=default
