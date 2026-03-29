# Terminal Hyperlinks: Feasibility Analysis

**Environment:** WSL2 on Windows, using **Windows Terminal** (not Cursor's integrated terminal).

## TL;DR

Three questions investigated:

1. **Click to cd into folders** -- Not feasible. No terminal can execute shell commands via hyperlink clicks. Fundamental security boundary.
2. **Click ls results to open files in micro** -- Not directly feasible in Windows Terminal. WT dispatches clicks to Windows ShellExecute (default Windows app handler), and micro is a terminal-mode editor with no Windows file association. Feasible with Kitty or WezTerm which have custom open-action configs.
3. **Click to open files in Windows apps from WSL** -- Partially feasible. Windows Terminal supports OSC 8 and added `file://wsl$/` path support in 2023 (PR #14993). The catch: `ls --hyperlink=auto` generates Linux-format paths (`file:///home/user/...`) which Windows can't resolve. Requires path translation to UNC format (`file://wsl.localhost/distro/home/user/...`).

---

## How OSC 8 Works

```
\033]8;;<URL>\033\\<visible text>\033]8;;\033\\
```

The terminal renders `<visible text>` as a clickable link. On Ctrl+Click (or just click, depending on terminal), it opens `<URL>`.

**What Windows Terminal does on click:** calls Windows `ShellExecute` with the URL. This means:
- `https://` -- Opens default browser
- `file:///C:/path/to/file` -- Opens with default Windows app for that file type
- `file://wsl.localhost/Ubuntu/home/user/file` -- Opens with default Windows app (since WT PR #14993, March 2023)
- `file:///home/user/file` -- **Fails** (bare Linux path, not valid on Windows side)

**No URL scheme can inject a `cd` command into the running shell.** This is by design.

---

## Q1: Can clicking a hyperlink cd into a folder?

**No.** The terminal architecture intentionally prevents programs from executing commands in the parent shell via output. Approaches considered:

- **Shell function wrapper** -- A zsh function that parses output and offers an interactive cd prompt. Works but isn't "clickable."
- **Custom URI protocol handler** -- Register a custom scheme, but still can't inject `cd` into the calling shell without a cooperative shell function polling a file.
- **Clipboard + alias** -- Link copies path to clipboard, user types `cdc` alias. Simple but not truly clickable.
- **tmux send-keys** -- If inside tmux, a handler could `tmux send-keys "cd /path" Enter`. Actually works but ties you to tmux.

## Q2: Can ls results be clicked to open files in micro?

**Not in Windows Terminal.** micro is a terminal-mode editor -- it doesn't register as a Windows file handler, so ShellExecute can't dispatch to it. Windows Terminal has no equivalent of Kitty's `open-actions.conf` for routing clicks to custom programs ([issue #8849](https://github.com/microsoft/terminal/issues/8849) is open but not planned).

### What would work for micro

**Kitty** has `~/.config/kitty/open-actions.conf`:

```conf
# Open text files in micro
protocol file
mime text/*
action launch --type=os-window micro $FILE_PATH
```

**WezTerm** has `wezterm.lua` `open-uri` event handler with similar per-type dispatch.

Neither of these applies to Windows Terminal.

### What does work in Windows Terminal

If the path is in UNC format, clicking opens the file with the **default Windows app** for that extension. So:

- `.png` file click -- opens in Windows Photos or whatever you've set
- `.py` file click -- opens in whatever `.py` is associated with (likely VS Code or Python)
- `.txt` file click -- opens in Notepad or your default text editor

To make `.py` or `.txt` files open in a specific Windows GUI editor, change the Windows file association for that extension ("Open with" > "Choose another app" > set as default).

### The path format problem

`ls --hyperlink=auto` running in WSL generates links like `file:///home/user/file.txt`. Windows Terminal can't resolve bare Linux paths. You'd need UNC-format links: `file://wsl.localhost/Ubuntu/home/user/file.txt`.

Neither GNU `ls` nor `eza` perform this translation. A workaround would be a shell wrapper or custom `ls` alias that pipes through `wslpath -w` to produce Windows-accessible paths, but this is fragile and no standard tool does it.

## Q3: Can clicking open files in Windows apps from WSL?

**Yes, with caveats.**

### What works now (command line, no hyperlinks needed)

Install `wslu` for `wslview`:

```bash
sudo apt install wslu
wslview /path/to/file.png    # Opens in Windows default app for .png
wslview /path/to/folder      # Opens in Windows Explorer
```

Or a direct bridge function:

```bash
winopen() { explorer.exe "$(wslpath -w "$(realpath "$1")")"; }
```

### What works via OSC 8 hyperlinks in Windows Terminal

Windows Terminal added support for `file://wsl$/` and `file://wsl.localhost/` URIs in [PR #14993](https://github.com/microsoft/terminal/pull/14993) (March 2023). So if you emit an OSC 8 link with the UNC-format path, clicking it in Windows Terminal will open it with the default Windows app.

A helper function to generate WSL-aware links:

```python
import os
from pathlib import Path
from urllib.parse import quote

def _wsl_file_link(path: str, label: str | None = None) -> str:
    text = label or path
    distro = os.environ.get("WSL_DISTRO_NAME")
    if not distro:
        return text
    resolved = Path(path).expanduser().resolve(strict=False)
    posix = resolved.as_posix()
    encoded = quote(posix, safe="/")
    url = f"file://wsl.localhost/{distro}{encoded}"
    return f"\033]8;;{url}\033\\{text}\033]8;;\033\\"
```

Or in zsh:

```bash
wsl_link() {
    local path="$(realpath "$1")"
    local label="${2:-$1}"
    local distro="$WSL_DISTRO_NAME"
    [ -z "$distro" ] && echo "$label" && return
    printf '\033]8;;file://wsl.localhost/%s%s\033\\%s\033]8;;\033\\' \
        "$distro" "$path" "$label"
}
```

**Status:** Viable but untested. The WT UNC support was added in the 22H2 milestone -- should work on any recent Windows 11 + Windows Terminal.

---

## Terminal Comparison Matrix

| Capability | Windows Terminal | Kitty | WezTerm | Cursor Terminal |
|---|---|---|---|---|
| OSC 8 support | Yes | Yes | Yes | Yes |
| `file://` clicks work | Yes (Windows paths + wsl.localhost UNC) | Yes | Yes | Broken on WSL (#211443) |
| Custom click handler | No (#8849 open) | Yes (open-actions.conf) | Yes (wezterm.lua) | No |
| Open in micro on click | No | Yes | Yes | No |
| Open in Windows app | Yes (via ShellExecute) | N/A | N/A | No |
| `ls --hyperlink` works | Only with UNC paths | Yes | Yes | Broken on WSL |

---

## Recommendations

### For `ls` and daily shell use

- `ls --hyperlink=auto` won't work out of the box because of the path format issue. If you want clickable `ls` output in Windows Terminal, you'd need a wrapper that translates paths, which is brittle.
- For opening files in Windows apps, `wslview <file>` is the reliable approach today.
- For opening files in micro, just `micro <file>` -- there's no click-to-open shortcut available in Windows Terminal.

### If custom click handlers matter to you

- **Consider running Kitty or WezTerm alongside Windows Terminal.** Kitty's `open-actions.conf` gives you full control: click a `.py` file and it opens in micro, click a `.png` and it opens in feh/Windows Photos, click a directory and it runs `cd` in a new pane. This is the only terminal that can satisfy all three original use cases.

## References

- [OSC 8 spec](https://gist.github.com/egmontkob/eb114294efbcd5adb1944c9f3cb5feda)
- [Windows Terminal: file://wsl$ support (PR #14993)](https://github.com/microsoft/terminal/pull/14993)
- [Windows Terminal: custom hyperlink handlers (issue #8849)](https://github.com/microsoft/terminal/issues/8849)
- [Kitty open-actions.conf docs](https://sw.kovidgoyal.net/kitty/open_actions/)
- [VSCode WSL OSC 8 bug (#211443)](https://github.com/microsoft/vscode/issues/211443)
