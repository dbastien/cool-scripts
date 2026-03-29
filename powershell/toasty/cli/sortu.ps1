[CmdletBinding()]
param(
  [Parameter(Position = 0)]
  [string]$Path,

  [Parameter(ValueFromPipeline = $true)]
  $InputObject
)

begin {
  $__sp = $PSScriptRoot
  if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
  $__root = Split-Path $__sp -Parent
  $__common = Join-Path $__root 'lib\common.ps1'
  if (Test-Path -LiteralPath $__common) { . $__common }

  $script:ToastySortuAcc = [System.Collections.Generic.List[string]]::new()
}

process {
  if ($Path) { return }
  if ($null -ne $InputObject) {
    $script:ToastySortuAcc.Add($InputObject.ToString()) | Out-Null
  }
}

end {
  if ($Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
      if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
        Write-ToastyMsg "sortu: not found: $Path" Err
      }
      exit 1
    }
    Get-Content -LiteralPath $Path | Sort-Object -Unique
    return
  }
  $script:ToastySortuAcc | Sort-Object -Unique
}
