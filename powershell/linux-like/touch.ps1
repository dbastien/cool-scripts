function touch { param([string]$Path) if (Test-Path $Path) {(Get-Item $Path).LastWriteTime=Get-Date} else { New-Item -ItemType File -Path $Path | Out-Null } }
