#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME=$(basename "$0")
MARKER_START="# >>> cool-scripts zsh bootstrap >>>"
MARKER_END="# <<< cool-scripts zsh bootstrap <<<"
DEFAULT_QUOTES_SOURCE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/quotes-default.txt"
QUOTES_RELATIVE_DEFAULT=".config/startup-quotes.txt"

if [[ ${EUID:-$(id -u)} -eq 0 ]]; then
  echo "Please run this script as your normal WSL user, not as root."
  exit 1
fi

if ! command -v sudo >/dev/null 2>&1; then
  echo "This script requires sudo for apt installs."
  exit 1
fi

log() {
  printf '\n[%s] %s\n' "$SCRIPT_NAME" "$*"
}

warn() {
  printf '\n[%s] WARNING: %s\n' "$SCRIPT_NAME" "$*" >&2
}

append_block() {
  local target_file="$1"
  local block_file="$2"
  mkdir -p "$(dirname "$target_file")"
  touch "$target_file"

  python3 - "$target_file" "$block_file" "$MARKER_START" "$MARKER_END" <<'PY'
import pathlib
import sys

target = pathlib.Path(sys.argv[1])
block_file = pathlib.Path(sys.argv[2])
start = sys.argv[3]
end = sys.argv[4]
block = block_file.read_text()
text = target.read_text() if target.exists() else ""
start_idx = text.find(start)
end_idx = text.find(end)
replacement = f"{start}\n{block.rstrip()}\n{end}\n"
if start_idx != -1 and end_idx != -1 and end_idx > start_idx:
    end_idx += len(end)
    if end_idx < len(text) and text[end_idx:end_idx+1] == "\n":
        end_idx += 1
    text = text[:start_idx] + replacement + text[end_idx:]
else:
    if text and not text.endswith("\n"):
        text += "\n"
    text += replacement

target.write_text(text)
PY
}

copy_quotes_file() {
  local source_quotes="$1"
  local target_quotes="$HOME/$QUOTES_RELATIVE_DEFAULT"
  mkdir -p "$(dirname "$target_quotes")"

  if [[ -n "$source_quotes" ]]; then
    if [[ ! -f "$source_quotes" ]]; then
      warn "Quotes file '$source_quotes' was not found. Falling back to bundled defaults."
      source_quotes="$DEFAULT_QUOTES_SOURCE"
    fi
  else
    source_quotes="$DEFAULT_QUOTES_SOURCE"
  fi

  cp "$source_quotes" "$target_quotes"
  echo "$target_quotes"
}

print_intro() {
  cat <<'TEXT'
This bootstrap script prepares a fresh Ubuntu-on-WSL shell environment for Zsh only.

What it does:
  - installs Zsh plus modern CLI tools,
  - configures strong completion, autosuggestions, syntax highlighting,
  - installs and enables thefuck,
  - sets up RAM-backed completion caches and zcompiled metadata where it helps,
  - adds useful colorful aliases,
  - adds a simple breadcrumb pill prompt,
  - and shows a random startup quote.

Tip: switch your terminal to a Nerd Font such as JetBrainsMono Nerd Font or FiraCode Nerd Font.
TEXT
}

choose_quotes() {
  local answer
  read -r -p "Optional quotes file path (leave blank to use the bundled default): " answer || true
  QUOTES_SOURCE="${answer:-}"
}

install_packages() {
  local packages=(
    # Core shell + completions.
    zsh bash-completion command-not-found

    # Zsh quality-of-life plugins.
    zsh-autosuggestions zsh-syntax-highlighting zsh-history-substring-search thefuck

    # Core foundations.
    git curl wget unzip zip ca-certificates software-properties-common
    build-essential pkg-config

    # Navigation and search.
    zoxide ripgrep fzf fd-find

    # Editing and viewing.
    micro bat jq less

    # System insight.
    btop fastfetch ncdu tree

    # WSL and modern listing.
    wslu eza tldr
  )

  log "Updating apt package lists."
  sudo apt-get update

  log "Installing Zsh and the CLI toolkit."
  sudo apt-get install -y "${packages[@]}"
}

resolve_binaries() {
  BAT_BIN=$(command -v batcat || command -v bat || true)
  FD_BIN=$(command -v fdfind || command -v fd || true)
  EZA_BIN=$(command -v eza || true)
  BTOP_BIN=$(command -v btop || true)
  FASTFETCH_BIN=$(command -v fastfetch || true)
  MICRO_BIN=$(command -v micro || true)
  RG_BIN=$(command -v rg || true)
  FZF_BIN=$(command -v fzf || true)
  ZOXIDE_BIN=$(command -v zoxide || true)
  ZSH_BIN=$(command -v zsh || true)
  THEFUCK_BIN=$(command -v thefuck || true)
}

write_zsh_config() {
  local output_file="$1"
  cat > "$output_file" <<EOF_ZSH
# Core environment.
export CLICOLOR=1
export COLORTERM=truecolor
export EDITOR='${MICRO_BIN:-micro}'
export VISUAL='${MICRO_BIN:-micro}'
export PAGER='less -R'
export MANPAGER='less -R'
export LESS='-R --use-color -Dd+r -Du+b'
export MANROFFOPT='-P -c'
export LS_COLORS='di=1;34:ln=1;36:so=1;35:pi=33:ex=1;32:bd=1;33:cd=1;33:su=37;41:sg=30;43:tw=30;42:ow=34;42'

# Fast local caches. Prefer tmpfs/ram when available for zsh completion metadata.
export ZSH_CACHE_DIR="\${XDG_CACHE_HOME:-\$HOME/.cache}/zsh"
if [[ -n "\${XDG_RUNTIME_DIR:-}" && -d "\$XDG_RUNTIME_DIR" ]]; then
  export ZSH_RAM_CACHE_DIR="\$XDG_RUNTIME_DIR/cool-scripts-zsh"
elif [[ -d /dev/shm ]]; then
  export ZSH_RAM_CACHE_DIR="/dev/shm/\$USER-zsh"
else
  export ZSH_RAM_CACHE_DIR="\$ZSH_CACHE_DIR/runtime"
fi
mkdir -p "\$ZSH_CACHE_DIR" "\$ZSH_RAM_CACHE_DIR" "\$ZSH_RAM_CACHE_DIR/completion-cache"

# History and shell behavior.
HISTFILE="\$HOME/.zsh_history"
HISTSIZE=100000
SAVEHIST=100000
setopt APPEND_HISTORY INC_APPEND_HISTORY SHARE_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_ALL_DUPS HIST_REDUCE_BLANKS
setopt AUTO_CD AUTO_PUSHD PUSHD_IGNORE_DUPS PUSHD_SILENT EXTENDED_GLOB INTERACTIVE_COMMENTS GLOB_DOTS NO_BEEP
setopt COMPLETE_IN_WORD ALWAYS_TO_END MENU_COMPLETE AUTO_MENU

# Completion framework.
autoload -Uz colors && colors
autoload -Uz compinit bashcompinit
zmodload zsh/complist
zmodload zsh/zpty 2>/dev/null || true
fpath=(/usr/share/zsh/vendor-completions /usr/share/zsh/site-functions /usr/share/zsh/functions/Completion/Linux \$fpath)

zstyle ':completion:*' accept-exact-dirs true
zstyle ':completion:*' add-space true
zstyle ':completion:*' completer _extensions _complete _approximate _correct _files _ignored
zstyle ':completion:*' file-sort modification
zstyle ':completion:*' group-name ''
zstyle ':completion:*' list-colors "\${(s.:.)LS_COLORS}"
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=** r:|=**'
zstyle ':completion:*' menu select=2
zstyle ':completion:*' rehash true
zstyle ':completion:*' squeeze-slashes true
zstyle ':completion:*' special-dirs true
zstyle ':completion:*' use-cache on
zstyle ':completion:*' verbose yes
zstyle ':completion:*' cache-path "\$ZSH_RAM_CACHE_DIR/completion-cache"
zstyle ':completion:*:descriptions' format '%F{110}-- %d --%f'
zstyle ':completion:*:messages' format '%F{178} %d %f'
zstyle ':completion:*:warnings' format '%F{203}no matches for:%f %d'
zstyle ':completion:*:corrections' format '%F{150}%d (errors: %e)%f'
zstyle ':completion:*' list-prompt '%S-- more matches --%s'
zstyle ':completion:*' select-prompt '%Sscrolling: current selection at %p%s'

ZSH_COMPDUMP="\$ZSH_RAM_CACHE_DIR/.zcompdump-\${HOST}-\${ZSH_VERSION}"
if [[ ! -s "\$ZSH_COMPDUMP.zwc" || ! -s "\$ZSH_COMPDUMP" || "\$ZSH_COMPDUMP" -nt "\$ZSH_COMPDUMP.zwc" ]]; then
  compinit -d "\$ZSH_COMPDUMP"
  zcompile "\$ZSH_COMPDUMP" 2>/dev/null || true
else
  compinit -C -d "\$ZSH_COMPDUMP"
fi
bashcompinit

# Plugin loading.
[[ -r /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]] && source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[[ -r /usr/share/zsh-history-substring-search/zsh-history-substring-search.zsh ]] && source /usr/share/zsh-history-substring-search/zsh-history-substring-search.zsh
[[ -r /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]] && source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh

# History substring search bindings.
bindkey '^[[A' history-substring-search-up
bindkey '^[[B' history-substring-search-down
bindkey '^[OA' history-substring-search-up
bindkey '^[OB' history-substring-search-down

# fzf integration.
[[ -r /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh
[[ -r /usr/share/doc/fzf/examples/completion.zsh ]] && source /usr/share/doc/fzf/examples/completion.zsh
export FZF_DEFAULT_OPTS='--height=45% --layout=reverse --border --info=inline --color=fg:#d0d0d0,bg:#101010,hl:#ffcc66,fg+:#ffffff,bg+:#202020,hl+:#8ccf7e,pointer:#5fd7ff,marker:#ffaf5f,prompt:#5fd7ff,spinner:#5fd7ff,header:#87afff'
EOF_ZSH

  if [[ -n "$FD_BIN" ]]; then
    cat >> "$output_file" <<EOF_ZSH
export FZF_DEFAULT_COMMAND='${FD_BIN} --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="\$FZF_DEFAULT_COMMAND"
EOF_ZSH
  fi

  cat >> "$output_file" <<EOF_ZSH

# zoxide and thefuck.
if command -v zoxide >/dev/null 2>&1; then
  eval "\$(zoxide init zsh)"
fi
if command -v thefuck >/dev/null 2>&1; then
  eval "\$(thefuck --alias)"
fi

setopt PROMPT_SUBST

# Breadcrumb labels and jump targets for shell-native navigation.
typeset -ga COOL_BREADCRUMB_PATHS
typeset -ga COOL_BREADCRUMB_LABELS

cool_refresh_breadcrumbs() {
  emulate -L zsh
  local path="\$PWD"
  local current=""
  local part
  local -a parts

  COOL_BREADCRUMB_PATHS=()
  COOL_BREADCRUMB_LABELS=()

  if [[ "\$path" == "\$HOME" || "\$path" == "\$HOME/"* ]]; then
    COOL_BREADCRUMB_PATHS+=("\$HOME")
    COOL_BREADCRUMB_LABELS+=("~")
    path="\${path#\$HOME}"
    current="\$HOME"
  else
    COOL_BREADCRUMB_PATHS+=("/")
    COOL_BREADCRUMB_LABELS+=("/")
    path="\${path#/}"
  fi

  parts=(\${(s:/:)path#/})
  for part in "\${parts[@]}"; do
    [[ -z "\$part" ]] && continue
    current="\${current%/}/\$part"
    COOL_BREADCRUMB_PATHS+=("\$current")
    COOL_BREADCRUMB_LABELS+=("\$part")
  done
}

cool_breadcrumbs() {
  emulate -L zsh
  cool_refresh_breadcrumbs
  local output=""
  local index total
  total=\${#COOL_BREADCRUMB_LABELS[@]}
  for (( index = 1; index <= total; index++ )); do
    [[ \$index -gt 1 ]] && output+=" %F{110}/%f "
    output+="%F{81}\${COOL_BREADCRUMB_LABELS[\$index]}%f"
  done
  print -nr -- "\$output"
}

cool_jump_breadcrumb() {
  emulate -L zsh
  cool_refresh_breadcrumbs
  local selected target
  local -a choices
  local index total

  total=\${#COOL_BREADCRUMB_PATHS[@]}
  for (( index = 1; index <= total; index++ )); do
    choices+=("\${index}: \${COOL_BREADCRUMB_LABELS[\$index]} -> \${COOL_BREADCRUMB_PATHS[\$index]}")
  done

  if command -v fzf >/dev/null 2>&1; then
    selected=\$(printf '%s\n' "\${choices[@]}" | fzf --ansi --layout=reverse --height=40% --border --prompt='breadcrumb> ' --bind='double-click:accept')
    [[ -z "\$selected" ]] && return 0
    target="\${selected#* -> }"
  else
    printf '\nBreadcrumb targets:\n'
    printf '  %s\n' "\${choices[@]}"
    read -r '?Jump to breadcrumb number: ' index
    [[ "\$index" != <-> ]] && return 0
    target="\${COOL_BREADCRUMB_PATHS[\$index]:-}"
  fi

  [[ -z "\$target" ]] && return 0
  cd "\$target"
}

cool_jump_breadcrumb_widget() {
  cool_jump_breadcrumb
  zle reset-prompt
}
zle -N cool_jump_breadcrumb_widget
bindkey '^[b' cool_jump_breadcrumb_widget

# Prompt: a simple pill around the breadcrumb path.
precmd() {
  local exit_code=\$?
  local pill="%K{24}%F{255}  \$(cool_breadcrumbs)  %f%k %F{110}[Alt-b jump]%f"
  if [[ \$exit_code -eq 0 ]]; then
    PROMPT="\${pill}\n$ "
  else
    PROMPT="%F{203}[\${exit_code}]%f \${pill}\n$ "
  fi
}

# Random startup quote.
function cool_random_quote() {
  local quotes_file="\$HOME/$QUOTES_RELATIVE_DEFAULT"
  if [[ -r "\$quotes_file" ]]; then
    grep -v '^[[:space:]]*$' "\$quotes_file" | shuf -n 1 | sed \$'s/.*/\\e[38;5;110m&\\e[0m/'
  fi
}

if [[ -o interactive ]]; then
  cool_random_quote
fi

# Safer and more informative file operations.
alias cp='cp -iv'                  # Confirm before overwriting while copying.
alias mv='mv -iv'                  # Confirm before overwriting while moving.
alias rm='rm -Iv'                  # Ask once before large or dangerous deletes.
alias mkdir='mkdir -pv'            # Create parents automatically and show what happened.

# Navigation shortcuts.
alias cd..='cd ..'                 # Fix the common missing-space typo.
alias ..='cd ..'                   # Jump up one directory quickly.
alias ...='cd ../../'              # Jump up two directory levels.
alias ....='cd ../../../'          # Jump up three directory levels.
alias .....='cd ../../../../'      # Jump up four directory levels.
alias j='z'                        # Use zoxide with the shorter jump muscle memory.

# Colorful modern replacements.
EOF_ZSH

  if [[ -n "$EZA_BIN" ]]; then
    cat >> "$output_file" <<EOF_ZSH
alias ls='${EZA_BIN} --group-directories-first --icons=auto --color=always'              # Better ls with icons and color.
alias ll='${EZA_BIN} -lah --group-directories-first --icons=auto --git --color=always'   # Detailed directory view.
alias la='${EZA_BIN} -a --group-directories-first --icons=auto --color=always'           # Show hidden files too.
alias lt='${EZA_BIN} --tree --level=2 --icons=auto --color=always'                       # Small tree view of the current directory.
EOF_ZSH
  else
    cat >> "$output_file" <<'EOF_ZSH'
alias ls='ls --color=auto -F'        # Fall back to GNU ls with color and file type markers.
alias ll='ls --color=auto -lahF'     # Detailed fallback ls view.
alias la='ls --color=auto -A'        # Show hidden files in the fallback ls mode.
alias lt='tree -C -L 2'              # Tree-style view with colors when eza is unavailable.
EOF_ZSH
  fi

  cat >> "$output_file" <<EOF_ZSH

# Colorful search and text inspection.
alias grep='grep --color=auto'       # Highlight matches in grep output.
alias egrep='egrep --color=auto'     # Highlight matches for extended grep syntax.
alias fgrep='fgrep --color=auto'     # Highlight fixed-string grep matches.
EOF_ZSH

  if [[ -n "$RG_BIN" ]]; then
    cat >> "$output_file" <<EOF_ZSH
alias rg='${RG_BIN} --colors=match:fg:yellow --colors=path:fg:cyan --smart-case'         # Faster recursive search with readable colors.
EOF_ZSH
  fi

  if [[ -n "$BAT_BIN" ]]; then
    cat >> "$output_file" <<EOF_ZSH
alias cat='${BAT_BIN} --paging=never --style=plain --color=always'                       # Use bat for colorful file output.
alias ccat='${BAT_BIN} --paging=never --style=numbers,changes --color=always'            # Show files with line numbers and syntax highlighting.
EOF_ZSH
  fi

  cat >> "$output_file" <<EOF_ZSH

# System helpers.
alias df='df -h'                    # Human-readable disk usage.
alias du='du -h'                    # Human-readable directory usage.
alias free='free -h'                # Human-readable memory output.
alias path='echo "$PATH" | tr ":" "\n"'  # Print PATH entries on separate lines.
alias ports='ss -tulpn'             # Show listening ports and associated processes.
alias psg='ps aux | grep -i'        # Quick process search helper.
alias weather='curl wttr.in'        # Ask wttr.in for a quick weather snapshot.
alias myip='curl -4 ifconfig.me'    # Show your public IPv4 address.
alias update='sudo apt-get update && sudo apt-get upgrade -y'   # Refresh and upgrade installed packages.
alias fixbroken='sudo apt-get install -f'                       # Repair broken package dependencies.
alias cls='clear'                   # Clear the terminal screen.
alias reload='exec zsh'             # Reload Zsh after editing config.
alias compdump='rm -f "$ZSH_COMPDUMP" "$ZSH_COMPDUMP.zwc" && exec zsh'   # Rebuild completion dump from scratch.

# Modern tool launchers.
EOF_ZSH

  if [[ -n "$BTOP_BIN" ]]; then
    cat >> "$output_file" <<EOF_ZSH
alias top='${BTOP_BIN}'             # Launch btop instead of the older top interface.
alias htop='${BTOP_BIN}'            # Point htop muscle memory at btop.
EOF_ZSH
  fi

  if [[ -n "$FASTFETCH_BIN" ]]; then
    cat >> "$output_file" <<EOF_ZSH
alias neofetch='${FASTFETCH_BIN}'   # Use fastfetch where people often expect neofetch.
EOF_ZSH
  fi

  if [[ -n "$MICRO_BIN" ]]; then
    cat >> "$output_file" <<EOF_ZSH
alias nano='${MICRO_BIN}'           # Use micro as a friendlier terminal editor.
alias edit='${MICRO_BIN}'           # Quick edit shortcut.
EOF_ZSH
  fi

  if [[ -n "$THEFUCK_BIN" ]]; then
    cat >> "$output_file" <<EOF_ZSH
alias please='fuck'                 # Friendly alias for thefuck.
EOF_ZSH
  fi
}

apply_config() {
  local quotes_path="$1"
  local tmpdir
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN

  write_zsh_config "$tmpdir/zshrc"
  append_block "$HOME/.zshrc" "$tmpdir/zshrc"
  log "Installed quotes file to $quotes_path"
}

set_login_shell() {
  local shell_path
  shell_path=$(command -v zsh || true)

  if [[ -z "$shell_path" ]]; then
    warn "Could not find the installed zsh binary, so the login shell was not changed."
    return 0
  fi

  if ! grep -qxF "$shell_path" /etc/shells 2>/dev/null; then
    echo "$shell_path" | sudo tee -a /etc/shells >/dev/null
  fi

  if chsh -s "$shell_path" "$USER"; then
    log "Changed your login shell to $shell_path"
  else
    warn "Unable to change your login shell automatically. You can run: chsh -s $shell_path"
  fi
}

print_package_plan() {
  cat <<'TEXT'

The script installs these always-on tools, grouped by purpose:
  Zsh experience:
    - zsh: the shell this bootstrap configures.
    - bash-completion: lets zsh reuse a lot of existing completion definitions.
    - command-not-found: suggests packages for missing commands.
    - zsh-autosuggestions: faint inline suggestions as you type.
    - zsh-syntax-highlighting: immediate visual feedback for valid commands.
    - zsh-history-substring-search: up/down searches that match what you already typed.
    - thefuck: fixes the previous command with one quick alias.

  Foundations:
    - git, curl, wget, unzip, zip, build-essential, pkg-config.

  Navigation and search:
    - zoxide, ripgrep, fzf, fd-find.

  Editing and inspection:
    - micro, bat, jq, less.

  System tools:
    - btop, fastfetch, ncdu, tree.

  WSL and listing:
    - wslu, eza, tldr.
TEXT
}

main() {
  print_intro
  print_package_plan
  choose_quotes
  install_packages
  resolve_binaries
  local quotes_path
  quotes_path=$(copy_quotes_file "$QUOTES_SOURCE")
  apply_config "$quotes_path"
  set_login_shell

  cat <<EOF_DONE

Done.

Configured shell: zsh
Quotes file:     $quotes_path

Next steps:
  1) Restart your terminal, or run: exec zsh
  2) Try the new shell helpers: Alt-b, fuck, please, z, ll, rg, bat, and btop
  3) If completion metadata ever feels stale, run: compdump
  4) Switch your terminal font to a Nerd Font for the cleanest prompt symbols
EOF_DONE
}

main "$@"
