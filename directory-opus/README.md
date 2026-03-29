# Directory Opus helpers

Small scripts and installers for [Directory Opus](https://www.gpsoft.com.au/) on Windows. Install paths and UI labels refer to recent Opus 12/13; adjust if your build differs.

| File | What it is |
|------|------------|
| [`compact-size-column.js`](compact-size-column.js) | **Script add-in** — adds a **c.size** column (compact `B`/`K`/`M`/…, files only; folders stay blank for speed). Install via **Preferences → Toolbars / Scripts → Script Add-Ins**, then add the column under **File Displays → Columns**. |
| [`rename-no-duplicate-extension.js`](rename-no-duplicate-extension.js) | **Advanced Rename script only** (`OnGetNewName`). Collapses doubled extensions, e.g. `notes.txt.txt` → `notes.txt`. **Do not** add to Script Add-Ins — Opus will log *“does not implement any known events”*. Use **Rename** → enable **Script** → **JScript** → paste or reference this file. |
| [`Go-WslResolved.ps1`](Go-WslResolved.ps1) | **PowerShell** — for `\\wsl$\…` / `\\wsl.localhost\…`, resolves symlink/junction targets with `readlink -f`, then drives the active lister via `dopusrt /acmd Go` (folders) or `Start-Process` (files). Wire **File Types** → symlink (or your link class) → **double-click** to run PowerShell with `"{filepath}"`. See the script header for the full command line. |
| [`Smart Compare.opusscriptinstall`](Smart Compare.opusscriptinstall) | Opus **script installer** package — open/import with Opus per its installer workflow (compare-related add-in; keep in this folder as a portable backup). |

Manual index: [docs.dopus.com](https://docs.dopus.com/doku.php?id=scripting)
