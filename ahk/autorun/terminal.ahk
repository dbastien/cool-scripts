#Requires AutoHotkey v2.0
#SingleInstance Force

; --- config ---
; "wt.exe" uses PATH. Set a full path only for portable installs (then FileExist is checked).
global g_wtExe := "wt.exe"
; Args when starting Terminal cold (e.g. -p "Ubuntu" or -d "C:\Scripts").
global g_wtLaunchArgs := ""
; Extra args for RControl & Shift & t (new tab), e.g. -p "PowerShell".
global g_wtNewTabArgs := ""

; --- Hotkeys (match sibling scripts: RControl & letter) ---
RControl & t::TerminalOpenOrActivate()
RControl & Shift & t::TerminalNewTab()

TerminalOpenOrActivate() {
    if hwnd := WinExist("ahk_exe WindowsTerminal.exe") {
        WinActivate hwnd
        return
    }
    if !TerminalAssertExeExists()
        return
    Run Trim(g_wtExe . " " . g_wtLaunchArgs)
}

TerminalNewTab() {
    if !TerminalAssertExeExists()
        return
    Run Trim(g_wtExe . " nt " . g_wtNewTabArgs)
}

TerminalExePathIsConcrete() {
    return InStr(g_wtExe, "\") || SubStr(g_wtExe, 2, 1) = ":"
}

TerminalAssertExeExists() {
    if !TerminalExePathIsConcrete()
        return true
    if FileExist(g_wtExe)
        return true
    MsgBox "Windows Terminal not found:`n" g_wtExe, "Terminal", "Icon! T5"
    return false
}
