#!/usr/bin/env bash
set -uo pipefail

# Benchmarks the did-you-mean suggestion pipeline.
# Generates a realistic command list, then times both old and new awk
# pipelines to compare throughput. Verifies identical output.

SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

WORD_LIST=$(mktemp)
trap 'rm -f "$WORD_LIST" "$OLD_OUT" "$NEW_OUT"' EXIT
OLD_OUT=$(mktemp)
NEW_OUT=$(mktemp)

if command -v zsh >/dev/null 2>&1; then
  zsh -c 'print -rl -- ${(k)commands}' > "$WORD_LIST"
else
  compgen -c 2>/dev/null | sort -u > "$WORD_LIST"
fi

NUM_CMDS=$(wc -l < "$WORD_LIST")
echo "Command pool: $NUM_CMDS commands"

TYPOS=("gti" "gitl" "pythno" "mkdri" "toppp")
ITERATIONS=2

# --- Old pipeline (3 external processes: awk | sort | awk | head) ---
old_pipeline() {
  local target="$1"
  LC_ALL=C awk -v target="$target" '
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
}' "$WORD_LIST" | sort -n -k1,1 -k2,2 | awk -F'\t' '!seen[$2]++{print $2}' | head -n 6
}

# --- New pipeline (single awk process, internal sort) ---
new_pipeline() {
  local target="$1"
  LC_ALL=C awk -v target="$target" -v top_n=6 '
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
}' "$WORD_LIST"
}

echo ""
echo "=== Output correctness check ==="
MATCH=true
for typo in "${TYPOS[@]}"; do
  old_pipeline "$typo" > "$OLD_OUT"
  new_pipeline "$typo" > "$NEW_OUT"
  if diff -q "$OLD_OUT" "$NEW_OUT" >/dev/null 2>&1; then
    printf "[MATCH] %s\n" "$typo"
  else
    printf "[DIFF]  %s\n" "$typo"
    diff "$OLD_OUT" "$NEW_OUT" || true
    MATCH=false
  fi
done

echo ""
echo "=== Timing: old pipeline (awk|sort|awk|head) ==="
OLD_START=$(date +%s%N)
for _iter in $(seq 1 $ITERATIONS); do
  for typo in "${TYPOS[@]}"; do
    old_pipeline "$typo" >/dev/null
  done
done
OLD_END=$(date +%s%N)
OLD_MS=$(( (OLD_END - OLD_START) / 1000000 ))
OLD_PER=$(( OLD_MS / (ITERATIONS * ${#TYPOS[@]}) ))
echo "Total: ${OLD_MS}ms  (${OLD_PER}ms/lookup, $ITERATIONS iterations x ${#TYPOS[@]} typos)"

echo ""
echo "=== Timing: new pipeline (single awk) ==="
NEW_START=$(date +%s%N)
for _iter in $(seq 1 $ITERATIONS); do
  for typo in "${TYPOS[@]}"; do
    new_pipeline "$typo" >/dev/null
  done
done
NEW_END=$(date +%s%N)
NEW_MS=$(( (NEW_END - NEW_START) / 1000000 ))
NEW_PER=$(( NEW_MS / (ITERATIONS * ${#TYPOS[@]}) ))
echo "Total: ${NEW_MS}ms  (${NEW_PER}ms/lookup, $ITERATIONS iterations x ${#TYPOS[@]} typos)"

echo ""
if (( NEW_MS < OLD_MS )); then
  SPEEDUP=$(( (OLD_MS - NEW_MS) * 100 / OLD_MS ))
  echo "Result: new is ~${SPEEDUP}% faster"
else
  echo "Result: no measurable improvement (noise or workload too small)"
fi

if $MATCH; then
  echo "Output: identical for all test cases"
else
  echo "Output: DIFFERENCES DETECTED — check above"
fi
