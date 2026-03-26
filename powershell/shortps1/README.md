# psbin extras: more Linux-ish commands for PowerShell

## Install
```powershell
cd .\psbin-extras-pack
.\install.ps1
```

Installs into `~/psbin` by default and adds it to your **User PATH** (won't overwrite existing files unless `-Force`).

## New commands
- sed     (regex replace; optional `-i` to edit file in place)
- sortu   (sort unique)
- jq      (JSON pretty print / select properties)
- psgrep  (search processes)
- killp   (kill processes by pattern; supports -WhatIf / -Confirm)

## Honorable mentions
- realpath
- lns     (symlink)
- tee     (wrapper around Tee-Object; `-a` for append)
- env     (print env vars; optional regex filter)
- mkcd    (mkdir + cd)

## top
- top     (refreshing process view; `-Sort cpu|mem`, `-n`, `-s`, `-Once`)

Examples:
```powershell
sed "foo" "bar" .\file.txt
sed "foo" "bar" .\file.txt -i

cat .\names.txt | sortu
jq .\data.json
jq .\data.json -Property name,id

psgrep "chrome"
killp "chrome" -WhatIf
top -Sort mem -n 25
```
