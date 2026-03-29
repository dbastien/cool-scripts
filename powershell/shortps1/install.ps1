# Forwards to toasty\install.ps1 (junction + PATH + config seed).
$ErrorActionPreference = 'Stop'
& (Join-Path $PSScriptRoot '..\toasty\install.ps1') @args
