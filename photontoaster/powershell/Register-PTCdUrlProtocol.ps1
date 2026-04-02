# .SYNOPSIS
# Registers (or removes) the per-user pt-cd: URL protocol so Ctrl+click on rewritten eza links copies a cd line.
# Requires general.ls_hyperlink_ctrl_click_cd = true in config.toml and a new shell after changing it.

param([switch]$Remove)

$ErrorActionPreference = 'Stop'

$root = 'HKCU:\Software\Classes\pt-cd'
$handler = Join-Path $PSScriptRoot 'Invoke-PTCdUrl.ps1'
if (-not (Test-Path -LiteralPath $handler)) {
  Write-Error "Missing handler: $handler"
}

if ($Remove) {
  if (Test-Path -LiteralPath $root) {
    Remove-Item -LiteralPath $root -Recurse -Force
    Write-Host "Removed $root"
  } else {
    Write-Host "Nothing to remove."
  }
  exit 0
}

$pwsh = (Get-Command pwsh -ErrorAction Stop).Source
$cmd = "`"$pwsh`" -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$handler`" `"%1`""

New-Item -Path $root -Force | Out-Null
New-ItemProperty -Path $root -Name '(Default)' -Value 'URL:PhotonToaster cd (clipboard)' -PropertyType String -Force | Out-Null
New-ItemProperty -Path $root -Name 'URL Protocol' -Value '' -PropertyType String -Force | Out-Null
$open = Join-Path $root 'shell\open\command'
New-Item -Path $open -Force | Out-Null
New-ItemProperty -Path $open -Name '(Default)' -Value $cmd -PropertyType String -Force | Out-Null
Write-Host "Registered pt-cd: -> $handler"
Write-Host "Set ls_hyperlink_ctrl_click_cd = true in config.toml, reload, then Ctrl+click an eza path — paste cd with Ctrl+V."
