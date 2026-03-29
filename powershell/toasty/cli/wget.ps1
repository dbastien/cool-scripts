<#
.SYNOPSIS
  wget-like download helper (PowerShell 7+).
#>

[CmdletBinding(DefaultParameterSetName = 'Download')]
param (
  [Parameter(Mandatory = $true, ParameterSetName = 'Download')]
  [string]$Url,

  [Parameter(ParameterSetName = 'Download')]
  [string]$Output,

  [Parameter(ParameterSetName = 'Download')]
  [switch]$Resume,

  [Parameter(ParameterSetName = 'Download')]
  [int]$RetryCount = 3,

  [Parameter(ParameterSetName = 'Download')]
  [int]$RetryDelaySec = 2,

  [Parameter(ParameterSetName = 'Download')]
  [int]$ConnectTimeoutSec = 15,

  [Parameter(ParameterSetName = 'Download')]
  [int]$TimeoutSec = 300,

  [Parameter(ParameterSetName = 'Download')]
  [switch]$NoProgress,

  [Parameter(ParameterSetName = 'Help')]
  [Alias('h', '?')]
  [switch]$Help
)

$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
$__root = Split-Path $__sp -Parent
$__common = Join-Path $__root 'lib\common.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

if ($PSCmdlet.ParameterSetName -eq 'Help') {
  Get-Help -Name $PSCommandPath -Full
  return
}

try {
  $uri = [Uri]$Url

  if (-not $Output) {
    $Output = Split-Path -Path $uri.AbsolutePath -Leaf
    if ([string]::IsNullOrWhiteSpace($Output)) { $Output = "download.bin" }
  } else {
    $looksLikeDir =
      (Test-Path -LiteralPath $Output -PathType Container) -or
      $Output.EndsWith([IO.Path]::DirectorySeparatorChar) -or
      $Output.EndsWith([IO.Path]::AltDirectorySeparatorChar)

    if ($looksLikeDir) {
      $leaf = Split-Path -Path $uri.AbsolutePath -Leaf
      if ([string]::IsNullOrWhiteSpace($leaf)) { $leaf = "download.bin" }
      $Output = Join-Path -Path $Output -ChildPath $leaf
    }
  }

  $parent = Split-Path -Path $Output -Parent
  if ($parent -and -not (Test-Path -LiteralPath $parent -PathType Container)) {
    New-Item -ItemType Directory -Path $parent -Force | Out-Null
  }

  $urlDisp = $Url
  $outDisp = $Output
  if (Get-Command Format-ToastyUrlLink -ErrorAction SilentlyContinue) {
    $urlDisp = Format-ToastyUrlLink -Url $Url -Display $Url
  }
  if (Get-Command Format-ToastyPathLink -ErrorAction SilentlyContinue) {
    try { $outDisp = Format-ToastyPathLink -Path $Output -Display $Output } catch { }
  }

  if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
    Write-ToastyMsg ("Downloading: " + $urlDisp) Info
    Write-ToastyMsg ("Saving as:   " + $outDisp) Info
  } else {
    Write-Host "Downloading from URL: $Url"
    Write-Host "Saving as: $Output"
  }

  $oldProgress = $ProgressPreference
  if ($NoProgress) { $ProgressPreference = 'SilentlyContinue' }

  Invoke-WebRequest `
    -Uri $uri `
    -OutFile $Output `
    -Resume:$Resume `
    -MaximumRetryCount $RetryCount `
    -RetryIntervalSec $RetryDelaySec `
    -ConnectionTimeoutSeconds $ConnectTimeoutSec `
    -OperationTimeoutSeconds $TimeoutSec `
    -ErrorAction Stop | Out-Null

  if ($NoProgress) { $ProgressPreference = $oldProgress }

  if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
    Write-ToastyMsg "Download complete." Ok
  } else {
    Write-Host "Download complete!"
  }
} catch {
  try {
    if ($NoProgress) { $ProgressPreference = $oldProgress }
  } catch { }

  if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
    Write-ToastyMsg "Error: $($_.Exception.Message)" Err
  } else {
    Write-Host "Error: $($_.Exception.Message)"
  }
  exit 1
}