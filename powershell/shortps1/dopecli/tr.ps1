[CmdletBinding()]
param(
  [Parameter(Mandatory = $false, Position = 0)]
  [string]$Set1 = "",

  [Parameter(Mandatory = $false, Position = 1)]
  [string]$Set2 = "",

  [Alias("d")]
  [switch]$Delete,

  [Alias("s")]
  [switch]$Squeeze,

  [Parameter(ValueFromPipeline = $true)]
  $InputObject
)

begin {
  $__sp = $PSScriptRoot
  if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
  $__root = Split-Path $__sp -Parent
  $__common = Join-Path $__root 'SharedLibs\ShortCommon.ps1'
  if (Test-Path -LiteralPath $__common) { . $__common }

  function Build-Map([string]$a, [string]$b) {
    $map = @{}
    $aChars = $a.ToCharArray()
    $bChars = $b.ToCharArray()
    for ($i = 0; $i -lt $aChars.Length; $i++) {
      $from = $aChars[$i]
      $to = $bChars[[Math]::Min($i, $bChars.Length - 1)]
      $map[$from] = $to
    }
    return $map
  }

  $script:ShortPs1TrMap = $null
  if (-not $Delete -and $Set1.Length -gt 0) {
    if ($Set2.Length -eq 0) {
      if (Get-Command Write-ShortPs1Msg -ErrorAction SilentlyContinue) {
        Write-ShortPs1Msg "tr: missing SET2" Err
      }
      throw "tr: missing SET2"
    }
    $script:ShortPs1TrMap = Build-Map $Set1 $Set2
  }
}

process {
  if ($null -eq $InputObject) { return }
  $text = $InputObject.ToString()
  $sb = New-Object System.Text.StringBuilder
  $last = [char]0
  $hasLast = $false
  $map = $script:ShortPs1TrMap

  foreach ($ch in $text.ToCharArray()) {
    if ($Delete -and $Set1.Contains($ch)) { continue }

    $outCh = $ch
    if ($map -and $map.ContainsKey($ch)) { $outCh = $map[$ch] }

    if ($Squeeze -and $hasLast -and $outCh -eq $last) { continue }

    [void]$sb.Append($outCh)
    $last = $outCh
    $hasLast = $true
  }

  $sb.ToString()
}