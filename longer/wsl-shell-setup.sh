#!/usr/bin/env bash
set -Eeuo pipefail

SCRIPT_NAME=$(basename "$0")
MARKER_START="# >>> cool-scripts wsl-shell-setup >>>"
MARKER_END="# <<< cool-scripts wsl-shell-setup <<<"
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
This bootstrap script prepares a fresh Ubuntu-on-WSL shell environment.

You will be able to pick one shell to install and configure:
  1) bash   - familiar default shell with broad compatibility.
  2) zsh    - popular interactive shell with strong completion and prompts.
  3) fish   - very user-friendly shell with readable syntax and smart defaults.
  4) xonsh  - Python-powered shell for people who like mixing shell + Python.
  5) nushell- modern structured shell built around tables instead of plain text.

It will also:
  - install a curated CLI toolkit,
  - set up color-friendly aliases,
  - install a simple pill-style prompt,
  - show a random startup quote,
  - and suggest using a Nerd Font for the best terminal experience.
TEXT
}

choose_shell() {
  local choice
  while true; do
    cat <<'TEXT'

Choose your shell:
  1) bash
  2) zsh
  3) fish
  4) xonsh
  5) nushell
TEXT
    read -r -p "Enter 1-5: " choice
    case "$choice" in
      1|bash|Bash) SHELL_CHOICE="bash"; break ;;
      2|zsh|Zsh) SHELL_CHOICE="zsh"; break ;;
      3|fish|Fish) SHELL_CHOICE="fish"; break ;;
      4|xonsh|Xonsh) SHELL_CHOICE="xonsh"; break ;;
      5|nushell|nu|Nu) SHELL_CHOICE="nushell"; break ;;
      *) warn "Please enter one of: 1, 2, 3, 4, 5." ;;
    esac
  done
}

choose_quotes() {
  local answer
  read -r -p "Optional quotes file path (leave blank to use the bundled default): " answer || true
  QUOTES_SOURCE="${answer:-}"
}

ensure_ppas_if_needed() {
  if [[ "$SHELL_CHOICE" == "fish" ]]; then
    return 0
  fi

  local added_repo=0
  if [[ "$SHELL_CHOICE" == "xonsh" ]]; then
    if ! apt-cache policy xonsh 2>/dev/null | grep -q Candidate; then
      log "Adding the deadsnakes PPA to install xonsh."
      sudo add-apt-repository -y ppa:deadsnakes/ppa
      added_repo=1
    fi
  elif [[ "$SHELL_CHOICE" == "nushell" ]]; then
    if ! apt-cache policy nushell 2>/dev/null | grep -q Candidate; then
      log "Adding the fish-shell release PPA because it often carries newer Nushell builds."
      sudo add-apt-repository -y ppa:fish-shell/release-4
      added_repo=1
    fi
  fi

  if [[ $added_repo -eq 1 ]]; then
    sudo apt-get update
  fi
}

install_packages() {
  local packages=()
  packages+=(
    git curl wget unzip zip ca-certificates software-properties-common
    build-essential pkg-config
    zoxide micro btop wslu ripgrep fzf bat fastfetch ncdu
    fd-find eza jq tldr tree less
  )

  case "$SHELL_CHOICE" in
    bash) packages+=(bash bash-completion) ;;
    zsh) packages+=(zsh) ;;
    fish) packages+=(fish) ;;
    xonsh) packages+=(xonsh python3-pygments) ;;
    nushell) packages+=(nushell) ;;
  esac

  log "Updating apt package lists."
  sudo apt-get update

  log "Installing CLI toolkit and the selected shell: $SHELL_CHOICE"
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
  NU_BIN=$(command -v nu || true)
  XONSH_BIN=$(command -v xonsh || true)
  FISH_BIN=$(command -v fish || true)
  ZSH_BIN=$(command -v zsh || true)
}

write_shell_common() {
  local common_file="$1"
  cat > "$common_file" <<EOF_COMMON
# General shell experience improvements for WSL / Ubuntu.

# Respect colorful output whenever the tool supports it.
export CLICOLOR=1
export LSCOLORS=GxFxCxDxBxegedabagaced
export LS_COLORS='di=1;34:ln=1;36:so=1;35:pi=33:ex=1;32:bd=1;33:cd=1;33:su=37;41:sg=30;43:tw=30;42:ow=34;42'
export LESS='-R --use-color -Dd+r -Du+b'
export MANPAGER='less -R'
export MANROFFOPT='-P -c'
export COLORTERM=truecolor
export EDITOR='${MICRO_BIN:-micro}'
export VISUAL='${MICRO_BIN:-micro}'
export PAGER='less -R'

# Category: safer and more informative file operations.
alias cp='cp -iv'                  # Confirm before overwriting while copying.
alias mv='mv -iv'                  # Confirm before overwriting while moving.
alias rm='rm -Iv'                  # Ask once before large or dangerous deletes.
alias mkdir='mkdir -pv'            # Create parents automatically and show what happened.

# Category: navigation shortcuts.
alias cd..='cd ..'                 # Fix the very common typo where the space is missed.
alias ..='cd ..'                   # Jump up one directory quickly.
alias ...='cd ../../'              # Jump up two directory levels.
alias ....='cd ../../../'          # Jump up three directory levels.
alias .....='cd ../../../../'      # Jump up four directory levels.
alias home='cd ~'                  # Return to your home directory quickly.
alias desk='cd ~/Desktop 2>/dev/null || cd ~'   # Try the Desktop first, then fall back home.
alias dl='cd ~/Downloads 2>/dev/null || cd ~'   # Jump to Downloads when it exists.

# Category: colorful modern replacements.
EOF_COMMON

  if [[ -n "$EZA_BIN" ]]; then
    cat >> "$common_file" <<EOF_COMMON
alias ls='${EZA_BIN} --group-directories-first --icons=auto --color=always'              # Better ls with icons and color.
alias ll='${EZA_BIN} -lah --group-directories-first --icons=auto --git --color=always'   # Detailed directory view.
alias la='${EZA_BIN} -a --group-directories-first --icons=auto --color=always'           # Show hidden files too.
alias lt='${EZA_BIN} --tree --level=2 --icons=auto --color=always'                       # Small tree view of the current directory.
EOF_COMMON
  else
    cat >> "$common_file" <<'EOF_COMMON'
alias ls='ls --color=auto -F'        # Fall back to GNU ls with color and file type markers.
alias ll='ls --color=auto -lahF'     # Detailed fallback ls view.
alias la='ls --color=auto -A'        # Show hidden files in the fallback ls mode.
alias lt='tree -C -L 2'              # Tree-style view with colors when eza is unavailable.
EOF_COMMON
  fi

  cat >> "$common_file" <<EOF_COMMON

# Category: colorful search and text inspection.
alias grep='grep --color=auto'       # Highlight matches in grep output.
alias egrep='egrep --color=auto'     # Highlight matches for extended grep syntax.
alias fgrep='fgrep --color=auto'     # Highlight fixed-string grep matches.
EOF_COMMON

  if [[ -n "$RG_BIN" ]]; then
    cat >> "$common_file" <<EOF_COMMON
alias rg='${RG_BIN} --colors=match:fg:yellow --colors=path:fg:cyan --smart-case'         # Faster recursive search with readable colors.
EOF_COMMON
  fi

  if [[ -n "$BAT_BIN" ]]; then
    cat >> "$common_file" <<EOF_COMMON
alias cat='${BAT_BIN} --paging=never --style=plain --color=always'                       # Use bat for colorful file output.
alias ccat='${BAT_BIN} --paging=never --style=numbers,changes --color=always'            # Show files with line numbers and syntax highlighting.
alias diff='${BAT_BIN} --diff --paging=never --color=always'                             # Read small diffs with syntax-aware coloring.
EOF_COMMON
  fi

  if [[ -n "$FD_BIN" ]]; then
    cat >> "$common_file" <<EOF_COMMON
alias fd='${FD_BIN} --hidden --follow'                                                    # Fast file finder that includes hidden files.
EOF_COMMON
  fi

  cat >> "$common_file" <<EOF_COMMON

# Category: system helpers.
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

# Category: modern tool launchers.
EOF_COMMON

  if [[ -n "$BTOP_BIN" ]]; then
    cat >> "$common_file" <<EOF_COMMON
alias top='${BTOP_BIN}'             # Launch btop instead of the older top interface.
alias htop='${BTOP_BIN}'            # Point htop muscle memory at btop.
EOF_COMMON
  fi

  if [[ -n "$FASTFETCH_BIN" ]]; then
    cat >> "$common_file" <<EOF_COMMON
alias neofetch='${FASTFETCH_BIN}'   # Use fastfetch where people often expect neofetch.
EOF_COMMON
  fi

  if [[ -n "$MICRO_BIN" ]]; then
    cat >> "$common_file" <<EOF_COMMON
alias nano='${MICRO_BIN}'           # Use micro as a friendlier terminal editor.
alias edit='${MICRO_BIN}'           # Quick edit shortcut.
EOF_COMMON
  fi

  if [[ -n "$FZF_BIN" ]]; then
    cat >> "$common_file" <<'EOF_COMMON'
export FZF_DEFAULT_OPTS='--height=40% --layout=reverse --border --color=fg:#d0d0d0,bg:#101010,hl:#ffcc66,fg+:#ffffff,bg+:#202020,hl+:#8ccf7e,pointer:#5fd7ff,marker:#ffaf5f,prompt:#5fd7ff,spinner:#5fd7ff,header:#87afff'
EOF_COMMON
  fi
}

write_bash_config() {
  local common_file="$1"
  cat > "$common_file".bash <<EOF_BASH
# Load bash-completion if it exists.
if [[ -r /usr/share/bash-completion/bash_completion ]]; then
  source /usr/share/bash-completion/bash_completion
fi

# Enable smarter globbing and history behavior.
shopt -s autocd cdspell checkwinsize cmdhist histappend globstar
HISTCONTROL=ignoredups:erasedups
HISTSIZE=50000
HISTFILESIZE=100000
PROMPT_DIRTRIM=3

# Colorized completions and shell builtins.
if [[ -f /etc/DIR_COLORS ]]; then
  eval "\$(dircolors -b /etc/DIR_COLORS)"
fi

# Fast directory jumping with zoxide.
if command -v zoxide >/dev/null 2>&1; then
  eval "\$(zoxide init bash)"
fi

# fzf key bindings if present.
if [[ -r /usr/share/doc/fzf/examples/key-bindings.bash ]]; then
  source /usr/share/doc/fzf/examples/key-bindings.bash
fi
if [[ -r /usr/share/doc/fzf/examples/completion.bash ]]; then
  source /usr/share/doc/fzf/examples/completion.bash
fi

# Clickable breadcrumb helpers for terminals that support OSC 8 hyperlinks.
__cool_uri_escape() {
  local value="$1"
  value=${value//'%'/'%25'}
  value=${value//' '/'%20'}
  value=${value//'#'/'%23'}
  value=${value//'?'/'%3F'}
  printf '%s' "$value"
}

__cool_file_link() {
  local target="$1"
  local label="$2"
  local host="${HOSTNAME:-wsl}"
  printf '\001\033]8;;file://%s%s\a\002%s\001\033]8;;\a\002' "$host" "$(__cool_uri_escape "$target")" "$label"
}

__cool_breadcrumbs() {
  local path="$PWD"
  local current=""
  local output=""
  local part
  local -a parts=()

  if [[ "$path" == "$HOME" || "$path" == "$HOME/"* ]]; then
    output="$(__cool_file_link "$HOME" "~")"
    path="${path#$HOME}"
    current="$HOME"
  else
    output="$(__cool_file_link "/" "/")"
    path="${path#/}"
  fi

  IFS='/' read -r -a parts <<< "${path#/}"
  for part in "${parts[@]}"; do
    [[ -z "$part" ]] && continue
    current="${current%/}/$part"
    output+=" / "
    output+="$(__cool_file_link "$current" "$part")"
  done

  printf '%s' "$output"
}

# Pill-style prompt around clickable breadcrumbs.
__cool_prompt() {
  local exit_code=\$?
  local reset='\[\e[0m\]'
  local pill_bg='\[\e[48;5;24m\]'
  local pill_fg='\[\e[38;5;255m\]'
  local warn_fg='\[\e[38;5;203m\]'
  local crumbs
  crumbs="$(__cool_breadcrumbs)"
  if [[ \$exit_code -eq 0 ]]; then
    PS1="${pill_bg}${pill_fg}  \${crumbs}  ${reset}\\n$ "
  else
    PS1="${warn_fg}[\${exit_code}] ${pill_bg}${pill_fg}  \${crumbs}  ${reset}\\n$ "
  fi
}
PROMPT_COMMAND=__cool_prompt

# Random startup quote.
__cool_random_quote() {
  local quotes_file=\"$HOME/$QUOTES_RELATIVE_DEFAULT\"
  if [[ -r \"\$quotes_file\" ]]; then
    mapfile -t __cool_quotes < <(grep -v '^[[:space:]]*$' \"\$quotes_file\")
    if [[ \${#__cool_quotes[@]} -gt 0 ]]; then
      local index=\$(( RANDOM % \${#__cool_quotes[@]} ))
      printf '\\e[38;5;110m%s\\e[0m\\n' \"\${__cool_quotes[\$index]}\"
    fi
  fi
}

if [[ $- == *i* ]]; then
  __cool_random_quote
fi
EOF_BASH
}

write_zsh_config() {
  local common_file="$1"
  cat > "$common_file".zsh <<EOF_ZSH
# Strong history defaults.
HISTFILE=\$HOME/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt APPEND_HISTORY HIST_IGNORE_DUPS HIST_IGNORE_ALL_DUPS SHARE_HISTORY AUTO_CD CORRECT EXTENDED_GLOB

autoload -Uz colors && colors
autoload -Uz compinit && compinit
zmodload zsh/complist
zstyle ':completion:*' list-colors "\${(s.:.)LS_COLORS}"
zstyle ':completion:*' menu select

# Fast directory jumping with zoxide.
if command -v zoxide >/dev/null 2>&1; then
  eval "\$(zoxide init zsh)"
fi

# fzf shell integration if installed.
[[ -r /usr/share/doc/fzf/examples/key-bindings.zsh ]] && source /usr/share/doc/fzf/examples/key-bindings.zsh
[[ -r /usr/share/doc/fzf/examples/completion.zsh ]] && source /usr/share/doc/fzf/examples/completion.zsh

setopt PROMPT_SUBST

# Build breadcrumb labels and shell-native jump targets.
typeset -ga COOL_BREADCRUMB_PATHS
typeset -ga COOL_BREADCRUMB_LABELS

cool_refresh_breadcrumbs() {
  emulate -L zsh
  local path="$PWD"
  local current=""
  local part
  local -a parts

  COOL_BREADCRUMB_PATHS=()
  COOL_BREADCRUMB_LABELS=()

  if [[ "$path" == "$HOME" || "$path" == "$HOME/"* ]]; then
    COOL_BREADCRUMB_PATHS+=("$HOME")
    COOL_BREADCRUMB_LABELS+=("~")
    path="${path#$HOME}"
    current="$HOME"
  else
    COOL_BREADCRUMB_PATHS+=("/")
    COOL_BREADCRUMB_LABELS+=("/")
    path="${path#/}"
  fi

  parts=(${(s:/:)path#/})
  for part in "${parts[@]}"; do
    [[ -z "$part" ]] && continue
    current="${current%/}/$part"
    COOL_BREADCRUMB_PATHS+=("$current")
    COOL_BREADCRUMB_LABELS+=("$part")
  done
}

cool_breadcrumbs() {
  emulate -L zsh
  cool_refresh_breadcrumbs
  local output=""
  local index total
  total=${#COOL_BREADCRUMB_LABELS[@]}
  for (( index = 1; index <= total; index++ )); do
    [[ $index -gt 1 ]] && output+=" %F{110}/%f "
    output+="%F{81}${COOL_BREADCRUMB_LABELS[$index]}%f"
  done

  print -nr -- "$output"
}

# Jump to one of the parent breadcrumb targets.
cool_jump_breadcrumb() {
  emulate -L zsh
  cool_refresh_breadcrumbs
  local selected target
  local -a choices
  local index total

  total=${#COOL_BREADCRUMB_PATHS[@]}
  for (( index = 1; index <= total; index++ )); do
    choices+=("${index}: ${COOL_BREADCRUMB_LABELS[$index]} -> ${COOL_BREADCRUMB_PATHS[$index]}")
  done

  if command -v fzf >/dev/null 2>&1; then
    selected=$(printf '%s\n' "${choices[@]}" | fzf --ansi --layout=reverse --height=40% --border --prompt='breadcrumb> ' --bind='double-click:accept')
    [[ -z "$selected" ]] && return 0
    target="${selected#* -> }"
  else
    printf '\nBreadcrumb targets:\n'
    printf '  %s\n' "${choices[@]}"
    read -r '?Jump to breadcrumb number: ' index
    [[ "$index" != <-> ]] && return 0
    target="${COOL_BREADCRUMB_PATHS[$index]:-}"
  fi

  [[ -z "$target" ]] && return 0
  cd "$target"
}

cool_jump_breadcrumb_widget() {
  cool_jump_breadcrumb
  zle reset-prompt
}
zle -N cool_jump_breadcrumb_widget
bindkey '^[b' cool_jump_breadcrumb_widget

# Pill-style prompt around shell-native breadcrumbs.
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
  local quotes_file=\"$HOME/$QUOTES_RELATIVE_DEFAULT\"
  if [[ -r \"\$quotes_file\" ]]; then
    grep -v '^[[:space:]]*$' \"\$quotes_file\" | shuf -n 1 | sed $'s/.*/\\e[38;5;110m&\\e[0m/'
  fi
}

if [[ -o interactive ]]; then
  cool_random_quote
fi
EOF_ZSH
}

write_fish_config() {
  local common_file="$1"
  mkdir -p "$HOME/.config/fish/functions"
  cat > "$common_file".fish <<EOF_FISH
# Universal defaults for a colorful shell experience.
set -gx CLICOLOR 1
set -gx COLORTERM truecolor
set -gx EDITOR '${MICRO_BIN:-micro}'
set -gx VISUAL '${MICRO_BIN:-micro}'
set -gx PAGER 'less -R'
set -gx MANPAGER 'less -R'
set -gx FZF_DEFAULT_OPTS '--height=40% --layout=reverse --border --color=fg:#d0d0d0,bg:#101010,hl:#ffcc66,fg+:#ffffff,bg+:#202020,hl+:#8ccf7e,pointer:#5fd7ff,marker:#ffaf5f,prompt:#5fd7ff,spinner:#5fd7ff,header:#87afff'

# Fast directory jumping with zoxide.
if command -q zoxide
  zoxide init fish | source
end

# Random startup quote.
if status is-interactive
  set quotes_file "$HOME/$QUOTES_RELATIVE_DEFAULT"
  if test -r "$quotes_file"
    set quotes (string match -rv '^\\s*$' < "$quotes_file")
    if test (count $quotes) -gt 0
      set pick (random 1 (count $quotes))
      set_color 6FAF9F
      echo $quotes[$pick]
      set_color normal
    end
  end
end

# Pill-style prompt around the current path.
function fish_prompt
  set -l last_status $status
  if test $last_status -ne 0
    set_color ff5f87
    printf '[%s] ' $last_status
  end
  set_color -b 005f87 ffffff
  printf '  %s  ' (prompt_pwd)
  set_color normal
  printf '\n$ '
end

# Category: safer and more informative file operations.
alias cp 'cp -iv'                  # Confirm before overwriting while copying.
alias mv 'mv -iv'                  # Confirm before overwriting while moving.
alias rm 'rm -Iv'                  # Ask once before large or dangerous deletes.
alias mkdir 'mkdir -pv'            # Create parents automatically and show what happened.

# Category: navigation shortcuts.
alias cd.. 'cd ..'                 # Fix the common missing-space typo.
alias .. 'cd ..'                   # Jump up one directory quickly.
alias ... 'cd ../..'               # Jump up two directory levels.
alias .... 'cd ../../..'           # Jump up three directory levels.
alias ..... 'cd ../../../..'       # Jump up four directory levels.
alias home 'cd ~'                  # Return to the home directory.
alias desk 'cd ~/Desktop; or cd ~' # Go to Desktop when it exists.
alias dl 'cd ~/Downloads; or cd ~' # Go to Downloads when it exists.

# Category: colorful modern replacements.
EOF_FISH

  if [[ -n "$EZA_BIN" ]]; then
    cat >> "$common_file".fish <<EOF_FISH
alias ls '${EZA_BIN} --group-directories-first --icons=auto --color=always'            # Better ls with icons and color.
alias ll '${EZA_BIN} -lah --group-directories-first --icons=auto --git --color=always' # Detailed directory view.
alias la '${EZA_BIN} -a --group-directories-first --icons=auto --color=always'         # Show hidden files too.
alias lt '${EZA_BIN} --tree --level=2 --icons=auto --color=always'                     # Small tree view of the current directory.
EOF_FISH
  else
    cat >> "$common_file".fish <<'EOF_FISH'
alias ls 'ls --color=auto -F'       # Fall back to GNU ls with color.
alias ll 'ls --color=auto -lahF'    # Detailed fallback ls view.
alias la 'ls --color=auto -A'       # Show hidden files in fallback ls mode.
alias lt 'tree -C -L 2'             # Tree-style view with colors.
EOF_FISH
  fi

  cat >> "$common_file".fish <<'EOF_FISH'

# Category: colorful search and text inspection.
alias grep 'grep --color=auto'      # Highlight grep matches.
alias egrep 'egrep --color=auto'    # Highlight grep matches with extended regex.
alias fgrep 'fgrep --color=auto'    # Highlight fixed-string grep matches.
EOF_FISH

  if [[ -n "$RG_BIN" ]]; then
    cat >> "$common_file".fish <<EOF_FISH
alias rg '${RG_BIN} --colors=match:fg:yellow --colors=path:fg:cyan --smart-case'       # Faster recursive search with readable colors.
EOF_FISH
  fi

  if [[ -n "$BAT_BIN" ]]; then
    cat >> "$common_file".fish <<EOF_FISH
alias cat '${BAT_BIN} --paging=never --style=plain --color=always'                     # Use bat for colorful file output.
alias ccat '${BAT_BIN} --paging=never --style=numbers,changes --color=always'          # Show files with line numbers and highlighting.
alias diff '${BAT_BIN} --diff --paging=never --color=always'                           # Read small diffs with syntax-aware coloring.
EOF_FISH
  fi

  if [[ -n "$FD_BIN" ]]; then
    cat >> "$common_file".fish <<EOF_FISH
alias fd '${FD_BIN} --hidden --follow'                                                  # Fast file finder that includes hidden files.
EOF_FISH
  fi

  cat >> "$common_file".fish <<EOF_FISH

# Category: system helpers.
alias df 'df -h'                    # Human-readable disk usage.
alias du 'du -h'                    # Human-readable directory usage.
alias free 'free -h'                # Human-readable memory output.
alias path 'printf "%s\\n" \$PATH'  # Print PATH entries on separate lines.
alias ports 'ss -tulpn'             # Show listening ports and processes.
alias psg 'ps aux | grep -i'        # Quick process search helper.
alias weather 'curl wttr.in'        # Ask wttr.in for a quick weather snapshot.
alias myip 'curl -4 ifconfig.me'    # Show your public IPv4 address.
alias update 'sudo apt-get update && sudo apt-get upgrade -y'   # Refresh and upgrade packages.
alias fixbroken 'sudo apt-get install -f'                       # Repair broken package dependencies.
alias cls 'clear'                   # Clear the terminal screen.

# Category: modern tool launchers.
EOF_FISH

  if [[ -n "$BTOP_BIN" ]]; then
    cat >> "$common_file".fish <<EOF_FISH
alias top '${BTOP_BIN}'             # Launch btop instead of the older top interface.
alias htop '${BTOP_BIN}'            # Point htop muscle memory at btop.
EOF_FISH
  fi

  if [[ -n "$FASTFETCH_BIN" ]]; then
    cat >> "$common_file".fish <<EOF_FISH
alias neofetch '${FASTFETCH_BIN}'   # Use fastfetch where people expect neofetch.
EOF_FISH
  fi

  if [[ -n "$MICRO_BIN" ]]; then
    cat >> "$common_file".fish <<EOF_FISH
alias nano '${MICRO_BIN}'           # Use micro as a friendlier terminal editor.
alias edit '${MICRO_BIN}'           # Quick edit shortcut.
EOF_FISH
  fi
}

write_xonsh_config() {
  local common_file="$1"
  cat > "$common_file".xonsh <<EOF_XONSH
# History and color defaults.
$XONSH_HISTORY_SIZE = (50000, 'commands')
$AUTO_CD = True
$COMPLETIONS_DISPLAY = 'multi'
$XONSH_COLOR_STYLE = 'monokai'
$PROMPT_TOOLKIT_COLOR_DEPTH = 'DEPTH_24_BIT'
$EDITOR = '${MICRO_BIN:-micro}'
$VISUAL = '${MICRO_BIN:-micro}'
$PAGER = 'less -R'
$MANPAGER = 'less -R'
$FZF_DEFAULT_OPTS = '--height=40% --layout=reverse --border --color=fg:#d0d0d0,bg:#101010,hl:#ffcc66,fg+:#ffffff,bg+:#202020,hl+:#8ccf7e,pointer:#5fd7ff,marker:#ffaf5f,prompt:#5fd7ff,spinner:#5fd7ff,header:#87afff'

# Fast directory jumping with zoxide.
if $(which zoxide):
    execx($(zoxide init xonsh), 'zoxide-init.xsh', 'exec')

# Random startup quote.
def _cool_random_quote():
    import pathlib
    import random
    quotes_file = pathlib.Path.home() / '$QUOTES_RELATIVE_DEFAULT'
    if quotes_file.exists():
        quotes = [line.strip() for line in quotes_file.read_text().splitlines() if line.strip()]
        if quotes:
            print("\033[38;5;110m" + random.choice(quotes) + "\033[0m")

if $XONSH_INTERACTIVE:
    _cool_random_quote()

# Pill-style prompt around the current path.
def _cool_prompt():
    import os
    last = $__xonsh__.history.last_cmd_rtn
    prefix = f"\033[38;5;203m[{last}] \033[0m" if last else ""
    return prefix + f"\033[48;5;24m\033[38;5;255m  {os.getcwd()}  \033[0m\n$ "

$PROMPT = _cool_prompt

# Category: safer and more informative file operations.
alias cp = ['cp', '-iv']             # Confirm before overwriting while copying.
alias mv = ['mv', '-iv']             # Confirm before overwriting while moving.
alias rm = ['rm', '-Iv']             # Ask once before large or dangerous deletes.
alias mkdir = ['mkdir', '-pv']       # Create parents automatically and show what happened.

# Category: navigation shortcuts.
alias cd.. = ['cd', '..']            # Fix the common missing-space typo.
alias .. = ['cd', '..']              # Jump up one directory quickly.
alias ... = ['cd', '../..']          # Jump up two directory levels.
alias .... = ['cd', '../../..']      # Jump up three directory levels.
alias ..... = ['cd', '../../../..']  # Jump up four directory levels.

# Category: colorful modern replacements.
EOF_XONSH

  if [[ -n "$EZA_BIN" ]]; then
    cat >> "$common_file".xonsh <<EOF_XONSH
alias ls = ['${EZA_BIN}', '--group-directories-first', '--icons=auto', '--color=always']
alias ll = ['${EZA_BIN}', '-lah', '--group-directories-first', '--icons=auto', '--git', '--color=always']
alias la = ['${EZA_BIN}', '-a', '--group-directories-first', '--icons=auto', '--color=always']
alias lt = ['${EZA_BIN}', '--tree', '--level=2', '--icons=auto', '--color=always']
EOF_XONSH
  else
    cat >> "$common_file".xonsh <<'EOF_XONSH'
alias ls = ['ls', '--color=auto', '-F']
alias ll = ['ls', '--color=auto', '-lahF']
alias la = ['ls', '--color=auto', '-A']
alias lt = ['tree', '-C', '-L', '2']
EOF_XONSH
  fi

  cat >> "$common_file".xonsh <<'EOF_XONSH'

# Category: colorful search and text inspection.
alias grep = ['grep', '--color=auto']
alias egrep = ['egrep', '--color=auto']
alias fgrep = ['fgrep', '--color=auto']
EOF_XONSH

  if [[ -n "$RG_BIN" ]]; then
    cat >> "$common_file".xonsh <<EOF_XONSH
alias rg = ['${RG_BIN}', '--colors=match:fg:yellow', '--colors=path:fg:cyan', '--smart-case']
EOF_XONSH
  fi

  if [[ -n "$BAT_BIN" ]]; then
    cat >> "$common_file".xonsh <<EOF_XONSH
alias cat = ['${BAT_BIN}', '--paging=never', '--style=plain', '--color=always']
alias ccat = ['${BAT_BIN}', '--paging=never', '--style=numbers,changes', '--color=always']
alias diff = ['${BAT_BIN}', '--diff', '--paging=never', '--color=always']
EOF_XONSH
  fi

  if [[ -n "$FD_BIN" ]]; then
    cat >> "$common_file".xonsh <<EOF_XONSH
alias fd = ['${FD_BIN}', '--hidden', '--follow']
EOF_XONSH
  fi

  cat >> "$common_file".xonsh <<EOF_XONSH

# Category: system helpers.
alias df = ['df', '-h']
alias du = ['du', '-h']
alias free = ['free', '-h']
alias ports = ['ss', '-tulpn']
alias weather = ['curl', 'wttr.in']
alias myip = ['curl', '-4', 'ifconfig.me']
alias cls = ['clear']

# Category: modern tool launchers.
EOF_XONSH

  if [[ -n "$BTOP_BIN" ]]; then
    cat >> "$common_file".xonsh <<EOF_XONSH
alias top = ['${BTOP_BIN}']
alias htop = ['${BTOP_BIN}']
EOF_XONSH
  fi

  if [[ -n "$FASTFETCH_BIN" ]]; then
    cat >> "$common_file".xonsh <<EOF_XONSH
alias neofetch = ['${FASTFETCH_BIN}']
EOF_XONSH
  fi

  if [[ -n "$MICRO_BIN" ]]; then
    cat >> "$common_file".xonsh <<EOF_XONSH
alias nano = ['${MICRO_BIN}']
alias edit = ['${MICRO_BIN}']
EOF_XONSH
  fi
}

write_nushell_config() {
  local common_file="$1"
  cat > "$common_file".nu <<EOF_NU
# Nushell startup customizations.
$env.config = ($env.config | upsert show_banner false)
$env.EDITOR = '${MICRO_BIN:-micro}'
$env.VISUAL = '${MICRO_BIN:-micro}'
$env.PAGER = 'less -R'
$env.MANPAGER = 'less -R'
$env.COLORTERM = 'truecolor'
$env.FZF_DEFAULT_OPTS = '--height=40% --layout=reverse --border --color=fg:#d0d0d0,bg:#101010,hl:#ffcc66,fg+:#ffffff,bg+:#202020,hl+:#8ccf7e,pointer:#5fd7ff,marker:#ffaf5f,prompt:#5fd7ff,spinner:#5fd7ff,header:#87afff'

# Fast directory jumping with zoxide.
if (which zoxide | length) > 0 {
  zoxide init nushell | save -f ~/.zoxide.nu
  source ~/.zoxide.nu
}

# Random startup quote.
def cool-random-quote [] {
  let quotes_file = ($nu.home-path | path join '$QUOTES_RELATIVE_DEFAULT')
  if ($quotes_file | path exists) {
    let quotes = (open $quotes_file | lines | where ($it | str trim | is-not-empty))
    if ($quotes | length) > 0 {
      let pick = (random int 0..(($quotes | length) - 1))
      print $"(ansi green_bold)(($quotes | get $pick))(ansi reset)"
    }
  }
}

# Pill-style prompt around the current path.
$env.PROMPT_COMMAND = {||
  let code = $env.LAST_EXIT_CODE?
  let prefix = if ($code != null and $code != 0) { $"(ansi red_bold)[($code)] (ansi reset)" } else { "" }
  $"($prefix)(ansi white)(ansi bg_blue)  (pwd)  (ansi reset)\n$ "
}

cool-random-quote

# Category: safer and more informative file operations.
alias cp = ^cp -iv               # Confirm before overwriting while copying.
alias mv = ^mv -iv               # Confirm before overwriting while moving.
alias rm = ^rm -Iv               # Ask once before large or dangerous deletes.
alias mkdir = ^mkdir -pv         # Create parents automatically and show what happened.

# Category: navigation shortcuts.
alias cd.. = cd ..               # Fix the common missing-space typo.
alias .. = cd ..                 # Jump up one directory quickly.
alias ... = cd ../..             # Jump up two directory levels.
alias .... = cd ../../..         # Jump up three directory levels.
alias ..... = cd ../../../..     # Jump up four directory levels.

# Category: colorful modern replacements.
EOF_NU

  if [[ -n "$EZA_BIN" ]]; then
    cat >> "$common_file".nu <<EOF_NU
alias ls = ^${EZA_BIN} --group-directories-first --icons=auto --color=always
alias ll = ^${EZA_BIN} -lah --group-directories-first --icons=auto --git --color=always
alias la = ^${EZA_BIN} -a --group-directories-first --icons=auto --color=always
alias lt = ^${EZA_BIN} --tree --level=2 --icons=auto --color=always
EOF_NU
  else
    cat >> "$common_file".nu <<'EOF_NU'
alias ls = ^ls --color=auto -F
alias ll = ^ls --color=auto -lahF
alias la = ^ls --color=auto -A
alias lt = ^tree -C -L 2
EOF_NU
  fi

  cat >> "$common_file".nu <<'EOF_NU'

# Category: colorful search and text inspection.
alias grep = ^grep --color=auto
alias egrep = ^egrep --color=auto
alias fgrep = ^fgrep --color=auto
EOF_NU

  if [[ -n "$RG_BIN" ]]; then
    cat >> "$common_file".nu <<EOF_NU
alias rg = ^${RG_BIN} --colors=match:fg:yellow --colors=path:fg:cyan --smart-case
EOF_NU
  fi

  if [[ -n "$BAT_BIN" ]]; then
    cat >> "$common_file".nu <<EOF_NU
alias cat = ^${BAT_BIN} --paging=never --style=plain --color=always
alias ccat = ^${BAT_BIN} --paging=never --style=numbers,changes --color=always
alias diff = ^${BAT_BIN} --diff --paging=never --color=always
EOF_NU
  fi

  if [[ -n "$FD_BIN" ]]; then
    cat >> "$common_file".nu <<EOF_NU
alias fd = ^${FD_BIN} --hidden --follow
EOF_NU
  fi

  cat >> "$common_file".nu <<EOF_NU

# Category: system helpers.
alias df = ^df -h
alias du = ^du -h
alias free = ^free -h
alias ports = ^ss -tulpn
alias weather = ^curl wttr.in
alias myip = ^curl -4 ifconfig.me
alias cls = clear

# Category: modern tool launchers.
EOF_NU

  if [[ -n "$BTOP_BIN" ]]; then
    cat >> "$common_file".nu <<EOF_NU
alias top = ^${BTOP_BIN}
alias htop = ^${BTOP_BIN}
EOF_NU
  fi

  if [[ -n "$FASTFETCH_BIN" ]]; then
    cat >> "$common_file".nu <<EOF_NU
alias neofetch = ^${FASTFETCH_BIN}
EOF_NU
  fi

  if [[ -n "$MICRO_BIN" ]]; then
    cat >> "$common_file".nu <<EOF_NU
alias nano = ^${MICRO_BIN}
alias edit = ^${MICRO_BIN}
EOF_NU
  fi
}

apply_config() {
  local quotes_path="$1"
  local tmpdir
  tmpdir=$(mktemp -d)
  trap 'rm -rf "$tmpdir"' RETURN

  local common_file="$tmpdir/common"
  write_shell_common "$common_file"

  case "$SHELL_CHOICE" in
    bash)
      write_bash_config "$common_file"
      cat "$common_file" "$common_file".bash > "$tmpdir/final"
      append_block "$HOME/.bashrc" "$tmpdir/final"
      ;;
    zsh)
      write_zsh_config "$common_file"
      cat "$common_file" "$common_file".zsh > "$tmpdir/final"
      append_block "$HOME/.zshrc" "$tmpdir/final"
      ;;
    fish)
      write_fish_config "$common_file"
      append_block "$HOME/.config/fish/config.fish" "$common_file".fish
      ;;
    xonsh)
      write_xonsh_config "$common_file"
      append_block "$HOME/.xonshrc" "$common_file".xonsh
      ;;
    nushell)
      mkdir -p "$HOME/.config/nushell"
      write_nushell_config "$common_file"
      append_block "$HOME/.config/nushell/config.nu" "$common_file".nu
      ;;
  esac

  log "Installed quotes file to $quotes_path"
}

set_login_shell() {
  local shell_path=""
  case "$SHELL_CHOICE" in
    bash) shell_path=$(command -v bash || true) ;;
    zsh) shell_path=$(command -v zsh || true) ;;
    fish) shell_path=$(command -v fish || true) ;;
    xonsh) shell_path=$(command -v xonsh || true) ;;
    nushell) shell_path=$(command -v nu || true) ;;
  esac

  if [[ -z "$shell_path" ]]; then
    warn "Could not find the installed shell binary for $SHELL_CHOICE, so the login shell was not changed."
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
  Core foundations:
    - git: version control for almost every development workflow.
    - curl / wget: fetch URLs and download files from the terminal.
    - unzip / zip: pack and unpack archives quickly.
    - build-essential / pkg-config: basic compiler toolchain for building native packages.

  Navigation and search:
    - zoxide: smart cd replacement that learns where you go.
    - ripgrep: extremely fast recursive text search.
    - fzf: interactive fuzzy finder for files, history, and commands.
    - fd-find: modern find replacement with simple syntax.

  Editing and viewing:
    - micro: friendly terminal editor with modern keybindings.
    - bat: cat replacement with syntax highlighting and git-aware decorations.
    - jq: great for inspecting and transforming JSON.
    - less: pager configured for color-aware output.

  System insight:
    - btop: modern process viewer and resource dashboard.
    - fastfetch: quick system summary for a fresh shell.
    - ncdu: fast disk usage explorer.
    - tree: directory tree viewer.

  WSL quality-of-life:
    - wslu: helpers for opening files, links, and paths between WSL and Windows.

  Modern directory listing:
    - eza: colorful ls replacement with icons and tree views.

  Handy docs:
    - tldr: short community-maintained command examples.
TEXT
}

main() {
  print_intro
  print_package_plan
  choose_shell
  choose_quotes
  ensure_ppas_if_needed
  install_packages
  resolve_binaries
  local quotes_path
  quotes_path=$(copy_quotes_file "$QUOTES_SOURCE")
  apply_config "$quotes_path"
  set_login_shell

  cat <<EOF_DONE

Done.

Selected shell: $SHELL_CHOICE
Quotes file:    $quotes_path

Next steps:
  1) Restart your terminal, or run: exec $(case "$SHELL_CHOICE" in bash) echo bash ;; zsh) echo zsh ;; fish) echo fish ;; xonsh) echo xonsh ;; nushell) echo nu ;; esac)
  2) Switch your terminal font to a Nerd Font for the prompt symbols.
  3) Edit your quotes at: $quotes_path
  4) Explore the installed tools with: fastfetch, btop, zoxide, fzf, bat, rg, ncdu, eza, and tldr
EOF_DONE
}

main "$@"
