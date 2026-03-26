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
  $__common = Join-Path $__root 'SharedLibs\ShortCommon.ps1'
  if (Test-Path -LiteralPath $__common) { . $__common }

  $script:ShortPs1SortuAcc = [System.Collections.Generic.List[string]]::new()
}

process {
  if ($Path) { return }
  if ($null -ne $InputObject) {
    $script:ShortPs1SortuAcc.Add($InputObject.ToString()) | Out-Null
  }
}

end {
  if ($Path) {
    if (-not (Test-Path -LiteralPath $Path)) {
      if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
        Write-ShortPs1Msg "sortu: not found: $Path" Err
      }
      exit 1
    }
    Get-Content -LiteralPath $Path | Sort-Object -Unique
    return
  }
  $script:ShortPs1SortuAcc | Sort-Object -Unique
}
