# Forwards to dope-shell\install.ps1 (copy dopecli + shell helpers to psbin).
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot 'dope-shell\install.ps1') @args
