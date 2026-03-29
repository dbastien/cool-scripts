[CmdletBinding()]
param(
  [Parameter(Position = 0)] [string]$Pattern,
  [Parameter(Position = 1)] [string]$Replacement = "",
  [Parameter(Position = 2)] [string]$Path,

  [Parameter(ValueFromPipeline = $true)]
  $InputObject,
  [Alias("i")]
  [switch]$InPlace
)

begin {
  $__sp = $PSScriptRoot
  if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
  $__root = Split-Path $__sp -Parent
  $__common = Join-Path $__root 'lib\common.ps1'
  if (Test-Path -LiteralPath $__common) { . $__common }

  $script:ToastySedLines = [System.Collections.Generic.List[string]]::new()
}

process {
  if (-not $Path -and $null -ne $InputObject) {
    $script:ToastySedLines.Add($InputObject.ToString()) | Out-Null
  }
}

end {
  try {
    if ($Path) {
      if (-not (Test-Path -LiteralPath $Path)) {
        if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
          Write-ToastyMsg "sed: not found: $Path" Err
        }
        exit 1
      }
      if ($InPlace) {
        $raw = Get-Content -LiteralPath $Path -Raw
        $out = $raw -replace $Pattern, $Replacement
        Set-Content -LiteralPath $Path -Value $out -NoNewline
        if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
          Write-ToastyMsg "sed: updated $Path" Ok
        }
      } else {
        Get-Content -LiteralPath $Path | ForEach-Object { $_ -replace $Pattern, $Replacement }
      }
    } else {
      foreach ($ln in $script:ToastySedLines) {
        $ln -replace $Pattern, $Replacement
      }
    }
  } catch {
    if (Get-Command Write-ToastyMsg -ErrorAction SilentlyContinue) {
      Write-ToastyMsg "sed: $($_)" Err
    }
    exit 1
  }
}