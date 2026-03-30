<#
.SYNOPSIS
  Batch-download every extension from Firefox-extensions.csv into .\extensions (forwards to FirefoxExt.ps1 -All).
#>
# Forwards to FirefoxExt.ps1 with -All and output under .\extensions.
$ErrorActionPreference = 'Stop'
$here = $PSScriptRoot
& (Join-Path $here 'FirefoxExt.ps1') -All -OutDir (Join-Path $here 'extensions') @args
