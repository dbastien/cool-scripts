# PhotonToaster Aliases Cheatsheet

Canonical alias source is `config/aliases.toml` (then generated to each shell).
This sheet also includes zsh-only aliases defined in `zsh/init.zsh`.

## One-Hand Quick Picks

If your hand is cooked, these are the highest bang-for-keystroke aliases to
lean on first:

- `gs` -> `git status`
- `gd` -> `git diff`
- `ga` -> `git add`
- `gcm` -> `git commit -m`
- `..` / `...` / `....` -> jump up directories quickly
- `reload` -> restart shell config in place
- `v` -> open in `$EDITOR`
- `j` -> `z` (jump to recent/frequent directories)
- `ff` -> `plocate` (fast filename lookup)
- `ccat` -> rich file viewer output with `bat`

## Core Aliases (from `config/aliases.toml`)

### Color Overrides

- `bat` -> `bat --color=always --hyperlink=auto`
- `diff` -> `diff --color=always`
- `eza` -> `eza --icons=always --group-directories-first --git --color=always --hyperlink`
- `fd` -> `fd --color=always --hyperlink`
- `grep` -> `grep --color=always`
- `ip` -> `ip -c`
- `jq` -> `jq -C`
- `rg` -> `rg --color=always --hyperlink-format=default`

### Navigation

- `..` -> `cd ..`
- `...` -> `cd ../..`
- `....` -> `cd ../../..`
- `cd.` -> `cd ..`
- `cd..` -> `cd ..`
- `cls` -> `clear`
- `mkd` -> `mkdir -pv`
- `reload` -> `exec $SHELL -l`
- `v` -> `$EDITOR`

### Git

- `ga` -> `git add`
- `gc` -> `git commit`
- `gcb` -> `git checkout -b`
- `gcm` -> `git commit -m`
- `gco` -> `git checkout`
- `gd` -> `git diff`
- `gl` -> `git log --oneline --decorate --graph -20`
- `gp` -> `git pull`
- `gs` -> `git status`
- `gst` -> `git status -sb`

### Tools

- `bw` -> `bandwhich`
- `bench` -> `hyperfine`
- `br` -> `broot`
- `calc` -> `qalc`
- `d` -> `delta --hyperlinks`
- `fm` -> `yazi`
- `getgh` -> `eget`
- `gpu` -> `nvtop`
- `hex` -> `hexyl`
- `http` -> `xh`
- `hx` -> `helix`
- `jl` -> `jless`
- `kb` -> `tldr`
- `lg` -> `lazygit`
- `mcpp` -> `mcp-probe`
- `md` -> `glow`
- `richcsv` -> `rich --csv`
- `richj` -> `rich --json`
- `richmd` -> `rich --markdown`
- `samp` -> `sampler`
- `snippets` -> `pet`
- `tl` -> `tldr`
- `todo` -> `task`
- `tv` -> `television`
- `xp` -> `xplr`

### Replacements

- `df` -> `duf`
- `dig` -> `doggo --color`
- `du` -> `dust --color=always`
- `ps` -> `procs --color=always`
- `top` -> `btop`
- `x` -> `ouch decompress`

### Tmux

- `t` -> `tmux -2`
- `ta` -> `tmux attach -t`
- `tls` -> `tmux ls`
- `tn` -> `tmux new -s`

### Utility

- `ccat` -> `bat --color=always --hyperlink=auto --paging=never --style=header,grid,numbers,changes`
- `cronview` -> `cronboard`
- `fda` -> `fd -HI --color=always --hyperlink`
- `ff` -> `plocate`
- `ipbrief` -> `ip -c -br a`
- `j` -> `z`
- `jqp` -> `jq -C .`
- `ports` -> `ss -tulpn`
- `rgf` -> `rg -n --color=always --hyperlink-format=default`

## zsh-Only Aliases (`zsh/init.zsh`)

### Typo Aliases (when `general.typo_aliases = true`)

- `gti`, `got`, `gi` -> `git`
- `sl`, `sls`, `lss` -> `ls`
- `claer`, `clera`, `clare`, `cler`, `clr` -> `clear`
- `grpe`, `gerp` -> `grep`
- `suod`, `sudp` -> `sudo`
- `mkdri`, `mkdier` -> `mkdir`

### Dynamic `ls` Aliases (from `general.ls_tool`)

The following aliases are set based on config value:

- always defined: `l`, `ls`, `lsa`, `la`, `ll`, `lla`, `lt`, `tree`
- profiles:
  - `eza` profile
  - `lsd` profile
  - `broot` profile
  - `ls` profile

### zoxide `cd` Alias

When `general.cd_to_z = true` and `zoxide` exists:

- `cd` -> `z`

### Suffix Aliases (when `general.suffix_aliases = true`)

Type a filename directly in zsh and it is opened/processed by extension:

- `.json` -> `jq -C .`
- `.md` -> `glow`
- `.txt` -> `bat`
- `.log` -> `bat --language=log`
- `.csv` -> `bat --language=csv`
- `.yaml`, `.yml` -> `bat --language=yaml`
- `.toml` -> `bat --language=toml`
- `.py`, `.sh`, `.zsh`, `.rs`, `.ts`, `.js`, `.html`, `.css` -> `$EDITOR`

## Notes

- Tool aliases are command-guarded in generated files (`shared/aliases.sh`, etc.), so aliases only load if the target command exists.
- Regenerate shell alias files after editing TOML:
  - `./scripts/generate_aliases.sh`
