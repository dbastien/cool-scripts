[CmdletBinding(DefaultParameterSetName = "ScriptBlock")]
param(
  [Parameter(Position = 0)]
  [int]$s = 2,

  [Parameter(ParameterSetName = "ScriptBlock", Position = 1, Mandatory = $true)]
  [scriptblock]$Do,

  [Parameter(ParameterSetName = "String", Position = 1, Mandatory = $true, ValueFromRemainingArguments = $true)]
  [string[]]$Command,

  [switch]$Once
)

$__sp = $PSScriptRoot
if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
$__root = Split-Path $__sp -Parent
$__common = Join-Path $__root 'lib\common.ps1'
if (Test-Path -LiteralPath $__common) { . $__common }

function Invoke-Watched {
  param([scriptblock]$Do, [string[]]$Command, [string]$ParameterSetName)

  if ($ParameterSetName -eq "ScriptBlock") {
    & $Do
  } else {
    Invoke-Expression ($Command -join " ")
  }
}

do {
  Clear-Host
  if (Get-Command Write-PTMsg -ErrorAction SilentlyContinue) {
    Write-PTMsg ("`u{1F440} watch  every ${s}s  (Ctrl+C to stop)") Accent
  }
  Write-Host (Get-Date)
  try {
    Invoke-Watched -Do $Do -Command $Command -ParameterSetName $PSCmdlet.ParameterSetName
  } catch {
    Write-Host ""
    if (Get-Command Write-PTMsg -ErrorAction SilentlyContinue) {
      Write-PTMsg $_.ToString() Err
    } else {
      Write-Host $_
    }
  }
  if ($Once) { break }
  Start-Sleep -Seconds $s
} while ($true)