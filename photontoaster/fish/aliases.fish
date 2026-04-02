# PhotonToaster fish aliases (abbreviations)
# AUTO-GENERATED from config/aliases.toml — do not edit directly.

abbr -a bat -- 'bat --color=always --hyperlink=auto'
abbr -a diff -- 'diff --color=always'
abbr -a eza -- 'eza --icons=always --group-directories-first --git --color=always --hyperlink'
abbr -a fd -- 'fd --color=always --hyperlink'
abbr -a grep -- 'grep --color=always'
abbr -a ip -- 'ip -c'
abbr -a jq -- 'jq -C'
abbr -a rg -- 'rg --color=always --hyperlink-format=default'

abbr -a .. -- 'cd ..'
abbr -a ... -- 'cd ../..'
abbr -a .... -- 'cd ../../..'
abbr -a cd. -- 'cd ..'
abbr -a cd.. -- 'cd ..'
abbr -a cls -- 'clear'
abbr -a mkd -- 'mkdir -pv'
abbr -a reload -- 'exec fish -l'
abbr -a v -- '$EDITOR'

abbr -a ga -- 'git add'
abbr -a gc -- 'git commit'
abbr -a gcb -- 'git checkout -b'
abbr -a gcm -- 'git commit -m'
abbr -a gco -- 'git checkout'
abbr -a gd -- 'git diff'
abbr -a gl -- 'git log --oneline --decorate --graph -20'
abbr -a glog -- 'git log --graph --pretty=format:%C(auto)%h%d%x20%s%x20%C(dim)%cr%x20%C(blue)<%an>%C(reset) --all -30'
abbr -a gp -- 'git pull'
abbr -a gs -- 'git status'
abbr -a gst -- 'git status -sb'

if type -q bandwhich
  abbr -a bw -- 'bandwhich'
end
if type -q hyperfine
  abbr -a bench -- 'hyperfine'
end
if type -q broot
  abbr -a br -- 'broot'
end
if type -q cheat
  abbr -a ch -- 'cheat'
end
if type -q qalc
  abbr -a calc -- 'qalc'
end
if type -q delta
  abbr -a d -- 'delta --hyperlinks'
end
if type -q yazi
  abbr -a fm -- 'yazi'
end
if type -q eget
  abbr -a getgh -- 'eget'
end
if type -q nvtop
  abbr -a gpu -- 'nvtop'
end
if type -q hexyl
  abbr -a hex -- 'hexyl'
end
if type -q xh
  abbr -a http -- 'xh'
end
if type -q helix
  abbr -a hx -- 'helix'
end
if type -q jless
  abbr -a jl -- 'jless'
end
if type -q tldr
  abbr -a kb -- 'tldr'
  abbr -a tl -- 'tldr'
end
if type -q lazygit
  abbr -a lg -- 'lazygit'
end
if type -q mcp-probe
  abbr -a mcpp -- 'mcp-probe'
end
if type -q glow
  abbr -a md -- 'glow'
end
if type -q navi
  abbr -a nav -- 'navi'
end
if type -q rich
  abbr -a richcsv -- 'rich --csv'
  abbr -a richj -- 'rich --json'
  abbr -a richmd -- 'rich --markdown'
end
if type -q sampler
  abbr -a samp -- 'sampler'
end
if type -q pet
  abbr -a snippets -- 'pet'
end
if type -q task
  abbr -a todo -- 'task'
end
if type -q television
  abbr -a tv -- 'television'
end
if type -q xplr
  abbr -a xp -- 'xplr'
end

if type -q duf
  abbr -a df -- 'duf'
end
if type -q doggo
  abbr -a dig -- 'doggo --color'
end
if type -q dust
  abbr -a du -- 'dust --color=always'
end
if type -q procs
  abbr -a ps -- 'procs --color=always'
end
if type -q btop
  abbr -a top -- 'btop'
end
if type -q ouch
  abbr -a x -- 'ouch decompress'
end

abbr -a t -- 'tmux -2'
abbr -a ta -- 'tmux attach -t'
abbr -a tls -- 'tmux ls'
abbr -a tn -- 'tmux new -s'

abbr -a ccat -- 'bat --color=always --hyperlink=auto --paging=never --style=header,grid,numbers,changes'
abbr -a cronview -- 'cronboard'
abbr -a fda -- 'fd -HI --color=always --hyperlink'
abbr -a ff -- 'plocate'
abbr -a ipbrief -- 'ip -c -br a'
abbr -a j -- 'z'
abbr -a jqp -- 'jq -C .'
abbr -a ports -- 'ss -tulpn'
abbr -a rgf -- 'rg -n --color=always --hyperlink-format=default'
