param(
    [Parameter(Mandatory=$true, ValueFromRemainingArguments=$true)]
    [string[]]$Path,

    [Alias("c")]
    [switch]$NoCreate,

    [Alias("r")]
    [string]$Reference,

    [Alias("t")]
    [string]$Time
)

function Parse-TouchTime([string]$s) {
    # Accept: yyyyMMddHHmm[.ss] or any DateTime parseable string
    if ($s -match '^\d{12}(\.\d{2})?$') {
        $base = $s.Substring(0,12)
        $dt = [datetime]::ParseExact($base, 'yyyyMMddHHmm', $null)
        if ($s -match '\.(\d{2})$') {
            $dt = $dt.AddSeconds([int]$Matches[1])
        }
        return $dt
    }
    return [datetime]::Parse($s)
}

$stamp = $null
if ($Reference) {
    if (-not (Test-Path -LiteralPath $Reference)) {
        throw "touch: reference file not found: $Reference"
    }
    $stamp = (Get-Item -LiteralPath $Reference).LastWriteTime
} elseif ($Time) {
    $stamp = Parse-TouchTime $Time
} else {
    $stamp = Get-Date
}

foreach ($p in $Path) {
    if (Test-Path -LiteralPath $p) {
        $item = Get-Item -LiteralPath $p -ErrorAction Stop
        $item.LastWriteTime = $stamp
    } else {
        if (-not $NoCreate) {
            New-Item -ItemType File -Path $p -Force | Out-Null
            (Get-Item -LiteralPath $p).LastWriteTime = $stamp
        }
    }
}
