#requires -Version 7.0
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    $pwshPath = (Get-Process -Id $PID).Path
    $argList = @('-NoProfile','-Sta','-ExecutionPolicy','Bypass','-File', $PSCommandPath) + $MyInvocation.UnboundArguments
    Start-Process -FilePath $pwshPath -ArgumentList $argList | Out-Null
    exit
}

$XAML = @"
<Window xmlns='http://schemas.microsoft.com/winfx/2006/xaml/presentation'
        xmlns:x='http://schemas.microsoft.com/winfx/2006/xaml'
        Title='PC Setup'
        Height='700' Width='420'
        MinHeight='450' MinWidth='380'
        ResizeMode='CanResize'
        WindowStartupLocation='CenterScreen'>
  <Grid>
    <TabControl>
      <TabItem Header='Tweaks'>
        <Grid Margin='10'>
          <Grid.RowDefinitions>
            <RowDefinition Height='*' />
            <RowDefinition Height='Auto' />
          </Grid.RowDefinitions>

          <ScrollViewer Grid.Row='0' VerticalScrollBarVisibility='Auto' HorizontalScrollBarVisibility='Disabled'>
            <StackPanel>
              <CheckBox x:Name='DarkMode' Content='Enable Dark Mode' Margin='5'/>
              <CheckBox x:Name='DisableSystemSounds' Content='Disable System Sounds' Margin='5'/>
              <CheckBox x:Name='DisableNotifications' Content='Disable Notifications' Margin='5'/>
              <CheckBox x:Name='ShowHiddenFiles' Content='Show Hidden Files' Margin='5'/>
              <CheckBox x:Name='DisableActionCenter' Content='Disable Action Center' Margin='5'/>
              <CheckBox x:Name='PrivacySettings' Content='Configure Privacy Settings' Margin='5'/>
              <CheckBox x:Name='PowerPlan' Content='High Performance Power Plan' Margin='5'/>
              <CheckBox x:Name='DisableCortana' Content='Disable Cortana' Margin='5'/>
              <CheckBox x:Name='DisableTelemetry' Content='Disable Telemetry' Margin='5'/>
              <CheckBox x:Name='DisableLockScreen' Content='Disable Lock Screen' Margin='5'/>
              <CheckBox x:Name='TaskbarSettings' Content='Taskbar Settings' Margin='5'/>
              <CheckBox x:Name='DisableAutoPlay' Content='Disable AutoPlay' Margin='5'/>
              <CheckBox x:Name='DisableErrorReporting' Content='Disable Error Reporting' Margin='5'/>
              <CheckBox x:Name='DisableWindowsDefender' Content='Disable Windows Defender' Margin='5'/>
              <CheckBox x:Name='DisableFirewall' Content='Disable Windows Firewall' Margin='5'/>

              <CheckBox x:Name='StopOneDriveFolderBackup' Content='Keep Desktop/Documents/Pictures local (stop OneDrive folder backup)' Margin='5'/>

              <CheckBox x:Name='DisableGameBar' Content='Disable Game Bar' Margin='5'/>
              <CheckBox x:Name='DisableTimeline' Content='Disable Timeline' Margin='5'/>
              <CheckBox x:Name='DisableFeedbackHub' Content='Reduce Feedback Prompts' Margin='5'/>
              <CheckBox x:Name='DisableAnimations' Content='Disable Animations' Margin='5'/>
              <CheckBox x:Name='DisableBackgroundApps' Content='Disable Background Apps' Margin='5'/>
            </StackPanel>
          </ScrollViewer>

          <Button Grid.Row='1' x:Name='ApplyTweaksButton'
                  Content='Apply Tweaks'
                  Width='140' Margin='5'
                  HorizontalAlignment='Center'/>
        </Grid>
      </TabItem>
    </TabControl>
  </Grid>
</Window>
"@

try {
    $reader = New-Object System.Xml.XmlNodeReader ([xml]$XAML)
    $Window = [Windows.Markup.XamlReader]::Load($reader)
} catch {
    Write-Error "Failed to load XAML: $($_.Exception.Message)"
    exit 1
}

$elements = @{}
$names =
    [regex]::Matches($XAML, "x:Name='([^']+)'") |
    ForEach-Object { $_.Groups[1].Value } |
    Sort-Object -Unique

foreach ($name in $names) {
    $ctrl = $Window.FindName($name)
    if ($null -ne $ctrl) { $elements[$name] = $ctrl }
}

if (-not $elements.ContainsKey('ApplyTweaksButton')) {
    throw "Required control 'ApplyTweaksButton' not found. Check x:Name in XAML."
}

function Is-Admin {
    $id = [Security.Principal.WindowsIdentity]::GetCurrent()
    ([Security.Principal.WindowsPrincipal]$id).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Ensure-RegistryPath {
    param([Parameter(Mandatory)][string]$Path)
    if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force | Out-Null }
}

function Set-RegistryValue {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][object]$Value,
        [ValidateSet('String','ExpandString','Binary','DWord','QWord','MultiString')][string]$PropertyType = 'DWord'
    )
    Ensure-RegistryPath -Path $Path
    try {
        New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $PropertyType -Force | Out-Null
    } catch {
        Write-Warning "Failed to set registry value [$Path] '$Name': $($_.Exception.Message)"
    }
}

function Remove-RegistryValue {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Name)
    try {
        Remove-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue | Out-Null
    } catch {
        Write-Warning "Failed to remove registry value [$Path] '$Name': $($_.Exception.Message)"
    }
}

function To-RegExePath {
    param([Parameter(Mandatory)][string]$Path)

    if ($Path -like 'Microsoft.PowerShell.Core\Registry::*') { $Path = $Path.Split('::',2)[1] }

    if ($Path -like 'HKCU:\*') { return 'HKCU\' + $Path.Substring(6) }
    if ($Path -like 'HKLM:\*') { return 'HKLM\' + $Path.Substring(6) }

    if ($Path -like 'HKEY_CURRENT_USER\*')  { return 'HKCU\' + $Path.Substring(18) }
    if ($Path -like 'HKEY_LOCAL_MACHINE\*') { return 'HKLM\' + $Path.Substring(19) }

    return $Path
}

function Set-RegDefaultValue {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Value,
        [ValidateSet('REG_SZ','REG_DWORD','REG_QWORD')][string]$Type = 'REG_SZ'
    )
    $rp = To-RegExePath $Path
    & reg.exe add $rp /ve /t $Type /d $Value /f | Out-Null
}

function Get-ItemPropertyValueSafe {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Name)
    try {
        $p = Get-ItemProperty -Path $Path -ErrorAction Stop
        return $p.$Name
    } catch {
        return $null
    }
}

function Expand-Env {
    param([AllowNull()][string]$Value)
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    [Environment]::ExpandEnvironmentVariables($Value)
}

function Is-OneDrivePath {
    param([AllowNull()][string]$Path)
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    return ($Path -match "\\OneDrive( - [^\\]+)?\\")
}

function Move-FolderContents {
    param(
        [Parameter(Mandatory)][string]$Source,
        [Parameter(Mandatory)][string]$Dest
    )

    if (-not (Test-Path -LiteralPath $Source -PathType Container)) { return }
    if (-not (Test-Path -LiteralPath $Dest -PathType Container)) { New-Item -ItemType Directory -Path $Dest -Force | Out-Null }

    & robocopy $Source $Dest /E /MOVE /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
}

function Stop-OneDriveFolderBackup {
    $userShell = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
    $shell     = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders'
    $profile   = $env:USERPROFILE

    $defaultsUserShell = @{
        Desktop     = '%USERPROFILE%\Desktop'
        Personal    = '%USERPROFILE%\Documents'
        'My Pictures' = '%USERPROFILE%\Pictures'
    }

    $defaultsShell = @{
        Desktop     = (Join-Path $profile 'Desktop')
        Personal    = (Join-Path $profile 'Documents')
        'My Pictures' = (Join-Path $profile 'Pictures')
    }

    $currentUserShell = @{
        Desktop       = Get-ItemPropertyValueSafe -Path $userShell -Name 'Desktop'
        Personal      = Get-ItemPropertyValueSafe -Path $userShell -Name 'Personal'
        'My Pictures' = Get-ItemPropertyValueSafe -Path $userShell -Name 'My Pictures'
    }

    $movePlan = @()
    foreach ($k in @('Desktop','Personal','My Pictures')) {
        $cur = Expand-Env $currentUserShell[$k]
        $dst = Expand-Env $defaultsUserShell[$k]

        if ($cur -and $dst -and ($cur -ne $dst) -and (Is-OneDrivePath $cur)) {
            $movePlan += [pscustomobject]@{ Key=$k; Source=$cur; Dest=$dst }
        }
    }

    if ($movePlan.Count -gt 0) {
        $preview = ($movePlan | ForEach-Object { "$($_.Key):`n  from $($_.Source)`n  to   $($_.Dest)" }) -join "`n`n"
        $r = [System.Windows.MessageBox]::Show(
            "This will move your known folders back to local paths and move contents out of OneDrive:`n`n$preview`n`nContinue?",
            "Confirm OneDrive Folder Backup Stop",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question
        )
        if ($r -ne [System.Windows.MessageBoxResult]::Yes) { return $false }

        foreach ($m in $movePlan) {
            Move-FolderContents -Source $m.Source -Dest $m.Dest
        }
    }

    foreach ($k in @('Desktop','Personal','My Pictures')) {
        Set-RegistryValue -Path $userShell -Name $k -Value $defaultsUserShell[$k] -PropertyType 'ExpandString'
        Set-RegistryValue -Path $shell     -Name $k -Value $defaultsShell[$k]     -PropertyType 'String'
    }

    return $true
}

$hkcuCV          = 'HKCU:\Software\Microsoft\Windows\CurrentVersion'
$hkcuExplorerAdv = "$hkcuCV\Explorer\Advanced"
$hkcuPoliciesWin = 'HKCU:\Software\Policies\Microsoft\Windows'
$hkcuPoliciesCV  = "$hkcuCV\Policies"
$hkcuSiufRules   = 'HKCU:\Software\Microsoft\Siuf\Rules'
$hkcuAppEvents   = 'HKCU:\AppEvents\Schemes'

$hklmPoliciesWin = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows'
$hklmPoliciesDef = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'

$registryToggles = @(
    [pscustomobject]@{ Check='DarkMode'; Path="$hkcuCV\Themes\Personalize"; Name='AppsUseLightTheme';    On=0; Off=1; Type='DWord'; RemoveWhenOff=$false },
    [pscustomobject]@{ Check='DarkMode'; Path="$hkcuCV\Themes\Personalize"; Name='SystemUsesLightTheme'; On=0; Off=1; Type='DWord'; RemoveWhenOff=$false },

    [pscustomobject]@{ Check='DisableNotifications'; Path="$hkcuCV\PushNotifications"; Name='ToastEnabled'; On=0; Off=1; Type='DWord'; RemoveWhenOff=$false },

    [pscustomobject]@{ Check='ShowHiddenFiles'; Path=$hkcuExplorerAdv; Name='Hidden';          On=1; Off=2; Type='DWord'; RemoveWhenOff=$false },
    [pscustomobject]@{ Check='ShowHiddenFiles'; Path=$hkcuExplorerAdv; Name='ShowSuperHidden'; On=1; Off=0; Type='DWord'; RemoveWhenOff=$false },

    [pscustomobject]@{ Check='DisableActionCenter'; Path="$hkcuPoliciesWin\Explorer"; Name='DisableNotificationCenter'; On=1; Off=$null; Type='DWord'; RemoveWhenOff=$true },

    [pscustomobject]@{ Check='PrivacySettings'; Path="$hkcuCV\AdvertisingInfo"; Name='Enabled'; On=0; Off=1; Type='DWord'; RemoveWhenOff=$false },
    [pscustomobject]@{ Check='PrivacySettings'; Path=$hkcuSiufRules; Name='PeriodInNanoSeconds';  On=0; Off=$null; Type='QWord'; RemoveWhenOff=$true },
    [pscustomobject]@{ Check='PrivacySettings'; Path=$hkcuSiufRules; Name='NumberOfSIUFInPeriod'; On=0; Off=$null; Type='DWord'; RemoveWhenOff=$true },

    [pscustomobject]@{ Check='DisableCortana'; Path="$hklmPoliciesWin\Windows Search"; Name='AllowCortana'; On=0; Off=$null; Type='DWord'; RemoveWhenOff=$true },
    [pscustomobject]@{ Check='DisableTelemetry'; Path="$hklmPoliciesWin\DataCollection"; Name='AllowTelemetry'; On=0; Off=$null; Type='DWord'; RemoveWhenOff=$true },
    [pscustomobject]@{ Check='DisableLockScreen'; Path="$hklmPoliciesWin\Personalization"; Name='NoLockScreen'; On=1; Off=$null; Type='DWord'; RemoveWhenOff=$true },

    [pscustomobject]@{ Check='TaskbarSettings'; Path=$hkcuExplorerAdv; Name='TaskbarSmallIcons'; On=1; Off=0; Type='DWord'; RemoveWhenOff=$false },
    [pscustomobject]@{ Check='DisableAutoPlay'; Path="$hkcuPoliciesCV\Explorer"; Name='NoDriveTypeAutoRun'; On=255; Off=$null; Type='DWord'; RemoveWhenOff=$true },

    [pscustomobject]@{ Check='DisableErrorReporting'; Path="$hklmPoliciesWin\Windows Error Reporting"; Name='Disabled'; On=1; Off=$null; Type='DWord'; RemoveWhenOff=$true },

    [pscustomobject]@{ Check='DisableWindowsDefender'; Path=$hklmPoliciesDef; Name='DisableAntiSpyware'; On=1; Off=$null; Type='DWord'; RemoveWhenOff=$true },

    [pscustomobject]@{ Check='DisableGameBar'; Path="$hkcuCV\GameDVR"; Name='AppCaptureEnabled'; On=0; Off=1; Type='DWord'; RemoveWhenOff=$false },
    [pscustomobject]@{ Check='DisableGameBar'; Path='HKCU:\System\GameConfigStore'; Name='GameDVR_Enabled'; On=0; Off=1; Type='DWord'; RemoveWhenOff=$false },

    [pscustomobject]@{ Check='DisableTimeline'; Path="$hklmPoliciesWin\System"; Name='EnableActivityFeed';    On=0; Off=$null; Type='DWord'; RemoveWhenOff=$true },
    [pscustomobject]@{ Check='DisableTimeline'; Path="$hklmPoliciesWin\System"; Name='PublishUserActivities'; On=0; Off=$null; Type='DWord'; RemoveWhenOff=$true },
    [pscustomobject]@{ Check='DisableTimeline'; Path="$hklmPoliciesWin\System"; Name='UploadUserActivities';  On=0; Off=$null; Type='DWord'; RemoveWhenOff=$true },

    [pscustomobject]@{ Check='DisableFeedbackHub'; Path=$hkcuSiufRules; Name='PeriodInNanoSeconds';  On=0; Off=$null; Type='QWord'; RemoveWhenOff=$true },
    [pscustomobject]@{ Check='DisableFeedbackHub'; Path=$hkcuSiufRules; Name='NumberOfSIUFInPeriod'; On=0; Off=$null; Type='DWord'; RemoveWhenOff=$true },

    [pscustomobject]@{ Check='DisableAnimations'; Path=$hkcuExplorerAdv; Name='TaskbarAnimations'; On=0; Off=1; Type='DWord'; RemoveWhenOff=$false },
    [pscustomobject]@{ Check='DisableBackgroundApps'; Path="$hkcuCV\BackgroundAccessApplications"; Name='GlobalUserDisabled'; On=1; Off=0; Type='DWord'; RemoveWhenOff=$false }
)

$customToggles = @(
    [pscustomobject]@{
        Check='DisableSystemSounds'
        On = {
            Set-RegDefaultValue -Path $hkcuAppEvents -Value '.None' -Type 'REG_SZ'
            Get-ChildItem -Path "$hkcuAppEvents\Apps" -ErrorAction SilentlyContinue |
                Get-ChildItem -ErrorAction SilentlyContinue |
                Get-ChildItem -ErrorAction SilentlyContinue |
                Where-Object { $_.PSChildName -eq '.Current' } |
                ForEach-Object { Set-RegDefaultValue -Path $_.PSPath -Value '' -Type 'REG_SZ' }
        }
        Off = {
            Set-RegDefaultValue -Path $hkcuAppEvents -Value '.Default' -Type 'REG_SZ'
        }
    }
    [pscustomobject]@{
        Check='PowerPlan'
        On  = { powercfg /setactive SCHEME_MIN      | Out-Null }
        Off = { powercfg /setactive SCHEME_BALANCED | Out-Null }
    }
    [pscustomobject]@{
        Check='StopOneDriveFolderBackup'
        On  = { Stop-OneDriveFolderBackup | Out-Null }
        Off = { }
    }
)

function Apply-Toggles {
    $isAdmin = Is-Admin
    $skippedAdmin = @()

    if ($elements.ContainsKey('DisableWindowsDefender') -and $elements['DisableWindowsDefender'].IsChecked -eq $true) {
        $r = [System.Windows.MessageBox]::Show(
            "Disabling Defender can reduce security and is often blocked by Tamper Protection. Continue?",
            "Confirm",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Warning
        )
        if ($r -ne [System.Windows.MessageBoxResult]::Yes) { $elements['DisableWindowsDefender'].IsChecked = $false }
    }

    if ($elements.ContainsKey('DisableFirewall') -and $elements['DisableFirewall'].IsChecked -eq $true) {
        $r = [System.Windows.MessageBox]::Show(
            "Disabling the Firewall reduces security. Continue?",
            "Confirm",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Warning
        )
        if ($r -ne [System.Windows.MessageBoxResult]::Yes) { $elements['DisableFirewall'].IsChecked = $false }
    }

    foreach ($t in $registryToggles) {
        if (-not $elements.ContainsKey($t.Check)) { continue }
        $desiredOn = ($elements[$t.Check].IsChecked -eq $true)

        $needsAdminForThis = ($t.Path -like 'HKLM:*')
        if ($needsAdminForThis -and -not $isAdmin) {
            if ($desiredOn -or (-not $t.RemoveWhenOff -and $null -ne $t.Off) -or ($t.RemoveWhenOff -and -not $desiredOn)) {
                $skippedAdmin += $t.Check
            }
            continue
        }

        if ($desiredOn) {
            Set-RegistryValue -Path $t.Path -Name $t.Name -Value $t.On -PropertyType $t.Type
        } else {
            if ($t.RemoveWhenOff -and $null -eq $t.Off) {
                Remove-RegistryValue -Path $t.Path -Name $t.Name
            } elseif ($null -ne $t.Off) {
                Set-RegistryValue -Path $t.Path -Name $t.Name -Value $t.Off -PropertyType $t.Type
            }
        }
    }

    foreach ($t in $customToggles) {
        if (-not $elements.ContainsKey($t.Check)) { continue }
        try {
            if ($elements[$t.Check].IsChecked -eq $true) { & $t.On } else { & $t.Off }
        } catch {
            Write-Warning "Custom tweak '$($t.Check)' failed: $($_.Exception.Message)"
        }
    }

    $note = "Tweaks applied. Some changes may require sign-out, Explorer restart, or reboot."
    if (-not $isAdmin -and $skippedAdmin.Count -gt 0) {
        $skipped = ($skippedAdmin | Sort-Object -Unique) -join ", "
        $note += "`n`nSkipped (need Admin): $skipped"
    }

    [System.Windows.MessageBox]::Show(
        $note,
        "Info",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Information
    ) | Out-Null
}

$ApplyTweaks_Click = {
    try {
        Apply-Toggles
    } catch {
        [System.Windows.MessageBox]::Show(
            "Failed to apply tweaks: $($_.Exception.Message)",
            "Error",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    }
}

$elements['ApplyTweaksButton'].Add_Click($ApplyTweaks_Click)
$Window.ShowDialog() | Out-Null
