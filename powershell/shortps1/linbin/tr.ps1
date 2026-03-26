param(
    [Parameter(Mandatory=$false, Position=0)]
    [string]$Set1 = "",

    [Parameter(Mandatory=$false, Position=1)]
    [string]$Set2 = "",

    [Alias("d")]
    [switch]$Delete,

    [Alias("s")]
    [switch]$Squeeze,

    [Parameter(ValueFromPipeline=$true)]
    $InputObject
)

function Build-Map([string]$a, [string]$b) {
    $map = @{}
    $aChars = $a.ToCharArray()
    $bChars = $b.ToCharArray()
    for ($i=0; $i -lt $aChars.Length; $i++) {
        $from = $aChars[$i]
        $to = $bChars[[Math]::Min($i, $bChars.Length-1)]
        $map[$from] = $to
    }
    return $map
}

$map = $null
if (-not $Delete -and $Set1.Length -gt 0) {
    if ($Set2.Length -eq 0) { throw "tr: missing SET2" }
    $map = Build-Map $Set1 $Set2
}

process {
    if ($null -eq $InputObject) { return }
    $text = $InputObject.ToString()
    $sb = New-Object System.Text.StringBuilder
    $last = [char]0
    $hasLast = $false

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
