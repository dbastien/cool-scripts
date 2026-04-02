[CmdletBinding()]
param(
  [Parameter(Mandatory = $true, Position = 0)]
  $Command,

  [Alias("n")]
  [int]$MaxArgs = 0,

  [Alias("I")]
  [string]$ReplaceToken = "",

  [Parameter(ValueFromPipeline = $true)]
  $InputObject
)

begin {
  $__sp = $PSScriptRoot
  if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
  $__root = Split-Path $__sp -Parent
  $__common = Join-Path $__root 'lib\common.ps1'
  if (Test-Path -LiteralPath $__common) { . $__common }

  $items = New-Object System.Collections.Generic.List[string]
  function Invoke-Target([string[]]$Batch) {
    if ($ReplaceToken) {
      foreach ($a in $Batch) {
        if ($Command -is [scriptblock]) {
          & $Command ($a)
        } else {
          $cmdLine = ($Command.ToString()).Replace($ReplaceToken, $a)
          Invoke-Expression $cmdLine
        }
      }
      return
    }

    if ($Command -is [scriptblock]) {
      & $Command @Batch
    } else {
      & $Command @Batch
    }
  }
}

process {
  if ($null -ne $InputObject) { $items.Add($InputObject.ToString()) }
  if ($MaxArgs -gt 0 -and $items.Count -ge $MaxArgs) {
    try {
      Invoke-Target ($items.ToArray())
    } catch {
      if (Get-Command Write-PTMsg -ErrorAction SilentlyContinue) {
        Write-PTMsg "xargs: $($_)" Err
      }
      exit 1
    }
    $items.Clear()
  }
}

end {
  if ($items.Count -gt 0) {
    try {
      Invoke-Target ($items.ToArray())
    } catch {
      if (Get-Command Write-PTMsg -ErrorAction SilentlyContinue) {
        Write-PTMsg "xargs: $($_)" Err
      }
      exit 1
    }
  }
}