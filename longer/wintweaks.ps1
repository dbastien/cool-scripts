#requires -Version 7.0
Add-Type -AssemblyName PresentationFramework
Add-Type -AssemblyName PresentationCore
Add-Type -AssemblyName WindowsBase

# --- Ensure STA for WPF ---
if ([Threading.Thread]::CurrentThread.ApartmentState -ne 'STA') {
    $pwshPath = (Get-Process -Id $PID).Path
    $argList = @('-NoProfile','-Sta','-ExecutionPolicy','Bypass','-File', $PSCommandPath) + $args
    Start-Process -FilePath $pwshPath -ArgumentList $argList | Out-Null
    exit
}

# --- XAML (single page, sections, tooltips) ---
$XAML = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        Title="PC Setup"
        Height="700" Width="420"
        MinHeight="450" MinWidth="380"
        ResizeMode="CanResize"
        WindowStartupLocation="CenterScreen">

  <Window.Resources>
    <Style TargetType="CheckBox">
      <Setter Property="Margin" Value="6,4"/>
      <Setter Property="VerticalAlignment" Value="Center"/>
    </Style>

    <Style TargetType="ToolTip">
      <Setter Property="Padding" Value="10,6"/>
      <Setter Property="MaxWidth" Value="320"/>
    </Style>

    <Style TargetType="FrameworkElement">
      <Setter Property="ToolTipService.InitialShowDelay" Value="350"/>
      <Setter Property="ToolTipService.ShowDuration" Value="20000"/>
      <Setter Property="ToolTipService.BetweenShowDelay" Value="150"/>
    </Style>

    <Style TargetType="GroupBox">
      <Setter Property="Margin" Value="0,0,0,10"/>
      <Setter Property="Padding" Value="8"/>
    </Style>
  </Window.Resources>

  <Grid Margin="10">
    <Grid.RowDefinitions>
      <RowDefinition Height="*"/>
      <RowDefinition Height="Auto"/>
    </Grid.RowDefinitions>

    <ScrollViewer Grid.Row="0"
                  VerticalScrollBarVisibility="Auto"
                  HorizontalScrollBarVisibility="Disabled">
      <StackPanel>

        <GroupBox Header="Appearance &amp; Explorer">
          <StackPanel>
            <CheckBox x:Name="DarkMode"
                      Content="Enable Dark Mode"
                      ToolTip="Sets app and system theme to dark for the current user."/>

            <CheckBox x:Name="ShowHiddenFiles"
                      Content="Show Hidden Files"
                      ToolTip="Shows hidden and protected OS files in File Explorer."/>

            <CheckBox x:Name="TaskbarSettings"
                      Content="Taskbar Settings"
                      ToolTip="Applies a basic taskbar tweak (small icons where supported)."/>

            <CheckBox x:Name="DisableAnimations"
                      Content="Disable Animations"
                      ToolTip="Reduces some UI animations."/>
          </StackPanel>
        </GroupBox>

        <GroupBox Header="Notifications &amp; Sounds">
          <StackPanel>
            <CheckBox x:Name="DisableNotifications"
                      Content="Disable Notifications"
                      ToolTip="Disables toast notifications for the current user."/>

            <CheckBox x:Name="DisableActionCenter"
                      Content="Disable Action Center"
                      ToolTip="Disables the notification center UI (policy-based tweak)."/>

            <CheckBox x:Name="DisableSystemSounds"
                      Content="Disable System Sounds"
                      ToolTip="Sets sound scheme to None and clears per-event sound bindings."/>
          </StackPanel>
        </GroupBox>

        <GroupBox Header="Privacy &amp; Telemetry">
          <StackPanel>
            <CheckBox x:Name="PrivacySettings"
                      Content="Configure Privacy Settings"
                      ToolTip="Turns off some advertising settings and reduces feedback prompting."/>

            <CheckBox x:Name="DisableTelemetry"
                      Content="Disable Telemetry"
                      ToolTip="Sets Windows data collection policy (Admin required; edition-dependent)."/>

            <CheckBox x:Name="DisableFeedbackHub"
                      Content="Reduce Feedback Prompts"
                      ToolTip="Attempts to reduce Windows feedback frequency."/>

            <CheckBox x:Name="DisableTimeline"
                      Content="Disable Timeline"
                      ToolTip="Disables Activity Feed/Timeline activity publishing (policy-based; Admin)."/>
          </StackPanel>
        </GroupBox>

        <GroupBox Header="Power &amp; Autoplay">
          <StackPanel>
            <CheckBox x:Name="PowerPlan"
                      Content="High Performance Power Plan"
                      ToolTip="Switches to the High Performance power scheme."/>

            <CheckBox x:Name="DisableAutoPlay"
                      Content="Disable AutoPlay"
                      ToolTip="Disables AutoRun/AutoPlay for drives via Explorer policy."/>
          </StackPanel>
        </GroupBox>

        <GroupBox Header="Gaming">
          <StackPanel>
            <CheckBox x:Name="DisableGameBar"
                      Content="Disable Game Bar"
                      ToolTip="Disables Xbox Game Bar capture hooks and GameDVR settings for the current user."/>
          </StackPanel>
        </GroupBox>

        <GroupBox Header="Background Activity">
          <StackPanel>
            <CheckBox x:Name="DisableBackgroundApps"
                      Content="Disable Background Apps"
                      ToolTip="Blocks background app execution for the current user where honored."/>
          </StackPanel>
        </GroupBox>

        <GroupBox Header="OneDrive">
          <StackPanel>
            <CheckBox x:Name="StopOneDriveFolderBackup"
                      Content="Keep Desktop/Documents/Pictures local (stop OneDrive folder backup)"
                      ToolTip="Moves known folders back to local profile paths and moves files out of OneDrive if redirected."/>
          </StackPanel>
        </GroupBox>

        <GroupBox Header="Security (Advanced)">
          <StackPanel>
            <CheckBox x:Name="DisableLockScreen"
                      Content="Disable Lock Screen"
                      ToolTip="Disables the lock screen (policy). Admin required. May not apply on all editions."/>

            <CheckBox x:Name="DisableCortana"
                      Content="Disable Cortana"
                      ToolTip="Sets policy to disable Cortana (Admin required; behavior varies by version)."/>

            <CheckBox x:Name="DisableErrorReporting"
                      Content="Disable Error Reporting"
                      ToolTip="Disables Windows Error Reporting via policy (Admin required)."/>

            <CheckBox x:Name="DisableWindowsDefender"
                      Content="Disable Windows Defender"
                      ToolTip="Attempts to disable Defender via policy. Often blocked by Tamper Protection."/>

            <CheckBox x:Name="DisableFirewall"
                      Content="Disable Windows Firewall"
                      ToolTip="Disables firewall profiles (high risk; Admin required)."/>
          </StackPanel>
        </GroupBox>

      </StackPanel>
    </ScrollViewer>

    <Button Grid.Row="1"
            x:Name="ApplyTweaksButton"
            Content="Apply Tweaks"
            Width="140"
            Margin="5"
            HorizontalAlignment="Center"/>
  </Grid>
</Window>
'@

# --- Load XAML WITHOUT [xml] cast ---
function Load-XamlWindow {
    param([Parameter(Mandatory)][string]$XamlText)

    $sr = $null
    $xr = $null
    try {
        $sr = New-Object System.IO.StringReader($XamlText)
        $xr = [System.Xml.XmlReader]::Create($sr)
        return [Windows.Markup.XamlReader]::Load($xr)
    } catch {
        $msg = $_.Exception.Message
        $inner = $_.Exception.InnerException
        while ($inner) { $msg += "`nInner: " + $inner.Message; $inner = $inner.InnerException }
        throw $msg
    } finally {
        if ($xr) { $xr.Dispose() }
        if ($sr) { $sr.Dispose() }
    }
}

try {
    $Window = Load-XamlWindow -XamlText $XAML
} catch {
    Write-Error "Failed to load XAML:`n$_"
    exit 1
}

# --- Find named elements ---
$elements = @{}
$names =
    [regex]::Matches($XAML, 'x:Name="([^"]+)"') |
    ForEach-Object { $_.Groups[1].Value } |
    Sort-Object -Unique

foreach ($name in $names) {
    $ctrl = $Window.FindName($name)
    if ($null -ne $ctrl) { $elements[$name] = $ctrl }
}

if (-not $elements.ContainsKey('ApplyTweaksButton')) {
    Write-Error "ApplyTweaksButton not found (x:Name mismatch)."
    exit 1
}

# --- Helpers ---
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
    New-ItemProperty -Path $Path -Name $Name -Value $Value -PropertyType $PropertyType -Force | Out-Null
}

function Remove-RegistryValue {
    param([Parameter(Mandatory)][string]$Path, [Parameter(Mandatory)][string]$Name)
    Remove-ItemProperty -Path $Path -Name $Name -ErrorAction SilentlyContinue | Out-Null
}

function To-RegExePath {
    param([Parameter(Mandatory)][string]$Path)
    if ($Path -like 'Microsoft.PowerShell.Core\Registry::*') { $Path = $Path.Split('::',2)[1] }
    if ($Path -like 'HKCU:\*') { return 'HKCU\' + $Path.Substring(6) }
    if ($Path -like 'HKLM:\*') { return 'HKLM\' + $Path.Substring(6) }
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

function Expand-Env([string]$Value) {
    if ([string]::IsNullOrWhiteSpace($Value)) { return $null }
    [Environment]::ExpandEnvironmentVariables($Value)
}

function Get-ItemPropertyValueSafe([string]$Path, [string]$Name) {
    try { (Get-ItemProperty -Path $Path -ErrorAction Stop).$Name } catch { $null }
}

function Is-OneDrivePath([string]$Path) {
    if ([string]::IsNullOrWhiteSpace($Path)) { return $false }
    return ($Path -match "\\OneDrive( - [^\\]+)?\\")
}

function Move-FolderContents([string]$Source, [string]$Dest) {
    if (-not (Test-Path -LiteralPath $Source -PathType Container)) { return }
    if (-not (Test-Path -LiteralPath $Dest -PathType Container)) { New-Item -ItemType Directory -Path $Dest -Force | Out-Null }
    & robocopy $Source $Dest /E /MOVE /R:1 /W:1 /NFL /NDL /NJH /NJS /NP | Out-Null
}

function Stop-OneDriveFolderBackup {
    $userShell = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\User Shell Folders'
    $shell     = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Shell Folders'
    $profile   = $env:USERPROFILE

    $defaultsUserShell = @{
        Desktop       = '%USERPROFILE%\Desktop'
        Personal      = '%USERPROFILE%\Documents'
        'My Pictures' = '%USERPROFILE%\Pictures'
    }

    $defaultsShell = @{
        Desktop       = (Join-Path $profile 'Desktop')
        Personal      = (Join-Path $profile 'Documents')
        'My Pictures' = (Join-Path $profile 'Pictures')
    }

    $currentUserShell = @{
        Desktop       = Get-ItemPropertyValueSafe $userShell 'Desktop'
        Personal      = Get-ItemPropertyValueSafe $userShell 'Personal'
        'My Pictures' = Get-ItemPropertyValueSafe $userShell 'My Pictures'
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
            "Confirm",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Question
        )
        if ($r -ne [System.Windows.MessageBoxResult]::Yes) { return }
        foreach ($m in $movePlan) { Move-FolderContents $m.Source $m.Dest }
    }

    foreach ($k in @('Desktop','Personal','My Pictures')) {
        Set-RegistryValue $userShell $k $defaultsUserShell[$k] 'ExpandString'
        Set-RegistryValue $shell     $k $defaultsShell[$k]     'String'
    }
}

# --- Paths ---
$hkcuCV          = 'HKCU:\Software\Microsoft\Windows\CurrentVersion'
$hkcuExplorerAdv = "$hkcuCV\Explorer\Advanced"
$hkcuPoliciesWin = 'HKCU:\Software\Policies\Microsoft\Windows'
$hkcuPoliciesCV  = "$hkcuCV\Policies"
$hkcuSiufRules   = 'HKCU:\Software\Microsoft\Siuf\Rules'
$hkcuAppEvents   = 'HKCU:\AppEvents\Schemes'

$hklmPoliciesWin = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows'
$hklmPoliciesDef = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender'

# --- Toggle tables ---
$registryToggles = @(
    [pscustomobject]@{ Check='DarkMode'; Path="$hkcuCV\Themes\Personalize"; Name='AppsUseLightTheme';    On=0; Off=1; Type='DWord'; RemoveWhenOff=$false },
    [pscustomobject]@{ Check='DarkMode'; Path="$hkcuCV\Themes\Personalize"; Name='SystemUsesLightTheme'; On=0; Off=1; Type='DWord'; RemoveWhenOff=$false },

    [pscustomobject]@{ Check='DisableNotifications'; Path="$hkcuCV\PushNotifications"; Name='ToastEnabled'; On=0; Off=1; Type='DWord'; RemoveWhenOff=$false },
    [pscustomobject]@{ Check='DisableActionCenter'; Path="$hkcuPoliciesWin\Explorer"; Name='DisableNotificationCenter'; On=1; Off=$null; Type='DWord'; RemoveWhenOff=$true },

    [pscustomobject]@{ Check='ShowHiddenFiles'; Path=$hkcuExplorerAdv; Name='Hidden';          On=1; Off=2; Type='DWord'; RemoveWhenOff=$false },
    [pscustomobject]@{ Check='ShowHiddenFiles'; Path=$hkcuExplorerAdv; Name='ShowSuperHidden'; On=1; Off=0; Type='DWord'; RemoveWhenOff=$false },

    [pscustomobject]@{ Check='TaskbarSettings'; Path=$hkcuExplorerAdv; Name='TaskbarSmallIcons'; On=1; Off=0; Type='DWord'; RemoveWhenOff=$false },
    [pscustomobject]@{ Check='DisableAnimations'; Path=$hkcuExplorerAdv; Name='TaskbarAnimations'; On=0; Off=1; Type='DWord'; RemoveWhenOff=$false },

    [pscustomobject]@{ Check='DisableAutoPlay'; Path="$hkcuPoliciesCV\Explorer"; Name='NoDriveTypeAutoRun'; On=255; Off=$null; Type='DWord'; RemoveWhenOff=$true },

    [pscustomobject]@{ Check='DisableGameBar'; Path="$hkcuCV\GameDVR"; Name='AppCaptureEnabled'; On=0; Off=1; Type='DWord'; RemoveWhenOff=$false },
    [pscustomobject]@{ Check='DisableGameBar'; Path='HKCU:\System\GameConfigStore'; Name='GameDVR_Enabled'; On=0; Off=1; Type='DWord'; RemoveWhenOff=$false },

    [pscustomobject]@{ Check='DisableBackgroundApps'; Path="$hkcuCV\BackgroundAccessApplications"; Name='GlobalUserDisabled'; On=1; Off=0; Type='DWord'; RemoveWhenOff=$false },

    [pscustomobject]@{ Check='PrivacySettings'; Path="$hkcuCV\AdvertisingInfo"; Name='Enabled'; On=0; Off=1; Type='DWord'; RemoveWhenOff=$false },

    [pscustomobject]@{ Check='DisableCortana'; Path="$hklmPoliciesWin\Windows Search"; Name='AllowCortana'; On=0; Off=$null; Type='DWord'; RemoveWhenOff=$true },
    [pscustomobject]@{ Check='DisableTelemetry'; Path="$hklmPoliciesWin\DataCollection"; Name='AllowTelemetry'; On=0; Off=$null; Type='DWord'; RemoveWhenOff=$true },
    [pscustomobject]@{ Check='DisableLockScreen'; Path="$hklmPoliciesWin\Personalization"; Name='NoLockScreen'; On=1; Off=$null; Type='DWord'; RemoveWhenOff=$true },

    [pscustomobject]@{ Check='DisableTimeline'; Path="$hklmPoliciesWin\System"; Name='EnableActivityFeed';    On=0; Off=$null; Type='DWord'; RemoveWhenOff=$true },
    [pscustomobject]@{ Check='DisableTimeline'; Path="$hklmPoliciesWin\System"; Name='PublishUserActivities'; On=0; Off=$null; Type='DWord'; RemoveWhenOff=$true },
    [pscustomobject]@{ Check='DisableTimeline'; Path="$hklmPoliciesWin\System"; Name='UploadUserActivities';  On=0; Off=$null; Type='DWord'; RemoveWhenOff=$true },

    [pscustomobject]@{ Check='DisableErrorReporting'; Path="$hklmPoliciesWin\Windows Error Reporting"; Name='Disabled'; On=1; Off=$null; Type='DWord'; RemoveWhenOff=$true },

    [pscustomobject]@{ Check='DisableWindowsDefender'; Path=$hklmPoliciesDef; Name='DisableAntiSpyware'; On=1; Off=$null; Type='DWord'; RemoveWhenOff=$true }
)

$customToggles = @(
    [pscustomobject]@{
        Check='DisableSystemSounds'
        RequiresAdmin=$false
        On = {
            Set-RegDefaultValue $hkcuAppEvents '.None' 'REG_SZ'
            Get-ChildItem -Path "$hkcuAppEvents\Apps" -ErrorAction SilentlyContinue |
                Get-ChildItem -ErrorAction SilentlyContinue |
                Get-ChildItem -ErrorAction SilentlyContinue |
                Where-Object { $_.PSChildName -eq '.Current' } |
                ForEach-Object { Set-RegDefaultValue $_.PSPath '' 'REG_SZ' }
        }
        Off = { Set-RegDefaultValue $hkcuAppEvents '.Default' 'REG_SZ' }
    }
    [pscustomobject]@{
        Check='PowerPlan'
        RequiresAdmin=$false
        On  = { powercfg /setactive SCHEME_MIN      | Out-Null }
        Off = { powercfg /setactive SCHEME_BALANCED | Out-Null }
    }
    [pscustomobject]@{
        Check='StopOneDriveFolderBackup'
        RequiresAdmin=$false
        On  = { Stop-OneDriveFolderBackup }
        Off = { }
    }
    [pscustomobject]@{
        Check='DisableFirewall'
        RequiresAdmin=$true
        On = {
            try {
                Import-Module NetSecurity -ErrorAction Stop
                Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled False -ErrorAction Stop
            } catch {
                & netsh advfirewall set allprofiles state off | Out-Null
            }
        }
        Off = {
            try {
                Import-Module NetSecurity -ErrorAction Stop
                Set-NetFirewallProfile -Profile Domain,Private,Public -Enabled True -ErrorAction Stop
            } catch {
                & netsh advfirewall set allprofiles state on | Out-Null
            }
        }
    }
)

function Apply-Toggles {
    $isAdmin = Is-Admin
    $skippedAdmin = [System.Collections.Generic.HashSet[string]]::new()

    if ($elements['DisableWindowsDefender'].IsChecked -eq $true) {
        $r = [System.Windows.MessageBox]::Show(
            "Disabling Defender is often blocked by Tamper Protection and reduces security. Continue?",
            "Confirm",
            [System.Windows.MessageBoxButton]::YesNo,
            [System.Windows.MessageBoxImage]::Warning
        )
        if ($r -ne [System.Windows.MessageBoxResult]::Yes) { $elements['DisableWindowsDefender'].IsChecked = $false }
    }

    if ($elements['DisableFirewall'].IsChecked -eq $true) {
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

        $needsAdmin = ($t.Path -like 'HKLM:*')
        if ($needsAdmin -and -not $isAdmin) { $null = $skippedAdmin.Add($t.Check); continue }

        if ($desiredOn) {
            Set-RegistryValue $t.Path $t.Name $t.On $t.Type
        } else {
            if ($t.RemoveWhenOff -and $null -eq $t.Off) {
                Remove-RegistryValue $t.Path $t.Name
            } elseif ($null -ne $t.Off) {
                Set-RegistryValue $t.Path $t.Name $t.Off $t.Type
            }
        }
    }

    $siufWanted = ($elements['PrivacySettings'].IsChecked -eq $true) -or ($elements['DisableFeedbackHub'].IsChecked -eq $true)
    if ($siufWanted) {
        Set-RegistryValue $hkcuSiufRules 'PeriodInNanoSeconds' 0 'QWord'
        Set-RegistryValue $hkcuSiufRules 'NumberOfSIUFInPeriod' 0 'DWord'
    } else {
        Remove-RegistryValue $hkcuSiufRules 'PeriodInNanoSeconds'
        Remove-RegistryValue $hkcuSiufRules 'NumberOfSIUFInPeriod'
    }

    foreach ($t in $customToggles) {
        if (-not $elements.ContainsKey($t.Check)) { continue }

        if ($t.RequiresAdmin -and -not $isAdmin) { $null = $skippedAdmin.Add($t.Check); continue }

        if ($elements[$t.Check].IsChecked -eq $true) { & $t.On } else { & $t.Off }
    }

    $note = "Tweaks applied. Some changes may require sign-out, Explorer restart, or reboot."
    if (-not $isAdmin -and $skippedAdmin.Count -gt 0) {
        $note += "`n`nSkipped (need Admin): " + (($skippedAdmin | Sort-Object) -join ', ')
    }

    [System.Windows.MessageBox]::Show(
        $note,
        "Info",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Information
    ) | Out-Null
}

$elements['ApplyTweaksButton'].Add_Click({
    try { Apply-Toggles }
    catch {
        [System.Windows.MessageBox]::Show(
            "Failed to apply tweaks:`n$($_.Exception.Message)",
            "Error",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    }
})

$Window.ShowDialog() | Out-Null
