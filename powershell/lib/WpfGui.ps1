#requires -Version 7.0
<#
.SYNOPSIS
  Shared helpers for PowerShell WPF (XAML) tools in this repo.
.DESCRIPTION
  Register-WpfPresentationAssemblies, Restart-PwshScriptInStaIfNeeded,
  Import-XamlWindowFromString, Get-XamlNamedElementMap — use from longer/*.ps1, Instellator, etc.
#>
function Register-WpfPresentationAssemblies {
  Add-Type -AssemblyName PresentationFramework
  Add-Type -AssemblyName PresentationCore
  Add-Type -AssemblyName WindowsBase
}
function Restart-PwshScriptInStaIfNeeded {
  if ([Threading.Thread]::CurrentThread.ApartmentState -eq 'STA') { return }
  $pwshPath = (Get-Process -Id $PID).Path
  $argList = @('-NoProfile', '-Sta', '-ExecutionPolicy', 'Bypass', '-File', $PSCommandPath) + $args
  Start-Process -FilePath $pwshPath -ArgumentList $argList | Out-Null
  exit
}
function Import-XamlWindowFromString {
  param([Parameter(Mandatory)][string]$XamlText)
  $sr = $null; $xr = $null
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
function Get-XamlNamedElementMap {
  param([Parameter(Mandatory)]$Window, [Parameter(Mandatory)][string]$XamlText)
  $elements = @{}
  $names = [regex]::Matches($XamlText, 'x:Name="([^"]+)"') | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
  foreach ($name in $names) {
    $ctrl = $Window.FindName($name)
    if ($null -ne $ctrl) { $elements[$name] = $ctrl }
  }
  $elements
}
