param(
    [Parameter(Mandatory=$true, Position=0)]
    $Command,

    [Alias("n")]
    [int]$MaxArgs = 0,

    [Alias("I")]
    [string]$ReplaceToken = "",

    [Parameter(ValueFromPipeline=$true)]
    $InputObject
)

begin {
    $items = New-Object System.Collections.Generic.List[string]
    function Invoke-Target([string[]]$args) {
        if ($ReplaceToken) {
            foreach ($a in $args) {
                if ($Command -is [scriptblock]) {
                    & $Command ($a)
                } else {
                    $cmdLine = ($Command.ToString()).Replace($ReplaceToken, $a)
                    Invoke-Expression $cmdLine
                }
            }
            return
        }

        if ($Command -is [scriptblock]) {
            & $Command @args
        } else {
            & $Command @args
        }
    }
}

process {
    if ($null -ne $InputObject) { $items.Add($InputObject.ToString()) }
    if ($MaxArgs -gt 0 -and $items.Count -ge $MaxArgs) {
        Invoke-Target ($items.ToArray())
        $items.Clear()
    }
}

end {
    if ($items.Count -gt 0) {
        Invoke-Target ($items.ToArray())
    }
}
