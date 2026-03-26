# Forwards to cli\Install-Extern.ps1 (native CLIs via winget).
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'cli\Install-Extern.ps1') @args
