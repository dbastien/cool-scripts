param(
    [Parameter(ValueFromPipeline=$true)]
    $InputObject,

    [Alias("l")]
    [switch]$Lines,

    [Alias("w")]
    [switch]$Words,

    [Alias("c")]
    [switch]$Bytes,

    [Alias("m")]
    [switch]$Chars,

    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Path
)

begin {
    $targets = @()
    $piped = @()
    $anyFlag = $Lines -or $Words -or $Bytes -or $Chars
}

process {
    if ($null -ne $InputObject) { $piped += $InputObject }
}

end {
    if ($Path) { $targets += $Path }

    function Count-Text([string]$text, [string]$label) {
        $lineCount = 0
        if ($text.Length -gt 0) {
            # GNU-ish: number of '\n'
            $lineCount = ([regex]::Matches($text, "`n")).Count
        }
        $wordCount = ([regex]::Matches($text, '\S+')).Count
        $charCount = $text.Length
        $byteCount = [System.Text.Encoding]::UTF8.GetByteCount($text)

        $cols = @()
        if (-not $anyFlag -or $Lines) { $cols += $lineCount }
        if (-not $anyFlag -or $Words) { $cols += $wordCount }
        if (-not $anyFlag -or $Bytes) { $cols += $byteCount }
        if ($anyFlag -and $Chars) { $cols += $charCount }

        if ($label) { $cols += $label }
        ($cols -join " ")
    }

    if ($targets.Count -gt 0) {
        foreach ($p in $targets) {
            if (-not (Test-Path -LiteralPath $p)) {
                Write-Error "wc: not found: $p"
                continue
            }
            $text = Get-Content -LiteralPath $p -Raw -ErrorAction Stop
            Count-Text $text $p
        }
        return
    }

    if ($piped.Count -gt 0) {
        $text = ($piped | ForEach-Object { $_.ToString() }) -join "`n"
        Count-Text $text ""
    }
}
