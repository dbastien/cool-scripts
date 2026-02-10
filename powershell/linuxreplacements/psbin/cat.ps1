param(
    [Alias("n")]
    [switch]$Number,

    [Parameter(ValueFromPipeline=$true)]
    $InputObject,

    [Parameter(ValueFromRemainingArguments=$true)]
    [string[]]$Path
)

begin {
    $sawPipe = $false
    $lineNo = 1
    function Emit-Lines([string]$text) {
        $lines = $text -split "`n", -1
        foreach ($ln in $lines) {
            $out = $ln.TrimEnd("`r")
            if ($Number) {
                "{0,6}  {1}" -f $lineNo, $out
                $lineNo++
            } else {
                $out
            }
        }
    }
}

process {
    if ($null -ne $InputObject) {
        $sawPipe = $true
        Emit-Lines ($InputObject.ToString())
    }
}

end {
    if ($Path -and $Path.Count -gt 0) {
        foreach ($p in $Path) {
            if (-not (Test-Path -LiteralPath $p)) {
                Write-Error "cat: not found: $p"
                continue
            }
            $text = Get-Content -LiteralPath $p -Raw -ErrorAction Stop
            Emit-Lines $text
        }
    } elseif (-not $sawPipe) {
        # No args, no pipeline: behave like cat waiting for stdin (PowerShell already handles this awkwardly).
    }
}
