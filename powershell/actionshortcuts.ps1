Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# Relaunch (STA, 64-bit, or fresh WPF)
function Relaunch-Self([string]$exePath, [string[]]$extraArgs, [string]$envVar) {
    if ($envVar) { Set-Item "env:$envVar" '1' }
    Start-Process -FilePath $exePath -ArgumentList (@('-NoProfile','-ExecutionPolicy','Bypass','-File',$PSCommandPath)+$extraArgs) | Out-Null
    exit 0
}
try {
    if (-not $env:SHELLMENUMGR_STA -and [Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
        $env:SHELLMENUMGR_STA = '1'
        $sta = if ($PSVersionTable.PSEdition -eq 'Core') { '-Sta' } else { '-STA' }
        Relaunch-Self (Get-Process -Id $PID).Path (@($sta)+$MyInvocation.UnboundArguments)
    }
} catch {}
try {
    if ([Environment]::Is64BitOperatingSystem -and -not [Environment]::Is64BitProcess -and -not $env:SHELLMENUMGR_64) {
        $env:SHELLMENUMGR_64 = '1'
        $ps = Join-Path $env:WINDIR 'sysnative\WindowsPowerShell\v1.0\powershell.exe'
        if (Test-Path -LiteralPath $ps) { Relaunch-Self $ps $MyInvocation.UnboundArguments }
    }
} catch {}

# Quota mitigation
try { [System.Windows.Media.RenderOptions]::ProcessRenderMode = [System.Windows.Interop.RenderMode]::SoftwareOnly } catch {}

# Globals
$toolPrefix   = 'ShellMenuMgr'
$sendToDir    = Join-Path $env:APPDATA 'Microsoft\Windows\SendTo'
$managedValue = 'ManagedByTool'
$managedTag   = '1'

$script:UI = [pscustomobject]@{
    App          = $null
    Dispatcher   = $null
    Window       = $null
    Elements     = @{}
    TabState     = @{
        New     = @{ Loaded=$false; Dirty=$true; Loading=$false }
        SendTo  = @{ Loaded=$false; Dirty=$true; Loading=$false }
        Verbs   = @{ Loaded=$false; Dirty=$true; Loading=$false }
        Context = @{ Loaded=$false; Dirty=$true; Loading=$false }
    }
    ResolvedProg = $null
}

# Dispatcher delegates
$script:UiBeginDelegate = [System.Action[object]]{
    param($payload)
    if ($payload -is [scriptblock]) { $payload.InvokeReturnAsIs() | Out-Null }
}
$script:UiInvokeDelegate = [System.Func[object, object]]{
    param($payload)
    if ($payload -is [scriptblock]) { return $payload.InvokeReturnAsIs() }
    return $null
}

# UI helpers
function UI-Begin([scriptblock]$sb) {
    try {
        $d = $script:UI.Dispatcher
        if (-not $d) { $sb.InvokeReturnAsIs() | Out-Null; return }
        if ($d.HasShutdownStarted -or $d.HasShutdownFinished) { return }
        $null = $d.BeginInvoke($script:UiBeginDelegate, $sb)
    } catch { }
}
function UI-Invoke([scriptblock]$sb) {
    try {
        $d = $script:UI.Dispatcher
        if (-not $d) { return $sb.InvokeReturnAsIs() }
        if ($d.HasShutdownStarted -or $d.HasShutdownFinished) { return $null }
        if ($d.CheckAccess()) { return $sb.InvokeReturnAsIs() }
        return $d.Invoke($script:UiInvokeDelegate, $sb)
    } catch { return $null }
}
function UI-SetStatus([string]$msg) {
    UI-Begin {
        $t = $script:UI.Elements['StatusText']
        if ($t) { $t.Text = $msg }
    }
}
function UI-SetGrid([string]$gridName, [object]$items) {
    UI-Begin {
        $g = $script:UI.Elements[$gridName]
        if ($g) { $g.ItemsSource = $items }
    }
}
function UI-Require([string]$name) {
    $c = $script:UI.Elements[$name]
    if (-not $c) { throw ("Missing control named '{0}' (XAML mismatch?)" -f $name) }
    $c
}

function Msg-Confirm([string]$msg, [string]$title='Confirm') {
    $r = UI-Invoke {
        try {
            [System.Windows.MessageBox]::Show($msg, $title,
                [System.Windows.MessageBoxButton]::YesNo,
                [System.Windows.MessageBoxImage]::Question)
        } catch {
            [System.Windows.MessageBoxResult]::No
        }
    }
    $r -eq [System.Windows.MessageBoxResult]::Yes
}
function Msg-Show([string]$msg, [string]$title, [System.Windows.MessageBoxImage]$icon) {
    UI-Begin {
        try { [System.Windows.MessageBox]::Show($msg, $title, [System.Windows.MessageBoxButton]::OK, $icon) | Out-Null }
        catch { $m = "{0}: {1}" -f $title,$msg; if ($icon -eq [System.Windows.MessageBoxImage]::Error) { Write-Error $m } else { Write-Warning $m } }
    }
}
function Msg-Warn([string]$msg,[string]$title='Warning') { Msg-Show $msg $title ([System.Windows.MessageBoxImage]::Warning) }
function Msg-Error([string]$msg,[string]$title='Error') { Msg-Show $msg $title ([System.Windows.MessageBoxImage]::Error) }

# Registry helpers
function Reg-ParsePath([string]$psPath) {
    if ($psPath -match '^(HKCU|HKLM|HKCR):\\(.*)$') {
        $root = $Matches[1]; $sub = $Matches[2]
        switch ($root) {
            'HKCU' { return @([Microsoft.Win32.Registry]::CurrentUser,  $sub) }
            'HKLM' { return @([Microsoft.Win32.Registry]::LocalMachine, $sub) }
            'HKCR' { return @([Microsoft.Win32.Registry]::ClassesRoot,  $sub) }
        }
    }
    @($null,$null)
}
function Reg-Open([string]$psPath, [bool]$writable=$false) {
    $bk, $sub = Reg-ParsePath $psPath
    if (-not $bk) { return $null }
    try { $bk.OpenSubKey($sub, $writable) } catch { $null }
}
function Reg-Ensure([string]$psPath) {
    if (-not (Test-Path -LiteralPath $psPath)) { New-Item -Path $psPath -Force | Out-Null }
}
function Reg-Exists([string]$psPath) {
    $k = Reg-Open $psPath $false
    if ($k) { try { $true } finally { $k.Close() } } else { $false }
}
function Reg-GetDefault([string]$psPath) {
    $k = Reg-Open $psPath $false
    if (-not $k) { return $null }
    try { $k.GetValue('') } finally { $k.Close() }
}
function Reg-GetValue([string]$psPath, [string]$name) {
    $k = Reg-Open $psPath $false
    if (-not $k) { return $null }
    try { $k.GetValue($name, $null) } finally { $k.Close() }
}
function Reg-HasValue([string]$psPath, [string]$name) {
    $k = Reg-Open $psPath $false
    if (-not $k) { return $false }
    try { $k.GetValueNames() -contains $name } finally { $k.Close() }
}
function Reg-SetValue([string]$psPath, [string]$name, [object]$value,
    [Microsoft.Win32.RegistryValueKind]$kind=[Microsoft.Win32.RegistryValueKind]::String) {

    Reg-Ensure $psPath
    $k = Reg-Open $psPath $true
    if (-not $k) { throw ("Cannot open key for write: {0}" -f $psPath) }
    try { $k.SetValue($name, $value, $kind) } finally { $k.Close() }
}
function Reg-RemoveValue([string]$psPath, [string]$name) {
    $k = Reg-Open $psPath $true
    if (-not $k) { return }
    try { $k.DeleteValue($name, $false) } finally { $k.Close() }
}
function Reg-SubKeyNames([string]$psPath) {
    $k = Reg-Open $psPath $false
    if (-not $k) { return @() }
    try { $k.GetSubKeyNames() } finally { $k.Close() }
}
function Reg-IsEmpty([string]$psPath) {
    $k = Reg-Open $psPath $false
    if (-not $k) { return $true }
    try { ($k.GetSubKeyNames().Count -eq 0) -and ($k.GetValueNames().Count -eq 0) } finally { $k.Close() }
}
function Reg-RemoveTree([string]$psPath) {
    $bk, $sub = Reg-ParsePath $psPath
    if (-not $bk) { return }
    $parent = Split-Path -Path $sub -Parent
    $leaf   = Split-Path -Path $sub -Leaf
    try {
        $pk = $bk.OpenSubKey($parent, $true)
        if ($pk) { $pk.DeleteSubKeyTree($leaf, $false); $pk.Close() }
    } catch {}
}
function Reg-CopyValues([string]$srcPath, [string]$dstPath) {
    $src = Reg-Open $srcPath $false
    if (-not $src) { return $false }
    try {
        Reg-Ensure $dstPath
        $dst = Reg-Open $dstPath $true
        if (-not $dst) { return $false }
        try {
            foreach ($name in $src.GetValueNames()) {
                $val  = $src.GetValue($name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
                $kind = $src.GetValueKind($name)
                $dst.SetValue($name, $val, $kind)
            }
            return $true
        } finally { $dst.Close() }
    } finally { $src.Close() }
}

function Tool-MarkKey([string]$psPath) { Reg-SetValue $psPath $managedValue $managedTag ([Microsoft.Win32.RegistryValueKind]::String) }
function Tool-IsMarked([string]$psPath) { (Reg-GetValue $psPath $managedValue) -eq $managedTag }

# Tab state
function Tab-IsLoading([string]$key) { $script:UI.TabState[$key].Loading }
function Tab-MarkDirty([string]$key) { $script:UI.TabState[$key].Dirty = $true }
function Tab-SetLoadedClean([string]$key) { $script:UI.TabState[$key].Loaded = $true; $script:UI.TabState[$key].Dirty = $false }
function Tab-SetLoading([string]$key, [bool]$v) { $script:UI.TabState[$key].Loading = $v }

# Async loader
function Start-TabLoad([string]$key, [scriptblock]$compute, [scriptblock]$apply) {
    if (Tab-IsLoading $key) { return }
    Tab-SetLoading $key $true
    UI-SetStatus ("Loading {0}…" -f $key)

    $bw = New-Object System.ComponentModel.BackgroundWorker
    $bw.DoWork += { param($s,$e) $e.Result = & $compute }
    $bw.RunWorkerCompleted += {
        param($s,$e)
        UI-Begin {
            Tab-SetLoading $key $false
            if ($e.Error) {
                UI-SetStatus ("{0}: Error loading: {1}" -f $key, $e.Error.Message)
                return
            }
            try {
                & $apply $e.Result
                Tab-SetLoadedClean $key
            } catch {
                UI-SetStatus ("{0}: Error applying data: {1}" -f $key, $_.Exception.Message)
            }
        }
    }
    $bw.RunWorkerAsync()
}
function Ensure-TabLoaded([string]$key, [scriptblock]$loader) {
    $s = $script:UI.TabState[$key]
    if ($s.Loading) { return }
    if (-not $s.Loaded -or $s.Dirty) { & $loader }
}

# ShellNew
function ShellNew-BackupPath([string]$extWithDot) {
    $e = $extWithDot.Trim()
    if ($e.StartsWith('.')) { $e = $e.Substring(1) }
    "HKCU:\Software\$toolPrefix\Backups\ShellNew\$e"
}

function ShellNew-ReadRootMap([Microsoft.Win32.RegistryKey]$classesRoot) {
    $map = @{}
    if (-not $classesRoot) { return $map }

    $recognized = @('NullFile','FileName','Data','Command','Handler')

    foreach ($name in $classesRoot.GetSubKeyNames()) {
        if ($name.Length -lt 2 -or $name[0] -ne '.') { continue }

        $extKey = $null
        try { $extKey = $classesRoot.OpenSubKey($name) } catch { $extKey = $null }
        if (-not $extKey) { continue }

        try {
            $sn = $null
            try { $sn = $extKey.OpenSubKey('ShellNew') } catch { $sn = $null }
            if (-not $sn) { continue }

            try {
                $valNames = $sn.GetValueNames()

                $template = 'Unknown/Empty'
                foreach ($r in $recognized) { if ($valNames -contains $r) { $template = $r; break } }

                $progId = $extKey.GetValue('')
                $display = $name

                if ($progId) {
                    $pidKey = $null
                    try { $pidKey = $classesRoot.OpenSubKey([string]$progId) } catch { $pidKey = $null }
                    if ($pidKey) {
                        try {
                            $dv = $pidKey.GetValue('')
                            if ($dv) { $display = [string]$dv }
                        } finally { $pidKey.Close() }
                    }
                }

                $map[$name] = [pscustomobject]@{
                    Extension   = $name
                    DisplayName = $display
                    Template    = $template
                    ProgId      = if ($progId) { [string]$progId } else { $null }
                }
            } finally { $sn.Close() }
        } finally { $extKey.Close() }
    }
    $map
}

function ShellNew-GetItems {
    $lm = $null; $cu = $null
    try {
        $lm = [Microsoft.Win32.Registry]::LocalMachine.OpenSubKey('Software\Classes')
        $cu = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey('Software\Classes')

        $sysMap = ShellNew-ReadRootMap $lm
        $usrMap = ShellNew-ReadRootMap $cu

        $allKeys = New-Object System.Collections.Generic.HashSet[string]
        foreach ($k in $sysMap.Keys) { [void]$allKeys.Add($k) }
        foreach ($k in $usrMap.Keys) { [void]$allKeys.Add($k) }

        $out = foreach ($ext in ($allKeys | Sort-Object)) {
            $sys = $sysMap[$ext]
            $usr = $usrMap[$ext]
            $eff = if ($usr) { $usr } else { $sys }
            if (-not $eff) { continue }

            $hkcuShellNew = "HKCU:\Software\Classes\$ext\ShellNew"
            $disabled = $false
            if (Reg-Exists $hkcuShellNew) {
                $disabled = (Tool-IsMarked $hkcuShellNew) -and (Reg-HasValue $hkcuShellNew 'DisabledByTool')
            }

            [pscustomobject]@{
                Extension   = $eff.Extension
                DisplayName = $eff.DisplayName
                Template    = $eff.Template
                State       = if ($disabled) { 'Disabled (HKCU)' } else { 'Enabled' }
                Source      = if ($usr) { 'HKCU (override)' } else { 'HKLM' }
                ProgId      = $eff.ProgId
            }
        }

        # light debug in status: counts help spot “empty because view” vs “actually none”
        $debug = ("ShellNew found: HKLM={0}, HKCU={1}" -f $sysMap.Count, $usrMap.Count)
        @($out) | ForEach-Object { $_ | Add-Member -NotePropertyName Debug -NotePropertyValue $debug -Force; $_ }
    } finally {
        if ($lm) { $lm.Close() }
        if ($cu) { $cu.Close() }
    }
}

function ShellNew-DisableForUser([string]$extWithDot) {
    $ext = $extWithDot.Trim()
    if (-not $ext.StartsWith('.')) { $ext = ".${ext}" }

    $hkcuShellNew = "HKCU:\Software\Classes\$ext\ShellNew"

    # Backup any existing HKCU ShellNew (user customization)
    if (Test-Path -LiteralPath $hkcuShellNew) {
        $backup = ShellNew-BackupPath $ext
        if (-not (Test-Path -LiteralPath $backup)) { [void](Reg-CopyValues $hkcuShellNew $backup) }
    }

    Reg-Ensure $hkcuShellNew
    Tool-MarkKey $hkcuShellNew

    # Remove known template values so Explorer sees “nothing to create”
    foreach ($n in @('NullFile','FileName','Data','Command','Handler')) { Reg-RemoveValue $hkcuShellNew $n }
    Reg-SetValue $hkcuShellNew 'DisabledByTool' '1' ([Microsoft.Win32.RegistryValueKind]::String)
}

function ShellNew-EnableForUser([string]$extWithDot) {
    $ext = $extWithDot.Trim()
    if (-not $ext.StartsWith('.')) { $ext = ".${ext}" }

    $hkcuShellNew = "HKCU:\Software\Classes\$ext\ShellNew"
    $backup = ShellNew-BackupPath $ext

    if (Test-Path -LiteralPath $backup) {
        Reg-Ensure $hkcuShellNew
        [void](Reg-CopyValues $backup $hkcuShellNew)
        Reg-RemoveTree $backup
        Reg-RemoveValue $hkcuShellNew 'DisabledByTool'
        Reg-RemoveValue $hkcuShellNew $managedValue
        return
    }

    if (Reg-Exists $hkcuShellNew -and (Tool-IsMarked $hkcuShellNew)) {
        Reg-RemoveTree $hkcuShellNew
        $parent = Split-Path -Path $hkcuShellNew -Parent
        if (Reg-IsEmpty $parent) { Reg-RemoveTree $parent }
    } else {
        # If user owns it, just remove our markers
        Reg-RemoveValue $hkcuShellNew 'DisabledByTool'
        Reg-RemoveValue $hkcuShellNew $managedValue
    }
}

# Send To
function SendTo-GetItems {
    if (-not (Test-Path -LiteralPath $sendToDir)) { New-Item -ItemType Directory -Path $sendToDir -Force | Out-Null }
    @(Get-ChildItem -LiteralPath $sendToDir -File -ErrorAction SilentlyContinue |
        Sort-Object Name |
        ForEach-Object { [pscustomobject]@{ Name=$_.Name; Type=$_.Extension; Path=$_.FullName } })
}

# File-type verbs
function FileType-ResolveProgId([string]$ext) {
    $e = $ext.Trim()
    if (-not $e.StartsWith('.')) { $e = ".${e}" }

    $pid = Reg-GetDefault ("HKCU:\Software\Classes\{0}" -f $e)
    if ($pid) { return [pscustomobject]@{ Extension=$e; ProgId=[string]$pid; Source='HKCU' } }

    $pid = Reg-GetDefault ("HKLM:\Software\Classes\{0}" -f $e)
    if ($pid) { return [pscustomobject]@{ Extension=$e; ProgId=[string]$pid; Source='HKLM' } }

    $null
}

function Read-VerbEntry([string]$path, [string]$src) {
    $vk = Reg-Open $path $false
    if (-not $vk) { return $null }
    try {
        $display = $vk.GetValue('MUIVerb',$null); if(-not $display){$display=$vk.GetValue('',$null)}; if(-not $display){$display=Split-Path -Path $path -Leaf}
        $n = $vk.GetValueNames(); $disabled = ($n -contains 'LegacyDisable') -or ($n -contains 'ProgrammaticAccessOnly')
        $cmd = $null; $ck = $vk.OpenSubKey('command')
        if ($ck) { try { $cmd = $ck.GetValue('',$null) } finally { $ck.Close() } }
        [pscustomobject]@{ Key=(Split-Path -Path $path -Leaf); DisplayName=[string]$display; Command=if($cmd){[string]$cmd}else{$null}; Source=$src; DisabledRaw=$disabled }
    } finally { $vk.Close() }
}

function Verb-GetEffective([string]$progId) {
    $hkcuShell = "HKCU:\Software\Classes\$progId\shell"
    $hklmShell = "HKLM:\Software\Classes\$progId\shell"

    $keys = New-Object System.Collections.Generic.HashSet[string]
    foreach ($k in (Reg-SubKeyNames $hklmShell)) { [void]$keys.Add($k) }
    foreach ($k in (Reg-SubKeyNames $hkcuShell)) { [void]$keys.Add($k) }

    $out = foreach ($k in ($keys | Sort-Object)) {
        $sysPath = "$hklmShell\$k"
        $usrPath = "$hkcuShell\$k"

        $usr = Read-VerbEntry $usrPath 'HKCU'
        $sys = Read-VerbEntry $sysPath 'HKLM'
        $eff = if ($usr) { $usr } else { $sys }
        if (-not $eff) { continue }

        $disabledByUser = $false
        if ($usr) {
            $disabledByUser = (Reg-HasValue $usrPath 'LegacyDisable') -or (Reg-HasValue $usrPath 'ProgrammaticAccessOnly')
        }

        [pscustomobject]@{
            VerbKey     = $k
            DisplayName = $eff.DisplayName
            Disabled    = if ($disabledByUser) { 'Yes (HKCU)' } elseif ($eff.DisabledRaw) { 'Yes' } else { 'No' }
            Source      = if ($usr) { 'HKCU' } else { 'HKLM' }
            Command     = $eff.Command
        }
    }
    @($out)
}

function Toggle-VerbDisable([string]$path) {
    $exists = Reg-Exists $path
    $disabled = $exists -and ((Reg-HasValue $path 'LegacyDisable') -or (Reg-HasValue $path 'ProgrammaticAccessOnly'))
    if ($disabled) {
        Reg-RemoveValue $path 'LegacyDisable'
        Reg-RemoveValue $path 'ProgrammaticAccessOnly'
        if (Tool-IsMarked $path) {
            Reg-RemoveValue $path $managedValue
            if (Reg-IsEmpty $path) { Reg-RemoveTree $path }
        }
        return 'Enabled'
    }
    if (-not $exists) { Reg-Ensure $path; Tool-MarkKey $path }
    Reg-SetValue $path 'LegacyDisable' '' ([Microsoft.Win32.RegistryValueKind]::String)
    'Disabled (HKCU)'
}

# Context verbs
$script:ContextLocations = @(
    [pscustomobject]@{ Label='All Files (*)';         HKCU='HKCU:\Software\Classes\*\shell';                    HKLM='HKLM:\Software\Classes\*\shell' },
    [pscustomobject]@{ Label='All FileSystemObjects'; HKCU='HKCU:\Software\Classes\AllFileSystemObjects\shell'; HKLM='HKLM:\Software\Classes\AllFileSystemObjects\shell' },
    [pscustomobject]@{ Label='Directory';            HKCU='HKCU:\Software\Classes\Directory\shell';             HKLM='HKLM:\Software\Classes\Directory\shell' },
    [pscustomobject]@{ Label='Folder';               HKCU='HKCU:\Software\Classes\Folder\shell';                HKLM='HKLM:\Software\Classes\Folder\shell' },
    [pscustomobject]@{ Label='Directory Background'; HKCU='HKCU:\Software\Classes\Directory\Background\shell';  HKLM='HKLM:\Software\Classes\Directory\Background\shell' },
    [pscustomobject]@{ Label='Drive';                HKCU='HKCU:\Software\Classes\Drive\shell';                 HKLM='HKLM:\Software\Classes\Drive\shell' },
    [pscustomobject]@{ Label='Desktop Background';   HKCU='HKCU:\Software\Classes\DesktopBackground\Shell';      HKLM='HKLM:\Software\Classes\DesktopBackground\Shell' }
)

function Ctx-GetItems {
    $rows = foreach ($loc in $script:ContextLocations) {
        $keys = New-Object System.Collections.Generic.HashSet[string]
        foreach ($k in (Reg-SubKeyNames $loc.HKLM)) { [void]$keys.Add($k) }
        foreach ($k in (Reg-SubKeyNames $loc.HKCU)) { [void]$keys.Add($k) }

        foreach ($k in ($keys | Sort-Object)) {
            $sysPath = "$($loc.HKLM)\$k"
            $usrPath = "$($loc.HKCU)\$k"

            $usr = Read-VerbEntry $usrPath 'HKCU'
            $sys = Read-VerbEntry $sysPath 'HKLM'
            $eff = if ($usr) { $usr } else { $sys }
            if (-not $eff) { continue }

            $disabledByUser = $false
            if ($usr) {
                $disabledByUser = (Reg-HasValue $usrPath 'LegacyDisable') -or (Reg-HasValue $usrPath 'ProgrammaticAccessOnly')
            }

            [pscustomobject]@{
                Location    = $loc.Label
                KeyName     = $eff.Key
                DisplayName = $eff.DisplayName
                Disabled    = if ($disabledByUser) { 'Yes (HKCU)' } elseif ($eff.DisabledRaw) { 'Yes' } else { 'No' }
                Source      = if ($usr) { 'HKCU' } else { 'HKLM' }
                Command     = $eff.Command
                HKCUPath    = $usrPath
            }
        }
    }
    @($rows)
}


# Explorer restart
function Explorer-Restart {
    if (-not (Msg-Confirm "Restart Explorer now? (Explorer windows will close temporarily.)" "Restart Explorer")) { return }
    try {
        Get-Process explorer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 350
        Start-Process explorer.exe | Out-Null
    } catch {
        Msg-Error ("Failed to restart Explorer: {0}" -f $_.Exception.Message)
    }
}

# UI wiring
function Grid-WireDeleteKey([string]$gridName, [scriptblock]$action) {
    $g = UI-Require $gridName
    $g.Add_PreviewKeyDown({
        param($sender, $e)
        if ($e.Key -eq [System.Windows.Input.Key]::Delete) {
            $action.InvokeReturnAsIs() | Out-Null
            $e.Handled = $true
        }
    })
}
function Tabs-SelectedHeader() {
    $tabs = $script:UI.Elements['MainTabs']
    if (-not $tabs) { return $null }
    $tab = $tabs.SelectedItem
    if (-not $tab) { return $null }
    [string]$tab.Header
}

# Loaders
function Load-NewTab {
    Start-TabLoad 'New' { @(ShellNew-GetItems) } {
        param($data)
        UI-SetGrid 'NewGrid' $data
        $dbg = if ($data.Count -gt 0) { $data[0].Debug } else { "ShellNew found: HKLM=0, HKCU=0" }
        UI-SetStatus ("New Menu: {0} entries   ({1})" -f $data.Count, $dbg)
    }
}
function Load-SendToTab {
    Start-TabLoad 'SendTo' { @(SendTo-GetItems) } {
        param($data)
        UI-SetGrid 'SendToGrid' $data
        UI-SetStatus ("Send To: {0} entries" -f $data.Count)
    }
}
function Load-VerbsTab {
    $pid = if ($script:UI.ResolvedProg) { [string]$script:UI.ResolvedProg.ProgId } else { $null }
    if (-not $pid) {
        UI-SetGrid 'VerbGrid' @()
        UI-SetStatus "File Type Verbs: resolve an extension"
        return
    }
    Start-TabLoad 'Verbs' { @(Verb-GetEffective $pid) } {
        param($data)
        UI-SetGrid 'VerbGrid' $data
        UI-SetStatus ("File Type Verbs: {0} entries for {1}" -f $data.Count, $script:UI.ResolvedProg.Extension)
    }
}
function Load-ContextTab {
    Start-TabLoad 'Context' { @(Ctx-GetItems) } {
        param($data)
        UI-SetGrid 'ContextGrid' $data
        UI-SetStatus ("Context Verbs: {0} entries" -f $data.Count)
    }
}

# XAML
$XAML = @"
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="Shell Menu Manager (View + Toggle)"
        Height="740" Width="1020"
        MinHeight="560" MinWidth="860"
        WindowStartupLocation="CenterScreen">
  <Grid Margin="10">
    <Grid.RowDefinitions>
      <RowDefinition Height="*" />
      <RowDefinition Height="Auto" />
    </Grid.RowDefinitions>

    <TabControl x:Name="MainTabs" Grid.Row="0" Margin="0,0,0,10">

      <TabItem Header="New Menu">
        <Grid Margin="8">
          <Grid.RowDefinitions>
            <RowDefinition Height="*" />
            <RowDefinition Height="Auto" />
          </Grid.RowDefinitions>

          <DataGrid x:Name="NewGrid" Grid.Row="0"
                    AutoGenerateColumns="False"
                    CanUserAddRows="False"
                    IsReadOnly="True"
                    SelectionMode="Single"
                    Margin="0,0,0,8"
                    EnableRowVirtualization="True"
                    EnableColumnVirtualization="True"
                    VirtualizingPanel.IsVirtualizing="True"
                    VirtualizingPanel.VirtualizationMode="Recycling"
                    ScrollViewer.CanContentScroll="True">
            <DataGrid.Columns>
              <DataGridTextColumn Header="Ext" Binding="{Binding Extension}" Width="90" />
              <DataGridTextColumn Header="Display Name" Binding="{Binding DisplayName}" Width="*" />
              <DataGridTextColumn Header="Template" Binding="{Binding Template}" Width="130" />
              <DataGridTextColumn Header="State" Binding="{Binding State}" Width="170" />
              <DataGridTextColumn Header="Source" Binding="{Binding Source}" Width="140" />
              <DataGridTextColumn Header="ProgId" Binding="{Binding ProgId}" Width="240" />
            </DataGrid.Columns>
          </DataGrid>

          <StackPanel Grid.Row="1" Orientation="Horizontal">
            <Button x:Name="NewToggleBtn" Content="Disable/Enable (Del)" Width="170"/>
          </StackPanel>
        </Grid>
      </TabItem>

      <TabItem Header="Send To">
        <Grid Margin="8">
          <Grid.RowDefinitions>
            <RowDefinition Height="*" />
            <RowDefinition Height="Auto" />
          </Grid.RowDefinitions>

          <DataGrid x:Name="SendToGrid" Grid.Row="0"
                    AutoGenerateColumns="False"
                    CanUserAddRows="False"
                    IsReadOnly="True"
                    SelectionMode="Single"
                    Margin="0,0,0,8"
                    EnableRowVirtualization="True"
                    EnableColumnVirtualization="True"
                    VirtualizingPanel.IsVirtualizing="True"
                    VirtualizingPanel.VirtualizationMode="Recycling"
                    ScrollViewer.CanContentScroll="True">
            <DataGrid.Columns>
              <DataGridTextColumn Header="Name" Binding="{Binding Name}" Width="*" />
              <DataGridTextColumn Header="Type" Binding="{Binding Type}" Width="110" />
              <DataGridTextColumn Header="Path" Binding="{Binding Path}" Width="460" />
            </DataGrid.Columns>
          </DataGrid>

          <StackPanel Grid.Row="1" Orientation="Horizontal">
            <Button x:Name="SendToDeleteBtn" Content="Delete (Del)" Width="120" Margin="0,0,8,0"/>
            <Button x:Name="SendToOpenFolderBtn" Content="Open SendTo Folder" Width="160"/>
          </StackPanel>
        </Grid>
      </TabItem>

      <TabItem Header="File Type Verbs (Open etc.)">
        <Grid Margin="8">
          <Grid.RowDefinitions>
            <RowDefinition Height="Auto"/>
            <RowDefinition Height="*"/>
            <RowDefinition Height="Auto"/>
          </Grid.RowDefinitions>

          <Grid Grid.Row="0" Margin="0,0,0,8">
            <Grid.ColumnDefinitions>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="160"/>
              <ColumnDefinition Width="Auto"/>
              <ColumnDefinition Width="*"/>
            </Grid.ColumnDefinitions>

            <TextBlock Text="Extension" VerticalAlignment="Center"/>
            <TextBox x:Name="VerbExtBox" Grid.Column="1" Margin="8,0,8,0" ToolTip="e.g. .txt"/>
            <Button x:Name="VerbResolveBtn" Grid.Column="2" Content="Resolve" Width="90" Margin="0,0,8,0"/>
            <TextBlock x:Name="VerbProgIdLabel" Grid.Column="3" VerticalAlignment="Center" Foreground="#444"/>
          </Grid>

          <DataGrid x:Name="VerbGrid" Grid.Row="1"
                    AutoGenerateColumns="False"
                    CanUserAddRows="False"
                    IsReadOnly="True"
                    SelectionMode="Single"
                    Margin="0,0,0,8"
                    EnableRowVirtualization="True"
                    EnableColumnVirtualization="True"
                    VirtualizingPanel.IsVirtualizing="True"
                    VirtualizingPanel.VirtualizationMode="Recycling"
                    ScrollViewer.CanContentScroll="True">
            <DataGrid.Columns>
              <DataGridTextColumn Header="VerbKey" Binding="{Binding VerbKey}" Width="160" />
              <DataGridTextColumn Header="Display Name" Binding="{Binding DisplayName}" Width="280" />
              <DataGridTextColumn Header="Disabled" Binding="{Binding Disabled}" Width="160" />
              <DataGridTextColumn Header="Source" Binding="{Binding Source}" Width="120" />
              <DataGridTextColumn Header="Command" Binding="{Binding Command}" Width="*" />
            </DataGrid.Columns>
          </DataGrid>

          <StackPanel Grid.Row="2" Orientation="Horizontal">
            <Button x:Name="VerbToggleBtn" Content="Disable/Enable (Del)" Width="170"/>
          </StackPanel>
        </Grid>
      </TabItem>

      <TabItem Header="Context Verbs (Files/Folders/Background/Drive)">
        <Grid Margin="8">
          <Grid.RowDefinitions>
            <RowDefinition Height="*" />
            <RowDefinition Height="Auto" />
          </Grid.RowDefinitions>

          <DataGrid x:Name="ContextGrid" Grid.Row="0"
                    AutoGenerateColumns="False"
                    CanUserAddRows="False"
                    IsReadOnly="True"
                    SelectionMode="Single"
                    Margin="0,0,0,8"
                    EnableRowVirtualization="True"
                    EnableColumnVirtualization="True"
                    VirtualizingPanel.IsVirtualizing="True"
                    VirtualizingPanel.VirtualizationMode="Recycling"
                    ScrollViewer.CanContentScroll="True">
            <DataGrid.Columns>
              <DataGridTextColumn Header="Location" Binding="{Binding Location}" Width="190" />
              <DataGridTextColumn Header="KeyName" Binding="{Binding KeyName}" Width="220" />
              <DataGridTextColumn Header="Display Name" Binding="{Binding DisplayName}" Width="280" />
              <DataGridTextColumn Header="Disabled" Binding="{Binding Disabled}" Width="160" />
              <DataGridTextColumn Header="Source" Binding="{Binding Source}" Width="120" />
              <DataGridTextColumn Header="Command" Binding="{Binding Command}" Width="*" />
            </DataGrid.Columns>
          </DataGrid>

          <StackPanel Grid.Row="1" Orientation="Horizontal">
            <Button x:Name="ContextToggleBtn" Content="Disable/Enable (Del)" Width="170"/>
          </StackPanel>
        </Grid>
      </TabItem>

    </TabControl>

    <Grid Grid.Row="1">
      <Grid.ColumnDefinitions>
        <ColumnDefinition Width="Auto"/>
        <ColumnDefinition Width="*"/>
        <ColumnDefinition Width="Auto"/>
      </Grid.ColumnDefinitions>

      <Button x:Name="RestartExplorerBtn" Grid.Column="0" Content="Restart Explorer" Width="130" Margin="0,0,10,0"/>
      <TextBlock x:Name="StatusText" Grid.Column="1" VerticalAlignment="Center" Foreground="#444"/>
      <Button x:Name="CloseBtn" Grid.Column="2" Content="Close" Width="90"/>
    </Grid>

  </Grid>
</Window>
"@

# Ensure clean WPF session
if (-not $env:SHELLMENUMGR_WPF_FRESH) {
    try {
        $ea = [System.Windows.Application]::Current
        if ($ea) {
            $d = $ea.Dispatcher
            if ($d -and ($d.HasShutdownStarted -or $d.HasShutdownFinished)) {
                Relaunch-Self (Get-Process -Id $PID).Path $MyInvocation.UnboundArguments 'SHELLMENUMGR_WPF_FRESH'
            }
        }
    } catch { Relaunch-Self (Get-Process -Id $PID).Path $MyInvocation.UnboundArguments 'SHELLMENUMGR_WPF_FRESH' }
}

# App + exception handler
$script:UI.App = [System.Windows.Application]::Current
if (-not $script:UI.App) {
    try {
        $script:UI.App = New-Object System.Windows.Application
    } catch {
        if ($_.Exception.Message -match 'Cannot create more than one' -and -not $env:SHELLMENUMGR_WPF_FRESH) {
            Relaunch-Self (Get-Process -Id $PID).Path $MyInvocation.UnboundArguments 'SHELLMENUMGR_WPF_FRESH'
        }
        $script:UI.App = [System.Windows.Application]::Current
        if (-not $script:UI.App) {
            Write-Error "Cannot create WPF Application. Start a new PowerShell session and run this script again."
            exit 1
        }
    }
}

# Attach exception handler only if App supports it (shutdown App lacks DispatcherUnhandledException)
try {
    $script:UI.App.DispatcherUnhandledException += {
    param($sender, $e)
    $ex = $e.Exception

    if ($ex -is [System.ComponentModel.Win32Exception] -and $ex.NativeErrorCode -eq 1816) {
        try {
            [System.Windows.MessageBox]::Show(
                "WPF hit a system resource quota (Win32 1816). Close some heavy UI apps / many windows, then re-run.",
                "Resource Quota",
                [System.Windows.MessageBoxButton]::OK,
                [System.Windows.MessageBoxImage]::Error) | Out-Null
        } catch {}
        try { $script:UI.Window.Close() } catch {}
        $e.Handled = $true
        return
    }

    try {
        [System.Windows.MessageBox]::Show(
            ("Unhandled UI exception: {0}" -f $ex.Message),
            "Unhandled Exception",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error) | Out-Null
    } catch {}
    $e.Handled = $true
}
} catch {
    # Shutdown or non-standard App may not support DispatcherUnhandledException; continue without handler
}

# Build window
try {
    $reader = New-Object System.Xml.XmlNodeReader ([xml]$XAML)
    $script:UI.Window = [Windows.Markup.XamlReader]::Load($reader)
} catch {
    Write-Error ("Failed to load XAML: {0}" -f $_.Exception.Message)
    exit 1
}

$script:UI.Dispatcher = $script:UI.Window.Dispatcher

# Named controls
([regex]::Matches($XAML, 'x:Name="([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique) | ForEach-Object {
    $ctrl = $script:UI.Window.FindName($_)
    if ($null -ne $ctrl) { $script:UI.Elements[$_] = $ctrl }
}

# Actions
function Do-NewToggle {
    $row = $script:UI.Elements['NewGrid'].SelectedItem
    if (-not $row) { Msg-Warn "Select an item first."; return }

    try {
        if ($row.State -like 'Disabled*') {
            if (-not (Msg-Confirm ("Re-enable {0}?" -f $row.Extension) "Enable")) { return }
            ShellNew-EnableForUser $row.Extension
        } else {
            if (-not (Msg-Confirm ("Disable '{0}' ({1}) for this user?" -f $row.DisplayName, $row.Extension) "Disable")) { return }
            ShellNew-DisableForUser $row.Extension
        }

        Tab-MarkDirty 'New'
        Load-NewTab
    } catch { Msg-Error $_.Exception.Message }
}

function Do-SendToDelete {
    $row = $script:UI.Elements['SendToGrid'].SelectedItem
    if (-not $row) { Msg-Warn "Select an item first."; return }
    if (-not (Msg-Confirm ("Delete Send To item '{0}'?" -f $row.Name) "Delete")) { return }

    try {
        Remove-Item -LiteralPath $row.Path -Force -ErrorAction Stop | Out-Null
        Tab-MarkDirty 'SendTo'
        Load-SendToTab
    } catch { Msg-Error $_.Exception.Message }
}

function Do-VerbResolve {
    try {
        $script:UI.ResolvedProg = FileType-ResolveProgId $script:UI.Elements['VerbExtBox'].Text
        if (-not $script:UI.ResolvedProg) {
            $script:UI.Elements['VerbProgIdLabel'].Text = "No ProgId found"
            UI-SetGrid 'VerbGrid' @()
            UI-SetStatus "File Type Verbs: could not resolve ProgId"
            return
        }

        $script:UI.Elements['VerbProgIdLabel'].Text = ("ProgId: {0} (from {1})" -f $script:UI.ResolvedProg.ProgId, $script:UI.ResolvedProg.Source)
        Tab-MarkDirty 'Verbs'
        Load-VerbsTab
    } catch { Msg-Error $_.Exception.Message }
}

function Do-VerbToggle {
    if (-not $script:UI.ResolvedProg) { Msg-Warn "Resolve an extension first."; return }
    $row = $script:UI.Elements['VerbGrid'].SelectedItem
    if (-not $row) { Msg-Warn "Select a verb first."; return }

    if (-not (Msg-Confirm ("Toggle disable/enable for '{0}'?" -f $row.VerbKey) "Toggle")) { return }

    try {
        $result = Toggle-VerbDisable "HKCU:\Software\Classes\$($script:UI.ResolvedProg.ProgId)\shell\$($row.VerbKey)"
        Tab-MarkDirty 'Verbs'
        Load-VerbsTab
        UI-SetStatus ("{0}: {1}" -f $row.VerbKey, $result)
    } catch { Msg-Error $_.Exception.Message }
}

function Do-ContextToggle {
    $row = $script:UI.Elements['ContextGrid'].SelectedItem
    if (-not $row) { Msg-Warn "Select an item first."; return }

    if (-not (Msg-Confirm ("Toggle disable/enable for '{0}'?" -f $row.DisplayName) "Toggle")) { return }

    try {
        $result = Toggle-VerbDisable $row.HKCUPath
        Tab-MarkDirty 'Context'
        Load-ContextTab
        UI-SetStatus ("{0} / {1}: {2}" -f $row.Location, $row.KeyName, $result)
    } catch { Msg-Error $_.Exception.Message }
}

# Hook buttons
(UI-Require 'CloseBtn').Add_Click({ $script:UI.Window.Close() })
(UI-Require 'RestartExplorerBtn').Add_Click({ Explorer-Restart })
(UI-Require 'NewToggleBtn').Add_Click({ Do-NewToggle })
(UI-Require 'SendToDeleteBtn').Add_Click({ Do-SendToDelete })
(UI-Require 'SendToOpenFolderBtn').Add_Click({
    try {
        if (-not (Test-Path -LiteralPath $sendToDir)) { New-Item -ItemType Directory -Path $sendToDir -Force | Out-Null }
        Start-Process -FilePath explorer.exe -ArgumentList @($sendToDir) | Out-Null
    } catch { Msg-Error $_.Exception.Message }
})
(UI-Require 'VerbResolveBtn').Add_Click({ Do-VerbResolve })
(UI-Require 'VerbToggleBtn').Add_Click({ Do-VerbToggle })
(UI-Require 'ContextToggleBtn').Add_Click({ Do-ContextToggle })

# Delete key support
Grid-WireDeleteKey 'NewGrid' { Do-NewToggle }
Grid-WireDeleteKey 'SendToGrid' { Do-SendToDelete }
Grid-WireDeleteKey 'VerbGrid' { Do-VerbToggle }
Grid-WireDeleteKey 'ContextGrid' { Do-ContextToggle }

# Tab selection
$tabs = UI-Require 'MainTabs'
$tabs.Add_SelectionChanged({
    param($sender, $e)
    if ($e.OriginalSource -ne $sender) { return }
    try {
        $header = Tabs-SelectedHeader
        if (-not $header) { return }
        switch -Wildcard ($header) {
            'New Menu*'        { Ensure-TabLoaded 'New'     { Load-NewTab } }
            'Send To*'         { Ensure-TabLoaded 'SendTo'  { Load-SendToTab } }
            'File Type Verbs*' { Ensure-TabLoaded 'Verbs'   { Load-VerbsTab } }
            'Context Verbs*'   { Ensure-TabLoaded 'Context' { Load-ContextTab } }
        }
    } catch {
        UI-SetStatus ("Tab error: {0}" -f $_.Exception.Message)
    }
})

# Initial load
$script:UI.Window.Add_ContentRendered({
    $script:UI.Elements['VerbProgIdLabel'].Text = "Resolve an extension to view/toggle file-type verbs."
    Ensure-TabLoaded 'New' { Load-NewTab }
})

# Run
if (-not $script:UI.App) {
    Write-Error "WPF Application is not initialized. Start a new PowerShell session and run again."
    exit 1
}
$null = $script:UI.App.Run($script:UI.Window)
