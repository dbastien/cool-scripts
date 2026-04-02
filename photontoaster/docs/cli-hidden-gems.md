# CLI Hidden Gems Cheatsheet

This is the "oh right, that flag exists" sheet for PhotonToaster tools.
Short, useful, copy-pasteable.

## Search and Find

### `rg` (ripgrep)

- `-U` and `--multiline-dotall`: match across newlines.
- `-t` / `-T`: include or exclude language families fast.
- `--glob`: add path constraints without changing cwd.
- `--replace`: quick search-and-rewrite previews.
- `--json`: machine-readable output for scripts.
- `--stats`: sanity-check search scope and speed.
- `--sort path`: deterministic output for tooling.

```bash
# Find a function call split across lines
rg -n -U --multiline-dotall 'doThing\([^)]*\n[^)]*\)'

# Search only shell and markdown, ignore generated docs
rg -n -tsh -tmd --glob '!docs/assets/**' 'TODO|FIXME'

# Quick rewrite preview (dry run style)
rg -n --replace 'src/$1' 'from="([^"]+)"' .
```

### `fd`

- `--exec` / `--exec-batch`: run one command per result or one per batch.
- `--changed-within`: target files touched recently.
- `--size`: quick size filtering.
- `-t`: restrict by file type (`f`, `d`, `x`, `l`).
- `-E`: exclude dirs/patterns.

```bash
# Run shellcheck on all shell scripts except vendor
fd -e sh -E vendor --exec shellcheck {}

# Find big logs touched in the last day
fd -e log --changed-within 1day --size +5m
```

### `fzf`

- `--preview`: inspect candidate before selecting.
- `--bind`: custom keys for instant actions.
- `--multi`: choose many entries.
- `**` trigger completion (when shell integration is loaded).

```bash
# Fuzzy pick files with bat preview
fd . | fzf --preview 'bat --color=always --line-range=:200 {}'

# Multi-select ripgrep hits and open in editor
rg -n 'TODO' | fzf --multi --delimiter : --preview 'bat --color=always {1}' 
```

### `plocate`

- `-i`: case-insensitive matching.
- `--count`: get hit count only.
- `--existing`: ignore stale DB entries.
- `--regex`: use regex instead of glob-like patterns.

```bash
plocate -i --existing 'docker-compose'
plocate --count --regex '.*\.(sql|dump)$'
```

## Viewing and Diffing

### `bat`

- `--diff`: side-by-side-ish annotated diffs for two files.
- `--show-all`: include non-printing chars.
- `--line-range`: constrain output.
- `--map-syntax`: force syntax highlighting for custom extensions.
- `-A`: show tabs/newlines visibly.

```bash
bat --diff old.conf new.conf
bat --line-range 120:220 --show-all script.sh
```

### `delta`

- `--side-by-side`: compact visual compare.
- `--word-diff`: changed words, not just lines.
- `-n`: line numbers in diffs.
- `--diff-so-fancy`: alternate pretty style.

```bash
git -c core.pager='delta --side-by-side -n' show HEAD~1
git -c core.pager='delta --word-diff' diff
```

### `hexyl`

- `--length`: cap bytes shown.
- `--skip`: start at offset.
- `--block-size`: control grouping.
- `--no-squeezing`: do not collapse repeated zero lines.

```bash
hexyl --skip 0x200 --length 512 firmware.bin
```

### `jq`

- `--slurp`: read all inputs as one array.
- `--arg` / `--argjson`: pass variables safely.
- `to_entries` / `from_entries`: map transforms on objects.
- `@csv`, `@tsv`, `@base64`: emit serialization directly.
- `env`: access environment vars from jq.

```bash
# Filter by env var
TARGET=prod jq -r 'map(select(.env == env.TARGET))' deploys.json

# Object -> table-ish rows
jq -r 'to_entries[] | [.key, .value] | @tsv' settings.json
```

### `jless`

- `--yaml`: treat input as YAML.
- `.`: focus current value.
- `/`: search within JSON tree.
- `yy`: yank selected value.

```bash
jless --yaml docker-compose.yml
```

### `glow`

- `-p`: pager mode.
- `-w`: set render width.
- `-s`: switch style.

```bash
glow -p -w 100 -s dark README.md
```

## Files and Disk

### `eza`

- `--git-repos`: summarize repo state across dirs.
- `--total-size`: include totals.
- `--time-style`: custom time format.
- `--changed`: show only changed files in git repos.
- `--header`: labels for columns.
- `--sort`: explicit sorting.

```bash
eza -lah --header --git --git-repos --total-size
eza --changed --sort=modified
```

### `dust`

- `-d`: max depth.
- `-n`: limit entries.
- `-r`: reverse sorting.
- `-X`: regex exclude.

```bash
dust -d 3 -n 25 -X 'node_modules|.git'
```

### `duf`

- `--sort`: reorder by mount, size, usage.
- `--only` / `--hide`: include or exclude fs types.

```bash
duf --sort size --hide tmpfs,devtmpfs
```

### `ncdu`

- `-e`: enable deletion in UI.
- `--exclude`: skip noisy paths.
- `-o` / `-f`: export/import scan database.

```bash
ncdu --exclude .git -o scan.json .
ncdu -f scan.json
```

### `broot`

- `--whale-spotting`: surface huge dirs early.
- `--git-status`: include git state in tree.
- `--sizes`: size-first browsing.

```bash
broot --whale-spotting --git-status --sizes
```

### `yazi`

- Bulk rename workflow with visual confirmation.
- Tabs for multiple roots in one session.
- Built-in preview tuning for large files/media.

```bash
yazi .
```

## Processes and System

### `procs`

- `--tree`: parent/child relationship view.
- `--watch`: live refresh.
- `--sortd`: descending sort by metric.
- `--insert`: custom columns.

```bash
procs --tree --sortd cpu
procs --watch 1 --insert tcp,read,write
```

### `btop`

- Filter mode for process triage.
- Tree process mode to inspect forks.
- Theme switch on the fly for readability.

### `bandwhich`

- `-i`: select network interface explicitly.
- `--no-resolve`: skip DNS/process resolution overhead.
- `--raw`: output for external processing.

```bash
sudo bandwhich -i eth0 --no-resolve
```

### `nvtop`

- Per-process GPU usage and kill shortcuts.
- Useful when multiple ML/inference jobs compete.

## HTTP and Network

### `xh`

- `--session`: persist cookies and headers.
- `--download`: save body to file.
- `--follow`: follow redirects.
- `--offline`: print request without sending.
- Request item syntax (`k=v`, `k:=json`, `Header:value`) is very script-friendly.

```bash
# Dry-run a complex request first
xh --offline POST api.local/users name=neo role:=admin X-Trace:1

# Reuse auth session
xh --session=dev GET api.local/me
```

### `doggo`

- `--type`: record class (`A`, `AAAA`, `TXT`, `MX`).
- `--nameserver`: force resolver.
- `--short`: concise output.
- `@server` shorthand for resolver target.

```bash
doggo --type TXT --short example.com @1.1.1.1
```

## Benchmarking and Dev

### `hyperfine`

- `--warmup`: reduce cold-start noise.
- `--prepare` / `--cleanup`: reset state around each run.
- `--parameter-scan`: sweep numeric ranges.
- `--shell=none`: avoid shell overhead.
- `--export-markdown`: paste-ready benchmark report.

```bash
hyperfine --warmup 3 --export-markdown bench.md 'rg TODO .' 'fd TODO'
hyperfine --parameter-scan n 10 100 'python script.py --n {n}'
```

### `lazygit`

- Interactive rebase/edit/squash flows.
- Cherry-pick from branch/commit list quickly.
- Stash browser makes partial stash workflows easier.

## Shell and History

### `atuin`

- `atuin stats`: command frequency and history shape.
- `atuin search --after/--before`: time slicing.
- `--exit`: hunt failing commands.
- `--cmd-only`: cleaner output for reuse.

```bash
atuin search --exit 1 --after '7 days ago' --cmd-only
```

### `zoxide`

- `zi`: fuzzy interactive jump.
- `zoxide query -ls`: inspect scores and matches.
- `zoxide edit`: manually prune bad jumps.

```bash
zoxide query -ls src
zi
```

### `tmux`

- `send-keys`: automate panes.
- `capture-pane`: dump output to file.
- `save-buffer`: persist copied content.
- `resize-pane` and `swap-window`: quick layout surgery.

```bash
tmux capture-pane -pS -200 > pane.log
tmux resize-pane -R 20
```

### `direnv`

- `direnv allow`: trust and apply `.envrc`.
- `direnv status`: diagnose loaded state.
- `watch_file`: reload on file changes.
- `layout python`: zero-drama per-project virtualenv.

```bash
# in .envrc
watch_file requirements.txt
layout python
```

## Compression

### `ouch`

- List archive contents without full extraction.
- Compress multiple files with format auto-detection.
- Pick output format by extension (`.tar.zst`, `.zip`, etc).

```bash
ouch compress dist/ notes.txt archive.tar.zst
```

## Git Power Moves

These are not aliases, but they save your day:

- `git stash -p`: stash only selected hunks.
- `git log -S 'needle'`: find commits that changed string count.
- `git log -G 'regex'`: regex-aware history search.
- `git bisect`: binary-search regressions.
- `git worktree add ../tmp-branch feature/x`: parallel branch checkout.
- `git reflog`: recover "lost" commits and HEAD moves.
- `git diff --stat`: quick size/scope diff summary.
- `git shortlog -sn`: contributor summary by commit count.

```bash
git log -G 'command_not_found_handler' -- zsh/
git worktree add ../pt-hotfix hotfix/startup
```

## Fast Combos Worth Memorizing

```bash
# Find + preview + open
fd . | fzf --preview 'bat --color=always {}' | xargs -r "$EDITOR"

# Ripgrep -> choose hit -> open file at line
rg -n 'TODO|FIXME' | fzf | awk -F: '{print $1 ":" $2}' | xargs -r "$EDITOR"

# Disk triage pipeline
dust -d 3 | fzf
```

