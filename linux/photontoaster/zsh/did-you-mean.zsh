# PhotonToaster "did you mean?" handler
# Inline Levenshtein distance in awk — no external deps, fast enough for
# interactive use. Suggests up to 6 closest commands on typos.

_did_you_mean_commands() {
  emulate -L zsh
  setopt local_options pipe_fail no_aliases
  local target="$1"
  rehash >/dev/null 2>&1 || true

  print -rl -- ${(k)commands} | LC_ALL=C awk -v target="$target" '
function min3(a,b,c){m=(a<b?a:b); return (m<c?m:c)}
function abs(v){return v<0?-v:v}
function lev(s,t,   _d,i,j,n,m,cost,x_del,x_ins,x_sub){
  n=length(s); m=length(t)
  for(i=0;i<=n;i++) _d[i,0]=i
  for(j=0;j<=m;j++) _d[0,j]=j
  for(i=1;i<=n;i++){
    for(j=1;j<=m;j++){
      cost=(substr(s,i,1)==substr(t,j,1)?0:1)
      x_del=_d[i-1,j]+1
      x_ins=_d[i,j-1]+1
      x_sub=_d[i-1,j-1]+cost
      _d[i,j]=min3(x_del,x_ins,x_sub)
    }
  }
  return _d[n,m]
}
{
  cand=$0
  if (cand==target) next
  dist=lev(target,cand)
  ld=abs(length(cand)-length(target))
  prefix=(substr(cand,1,1)==substr(target,1,1)?1:0)
  has_substr=(index(cand,target)||index(target,cand))?1:0
  if (dist <= 2 || has_substr || prefix) {
    score = dist*10 + ld*2 - prefix - (has_substr?2:0)
    printf "%d\t%s\n", score, cand
  }
}' | sort -n -k1,1 -k2,2 | awk -F'\t' '!seen[$2]++{print $2}' | head -n 6
}

command_not_found_handler() {
  emulate -L zsh
  local cmd="$1"
  shift || true
  local -a suggestions
  suggestions=( $(_did_you_mean_commands "$cmd") )

  local _err=$'\e[38;2;255;90;90m'
  local _warn=$'\e[38;2;255;220;60m'
  local _vio=$'\e[38;2;150;125;255m'
  local _rst=$'\e[0m'
  local _bold=$'\e[1m'
  local _icon_err=$'\uF00D'
  local _icon_warn=$'\uF071'
  local _icon_arrow=$'\uE0B1'

  print "${_err}${_icon_err} command not found:${_rst} ${_bold}${cmd}${_rst}" >&2

  (( ${#suggestions[@]} )) || return 127

  print "${_warn}${_icon_warn} maybe one of these:${_rst}" >&2
  local s
  for s in "${suggestions[@]}"; do
    print "  ${_vio}${_icon_arrow}${_rst} ${s}" >&2
  done

  return 127
}
