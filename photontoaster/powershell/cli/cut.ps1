[CmdletBinding()]
param(
  [Alias("d")]
  [string]$Delimiter = "`t",

  [Alias("f")]
  [Parameter(Mandatory = $true)]
  [string]$Fields,

  [Alias("s")]
  [switch]$OnlyDelimited,

  [string]$OutputDelimiter,

  [Parameter(ValueFromPipeline = $true)]
  $InputObject
)

begin {
  $__sp = $PSScriptRoot
  if (-not $__sp -and $MyInvocation.MyCommand.Path) { $__sp = Split-Path -Parent $MyInvocation.MyCommand.Path }
  $__root = Split-Path $__sp -Parent
  $__common = Join-Path $__root 'lib\common.ps1'
  if (Test-Path -LiteralPath $__common) { . $__common }

  if (-not $OutputDelimiter) { $OutputDelimiter = $Delimiter }

  function Parse-Fields([string]$spec) {
    $set = New-Object System.Collections.Generic.SortedSet[int]
    foreach ($part in ($spec -split ',')) {
      if ($part -match '^\s*(\d+)\s*-\s*(\d+)\s*$') {
        $a = [int]$Matches[1]; $b = [int]$Matches[2]
        for ($i = $a; $i -le $b; $i++) { $set.Add($i) | Out-Null }
      } elseif ($part -match '^\s*(\d+)\s*$') {
        $set.Add([int]$Matches[1]) | Out-Null
      } else {
        if (Get-Command Write-PTMsg -ErrorAction SilentlyContinue) {
          Write-PTMsg "cut: invalid field spec: $part" Err
        }
        throw "cut: invalid field spec: $part"
      }
    }
    return $set
  }

  $script:ToastyCutWanted = Parse-Fields $Fields
}

process {
  if ($null -eq $InputObject) { return }
  $line = $InputObject.ToString().TrimEnd("`r")
  if ($OnlyDelimited -and -not $line.Contains($Delimiter)) {
    return
  }
  $parts = [regex]::Split($line, [regex]::Escape($Delimiter))
  $out = @()
  foreach ($idx in $script:ToastyCutWanted) {
    $i = $idx - 1
    if ($i -ge 0 -and $i -lt $parts.Length) { $out += $parts[$i] }
  }
  ($out -join $OutputDelimiter)
}