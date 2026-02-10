param(
    [Alias("d")]
    [string]$Delimiter = "`t",

    [Alias("f")]
    [Parameter(Mandatory=$true)]
    [string]$Fields,

    [Parameter(ValueFromPipeline=$true)]
    $InputObject
)

function Parse-Fields([string]$spec) {
    $set = New-Object System.Collections.Generic.SortedSet[int]
    foreach ($part in ($spec -split ',')) {
        if ($part -match '^\s*(\d+)\s*-\s*(\d+)\s*$') {
            $a = [int]$Matches[1]; $b = [int]$Matches[2]
            for ($i=$a; $i -le $b; $i++) { $set.Add($i) | Out-Null }
        } elseif ($part -match '^\s*(\d+)\s*$') {
            $set.Add([int]$Matches[1]) | Out-Null
        } else {
            throw "cut: invalid field spec: $part"
        }
    }
    return $set
}

$wanted = Parse-Fields $Fields

process {
    if ($null -eq $InputObject) { return }
    $line = $InputObject.ToString().TrimEnd("`r")
    $parts = $line -split [regex]::Escape($Delimiter), -1
    $out = @()
    foreach ($idx in $wanted) {
        $i = $idx - 1
        if ($i -ge 0 -and $i -lt $parts.Length) { $out += $parts[$i] }
    }
    ($out -join $Delimiter)
}
