# Directory Opus Scripts

JScript add-ins for [Directory Opus](https://www.gpsoft.com.au/). Each script registers a custom internal command you can assign to buttons or hotkeys.

## Scripts

| Script | Command | Description |
|--------|--------|-------------|
| NavigateSymlink | `NavigateSymlink` | Select a symlink/junction, run to navigate to its target |
| FlattenDirectory | `FlattenDirectory` | Move all files from subdirectories into the current folder |
| CreateDatedFolder | `CreateDatedFolder` | Create `YYYY-MM-DD` folder, optionally move selected files into it |
| ChecksumSelected | `ChecksumSelected` | SHA256 (or MD5) hash of selected files, copied to clipboard |
| ExtractHere | `ExtractHere` | Extract selected archives into current folder (no subfolder per archive) |
| AddToArchive | `AddToArchive` | Add to archive with format picker (Zip, 7z, Tar, etc.) |
| RevealInExplorer | `RevealInExplorer` | Open current folder in Windows Explorer |

### ChecksumSelected options

Use the `HASH` argument to choose algorithm:

- `ChecksumSelected` — SHA256 (default)
- `ChecksumSelected HASH=md5`
- `ChecksumSelected HASH=sha1`

## Install

1. Copy `.js` files to the Opus Script AddIns folder:
   - In Opus location bar, type: `/dopusdata/Script AddIns`
   - Or: `%APPDATA%\GPSoftware\Directory Opus\Script AddIns`
2. Or: **Prefs** → **Scripts** → drag `.js` files onto the list
3. Create a button or hotkey: **Right-click toolbar** → **New Button** → set the function to the command name (e.g. `NavigateSymlink`)

## Notes

- **FlattenDirectory**: Asks for confirmation before running. Name conflicts are auto-renamed by Opus (e.g. `file (1).txt`).
- **NavigateSymlink**: For file symlinks, navigates to the containing folder of the target.
- **ExtractHere**: Requires archives to be selected. Uses Opus built-in extract; supports zip, 7z, etc.
- **AddToArchive**: Select files first, then run. Shows a dialog to pick format (Zip, 7z, Tar, etc.) before opening the Add to Archive dialog.
