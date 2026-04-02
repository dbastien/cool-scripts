# PhotonToaster "did you mean?" handler
# Inline Levenshtein distance in awk — no external deps, fast enough for
# interactive use. Suggests up to 6 closest commands on typos.

typeset -gr _PT_DYM_ERR=$'\e[38;2;255;90;90m'
typeset -gr _PT_DYM_WARN=$'\e[38;2;255;220;60m'
typeset -gr _PT_DYM_VIO=$'\e[38;2;150;125;255m'
typeset -gr _PT_DYM_RST=$'\e[0m'
typeset -gr _PT_DYM_BOLD=$'\e[1m'
typeset -gr _PT_DYM_ICON_ERR=$'\uF00D'
typeset -gr _PT_DYM_ICON_WARN=$'\uF071'
typeset -gr _PT_DYM_ICON_ARROW=$'\uE0B1'

_did_you_mean_commands() {
  emulate -L zsh
  setopt local_options pipe_fail no_aliases
  local target="$1"
  rehash >/dev/null 2>&1 || true

  print -rl -- ${(k)commands} | LC_ALL=C awk -v target="$target" -v top_n=6 '
function min3(a,b,c){m=(a<b?a:b); return (m<c?m:c)}
function lev(s,t,   _d,i,j,n,m,cost){
  n=length(s); m=length(t)
  for(i=0;i<=n;i++) _d[i,0]=i
  for(j=0;j<=m;j++) _d[0,j]=j
  for(i=1;i<=n;i++){
    for(j=1;j<=m;j++){
      cost=(substr(s,i,1)==substr(t,j,1)?0:1)
      _d[i,j]=min3(_d[i-1,j]+1, _d[i,j-1]+1, _d[i-1,j-1]+cost)
    }
  }
  return _d[n,m]
}
BEGIN { tlen=length(target); tc1=substr(target,1,1); count=0 }
{
  cand=$0
  if (cand==target) next
  clen=length(cand)
  ld=clen-tlen; if(ld<0) ld=-ld
  prefix=(substr(cand,1,1)==tc1?1:0)
  has_substr=(index(cand,target)||index(target,cand))?1:0
  if (ld>3 && !has_substr && !prefix) next
  dist=lev(target,cand)
  if (dist<=2 || has_substr || prefix) {
    score=dist*10 + ld*2 - prefix - (has_substr?2:0)
    results[count]=score "\t" cand
    count++
  }
}
END {
  for(i=0;i<count;i++) for(j=i+1;j<count;j++){
    split(results[i],ai,"\t"); split(results[j],aj,"\t")
    if(aj[1]+0 < ai[1]+0 || (aj[1]+0==ai[1]+0 && aj[2]<ai[2])){
      tmp=results[i]; results[i]=results[j]; results[j]=tmp
    }
  }
  n=(count<top_n?count:top_n)
  for(i=0;i<n;i++){split(results[i],a,"\t"); print a[2]}
}'
}

command_not_found_handler() {
  emulate -L zsh
  local cmd="$1"
  shift || true
  local -a suggestions
  suggestions=( $(_did_you_mean_commands "$cmd") )

  print "${_PT_DYM_ERR}${_PT_DYM_ICON_ERR} command not found:${_PT_DYM_RST} ${_PT_DYM_BOLD}${cmd}${_PT_DYM_RST}" >&2

  (( ${#suggestions[@]} )) || return 127

  local buf="${_PT_DYM_WARN}${_PT_DYM_ICON_WARN} maybe one of these:${_PT_DYM_RST}"
  local s
  for s in "${suggestions[@]}"; do
    buf+=$'\n'"  ${_PT_DYM_VIO}${_PT_DYM_ICON_ARROW}${_PT_DYM_RST} ${s}"
  done
  print -r -- "$buf" >&2

  return 127
}
