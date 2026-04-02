# PhotonToaster PowerShell aliases/functions
# AUTO-GENERATED from config/aliases.toml — do not edit directly.

function global:bat { & bat --color=always --hyperlink=auto @args }
function global:diff { & diff --color=always @args }
function global:eza { & eza --icons=always --group-directories-first --git --color=always --hyperlink @args }
function global:fd { & fd --color=always --hyperlink @args }
function global:jq { & jq -C @args }
function global:rg { & rg --color=always --hyperlink-format=default @args }
if (Get-Command 'grep' -ErrorAction SilentlyContinue) {
  function global:grep { & grep --color=always @args }
}
if (Get-Command 'ip' -ErrorAction SilentlyContinue) {
  function global:ip { & ip -c @args }
}

function global:.. { Set-Location .. }
function global:... { Set-Location ../.. }
function global:.... { Set-Location ../../.. }
function global:cd. { & cd .. @args }
function global:cd.. { Set-Location .. }
function global:cls { Clear-Host }
function global:mkd {
  param([Parameter(ValueFromRemainingArguments)][string[]]$Paths)
  foreach ($p in $Paths) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
}
function global:reload {
  if (Test-Path $PROFILE) { . $PROFILE } else { Write-Warning 'No $PROFILE file found.' }
}
function global:v {
  if ($env:EDITOR) { & $env:EDITOR @args; return }
  foreach ($c in 'code', 'codium', 'nvim', 'vim', 'notepad') {
    if (Get-Command $c -ErrorAction SilentlyContinue) { & $c @args; return }
  }
  Write-Warning 'No editor found. Set $env:EDITOR.'
}

function global:ga { & git add @args }
function global:gc { & git commit @args }
function global:gcb { & git checkout -b @args }
function global:gcm { & git commit -m @args }
function global:gco { & git checkout @args }
function global:gd { & git diff @args }
function global:gl { & git log --oneline --decorate --graph -20 @args }
function global:glog { & git log --graph '--pretty=format:%C(auto)%h%d%x20%s%x20%C(dim)%cr%x20%C(blue)<%an>%C(reset)' --all -30 @args }
function global:gp { & git pull @args }
function global:gs { & git status @args }
function global:gst { & git status -sb @args }

if (Get-Command 'bandwhich' -ErrorAction SilentlyContinue) {
  function global:bw { & bandwhich @args }
}
if (Get-Command 'hyperfine' -ErrorAction SilentlyContinue) {
  function global:bench { & hyperfine @args }
}
if (Get-Command 'broot' -ErrorAction SilentlyContinue) {
  function global:br { & broot @args }
}
if (Get-Command 'cheat' -ErrorAction SilentlyContinue) {
  function global:ch { & cheat @args }
}
if (Get-Command 'qalc' -ErrorAction SilentlyContinue) {
  function global:calc { & qalc @args }
}
if (Get-Command 'delta' -ErrorAction SilentlyContinue) {
  function global:d { & delta --hyperlinks @args }
}
if (Get-Command 'yazi' -ErrorAction SilentlyContinue) {
  function global:fm { & yazi @args }
}
if (Get-Command 'eget' -ErrorAction SilentlyContinue) {
  function global:getgh { & eget @args }
}
if (Get-Command 'nvtop' -ErrorAction SilentlyContinue) {
  function global:gpu { & nvtop @args }
}
if (Get-Command 'hexyl' -ErrorAction SilentlyContinue) {
  function global:hex { & hexyl @args }
}
if (Get-Command 'xh' -ErrorAction SilentlyContinue) {
  function global:http { & xh @args }
}
if (Get-Command 'helix' -ErrorAction SilentlyContinue) {
  function global:hx { & helix @args }
}
if (Get-Command 'jless' -ErrorAction SilentlyContinue) {
  function global:jl { & jless @args }
}
if (Get-Command 'tldr' -ErrorAction SilentlyContinue) {
  function global:kb { & tldr @args }
  function global:tl { & tldr @args }
}
if (Get-Command 'lazygit' -ErrorAction SilentlyContinue) {
  function global:lg { & lazygit @args }
}
if (Get-Command 'mcp-probe' -ErrorAction SilentlyContinue) {
  function global:mcpp { & mcp-probe @args }
}
if (Get-Command 'glow' -ErrorAction SilentlyContinue) {
  function global:md { & glow @args }
}
if (Get-Command 'navi' -ErrorAction SilentlyContinue) {
  function global:nav { & navi @args }
}
if (Get-Command 'rich' -ErrorAction SilentlyContinue) {
  function global:richcsv { & rich --csv @args }
  function global:richj { & rich --json @args }
  function global:richmd { & rich --markdown @args }
}
if (Get-Command 'sampler' -ErrorAction SilentlyContinue) {
  function global:samp { & sampler @args }
}
if (Get-Command 'pet' -ErrorAction SilentlyContinue) {
  function global:snippets { & pet @args }
}
if (Get-Command 'task' -ErrorAction SilentlyContinue) {
  function global:todo { & task @args }
}
if (Get-Command 'television' -ErrorAction SilentlyContinue) {
  function global:tv { & television @args }
}
if (Get-Command 'xplr' -ErrorAction SilentlyContinue) {
  function global:xp { & xplr @args }
}

if (Get-Command 'duf' -ErrorAction SilentlyContinue) {
  function global:df { & duf @args }
}
if (Get-Command 'doggo' -ErrorAction SilentlyContinue) {
  function global:dig { & doggo --color @args }
}
if (Get-Command 'dust' -ErrorAction SilentlyContinue) {
  function global:du { & dust --color=always @args }
}
if (Get-Command 'procs' -ErrorAction SilentlyContinue) {
  function global:ps { & procs --color=always @args }
}
if (Get-Command 'btop' -ErrorAction SilentlyContinue) {
  function global:top { & btop @args }
}
if (Get-Command 'ouch' -ErrorAction SilentlyContinue) {
  function global:x { & ouch decompress @args }
}

if (Get-Command 'tmux' -ErrorAction SilentlyContinue) {
  function global:t { & tmux -2 @args }
  function global:ta { & tmux attach -t @args }
  function global:tls { & tmux ls @args }
  function global:tn { & tmux new -s @args }
}

function global:ccat { & bat --color=always --hyperlink=auto --paging=never --style=header,grid,numbers,changes @args }
function global:fda { & fd -HI --color=always --hyperlink @args }
function global:j { & z @args }
function global:jqp { & jq -C . @args }
function global:rgf { & rg -n --color=always --hyperlink-format=default @args }
if (Get-Command 'cronboard' -ErrorAction SilentlyContinue) {
  function global:cronview { & cronboard @args }
}
if (Get-Command 'plocate' -ErrorAction SilentlyContinue) {
  function global:ff { & plocate @args }
}
if (Get-Command 'ip' -ErrorAction SilentlyContinue) {
  function global:ipbrief { & ip -c -br a @args }
}
if (Get-Command 'ss' -ErrorAction SilentlyContinue) {
  function global:ports { & ss -tulpn @args }
}
