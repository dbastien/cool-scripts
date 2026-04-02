[CmdletBinding()]
param(
  [Parameter(Position = 0)] [string]$Path,

  [Parameter(ValueFromPipeline = $true)]
  $InputObject,

  [string[]]$Property,
  [int]$Depth = 99,
  [switch]$Raw,
  [switch]$Compress
)

begin {
  $__sp = $PSScriptRoot
  if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
  $__root = Split-Path $__sp -Parent
  $__common = Join-Path $__root 'lib\common.ps1'
  if (Test-Path -LiteralPath $__common) { . $__common }

  $script:ToastyJqChunks = [System.Collections.Generic.List[string]]::new()
}

process {
  if (-not $Path -and $null -ne $InputObject) {
    $script:ToastyJqChunks.Add($InputObject.ToString()) | Out-Null
  }
}

end {
  try {
    if ($Path) {
      $jsonText = Get-Content -LiteralPath $Path -Raw
    } else {
      $jsonText = ($script:ToastyJqChunks -join "`n").TrimEnd()
    }
  } catch {
    if (Get-Command Write-PTMsg -ErrorAction SilentlyContinue) {
      Write-PTMsg "jq: read failed: $($_)" Err
    }
    exit 1
  }

  if ([string]::IsNullOrWhiteSpace($jsonText)) { return }

  try {
    $obj = $jsonText | ConvertFrom-Json -ErrorAction Stop
  } catch {
    if (Get-Command Write-PTMsg -ErrorAction SilentlyContinue) {
      Write-PTMsg "jq: invalid JSON: $($_)" Err
    }
    exit 1
  }

  if ($Property -and $Property.Count -gt 0) {
    $obj = $obj | Select-Object -Property $Property
  }

  if ($Raw) {
    $obj
  } else {
    if ($Compress) { $obj | ConvertTo-Json -Depth $Depth -Compress }
    else { $obj | ConvertTo-Json -Depth $Depth }
  }
}