#requires -Version 7.2
BeforeAll {
    $script:ShortPs1Root = (Resolve-Path (Join-Path $PSScriptRoot '..')).Path
    $script:PsPow = Split-Path -Parent $script:ShortPs1Root
    $script:PtRoot = Join-Path $script:PsPow 'photontoaster'
    $script:DopeCli = Join-Path $script:PtRoot 'cli'
    $script:OldNoColor = $env:NO_COLOR
    $env:NO_COLOR = '1'
}

AfterAll {
    if ($null -eq $script:OldNoColor) {
        Remove-Item Env:\NO_COLOR -ErrorAction SilentlyContinue
    } else {
        $env:NO_COLOR = $script:OldNoColor
    }
}

Describe 'Script syntax' {
    It 'parses every PhotonToaster cli tool and shared helpers without errors' {
        $paths = @(
            (Get-ChildItem -LiteralPath $script:DopeCli -Filter '*.ps1' -File).FullName
            (Join-Path $script:PtRoot 'lib\ShortCommon.ps1')
            (Join-Path $script:PtRoot 'lib\ShellAliases.ps1')
            (Join-Path $script:PtRoot 'Install-PsBin.ps1')
            (Join-Path $script:PtRoot 'Init.ps1')
            (Join-Path $script:PtRoot 'shell\QuoteOfDay.ps1')
            (Join-Path $script:PtRoot 'shell\Install-ProfileHooks.ps1')
            (Join-Path $script:PtRoot 'shell\ShortPs1Prompt.ps1')
            (Join-Path $script:ShortPs1Root 'cli\Install-Extern.ps1')
            (Join-Path $script:ShortPs1Root 'cli\WingetManifest.ps1')
            (Join-Path $script:ShortPs1Root 'SharedLibs\Install-DevDependencies.ps1')
        )
        $paths += (Get-ChildItem -LiteralPath (Join-Path $script:ShortPs1Root 'Instellator') -Filter '*.ps1' -File -ErrorAction SilentlyContinue).FullName
        foreach ($p in $paths) {
            $tokens = $null
            $errs = $null
            [void][System.Management.Automation.Language.Parser]::ParseFile($p, [ref]$tokens, [ref]$errs)
            $errs | Should -BeNullOrEmpty -Because (Split-Path -Leaf $p)
        }
    }
}

Describe 'head.ps1' {
    It 'returns the first N lines from a file' {
        $f = New-TemporaryFile
        try {
            Set-Content -LiteralPath $f -Encoding utf8 -Value @('a', 'b', 'c', 'd')
            $out = @( & (Join-Path $script:DopeCli 'head.ps1') $f.FullName 2 )
            $out.Count | Should -Be 2
            $out[0] | Should -Be 'a'
            $out[1] | Should -Be 'b'
        } finally {
            Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'tail.ps1' {
    It 'returns the last N lines from a file' {
        $f = New-TemporaryFile
        try {
            Set-Content -LiteralPath $f -Encoding utf8 -Value @('a', 'b', 'c', 'd')
            $out = @( & (Join-Path $script:DopeCli 'tail.ps1') $f.FullName 2 )
            $out.Count | Should -Be 2
            $out[0] | Should -Be 'c'
            $out[1] | Should -Be 'd'
        } finally {
            Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'cut.ps1' {
    It 'extracts fields by delimiter' {
        $line = "one,two,three"
        $out = $line | & (Join-Path $script:DopeCli 'cut.ps1') -d ',' -f '2'
        $out | Should -Be 'two'
    }
}

Describe 'sortu.ps1' {
    It 'deduplicates pipeline input' {
        $out = @( 3, 1, 2, 1 | & (Join-Path $script:DopeCli 'sortu.ps1') )
        $out -join ',' | Should -Be '1,2,3'
    }
}

Describe 'wc.ps1' {
    It 'counts lines, words, and UTF-8 bytes for a known file' {
        $f = New-TemporaryFile
        try {
            Set-Content -LiteralPath $f -Encoding utf8 -NoNewline -Value "hello world`nline2"
      $line = & (Join-Path $script:DopeCli 'wc.ps1') $f.FullName
      $line | Should -Match '^\d+ \d+ \d+(\s|$)'
        } finally {
            Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'tr.ps1' {
    It 'translates characters from pipeline input' {
        $out = 'abc' | & (Join-Path $script:DopeCli 'tr.ps1') 'a-c' 'A-C'
        $out | Should -Be 'ABC'
    }
}

Describe 'realpath.ps1' {
    It 'resolves the current directory' {
        $out = @( & (Join-Path $script:DopeCli 'realpath.ps1') '.' )
        $out.Count | Should -Be 1
        $out[0] | Should -Be (Get-Location).Path
    }
}

Describe 'which.ps1' {
    It 'finds pwsh on PATH' {
        & (Join-Path $script:DopeCli 'which.ps1') 'pwsh' | Should -Not -BeNullOrEmpty
    }

    It 'exits non-zero when the command is missing' {
        & (Join-Path $script:DopeCli 'which.ps1') '__shortps1_missing_cmd__' 2>$null
        $LASTEXITCODE | Should -Be 1
    }
}

Describe 'grep.ps1' {
    It 'matches fixed strings in a file' {
        $f = New-TemporaryFile
        try {
            Set-Content -LiteralPath $f -Encoding utf8 -Value "alpha`nbeta"
            $sel = @( & (Join-Path $script:DopeCli 'grep.ps1') -Pattern 'beta' -FixedStrings $f.FullName )
            $sel.Count | Should -Be 1
            $sel[0].Line | Should -Be 'beta'
        } finally {
            Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'env.ps1' {
    It 'prints a line for a known variable when color is disabled' {
        $name = 'SHORTPS1_TEST_ENV_' + [guid]::NewGuid().ToString('N').Substring(0, 8)
        try {
            Set-Item -Path "Env:\$name" -Value 'ok'
            $lines = @( & (Join-Path $script:DopeCli 'env.ps1') -Pattern "^${name}$" )
            ($lines -join "`n") | Should -Match "${name}=ok"
        } finally {
            Remove-Item -Path "Env:\$name" -ErrorAction SilentlyContinue
        }
    }
}

Describe 'jq.ps1' {
    It 'parses JSON from the pipeline with -Raw' {
        $obj = '{"x":42}' | & (Join-Path $script:DopeCli 'jq.ps1') -Raw
        $obj.x | Should -Be 42
    }
}

Describe 'sed.ps1' {
    It 'applies regex replace per pipeline line' {
        $out = 'foo bar' | & (Join-Path $script:DopeCli 'sed.ps1') 'bar' 'baz'
        $out | Should -Be 'foo baz'
    }
}

Describe 'touch.ps1 and head.ps1' {
    It 'creates a file then reads it' {
        $f = Join-Path ([System.IO.Path]::GetTempPath()) ("shortps1_touch_" + [guid]::NewGuid().ToString('N') + '.txt')
        try {
            & (Join-Path $script:DopeCli 'touch.ps1') $f
            Test-Path -LiteralPath $f | Should -Be $true
            $first = @( & (Join-Path $script:DopeCli 'head.ps1') $f 1 )
            $first.Count | Should -Be 0
        } finally {
            Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'xargs.ps1' {
    It 'invokes a scriptblock with piped arguments' {
        $out = 'hello' | & (Join-Path $script:DopeCli 'xargs.ps1') { param($x) ">$x<" }
        $out | Should -Be '>hello<'
    }
}

Describe 'df.ps1' {
    It 'emits drive rows' {
        $rows = @( & (Join-Path $script:DopeCli 'df.ps1') -PassThru )
        $rows.Count | Should -BeGreaterThan 0
        $rows[0].PSObject.Properties.Name | Should -Contain 'Drive'
    }
}

Describe 'uptime.ps1' {
    It 'prints an uptime-style line' {
        $line = & (Join-Path $script:DopeCli 'uptime.ps1')
        $line | Should -Match 'up '
    }
}
