# Forwards to toasty\Install-PsBin.ps1 (copy cli + shell helpers to psbin).
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '..\toasty\Install-PsBin.ps1') @args
