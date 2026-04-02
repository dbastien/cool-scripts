#Requires AutoHotkey v2.0
#SingleInstance Force

; --- config ---
; Default install path (override if you use a portable build).
global g_obsidianExe := A_ProgramFiles "\Obsidian\Obsidian.exe"

; Second argument to Obsidian.exe: vault folder (relative or absolute).
; Ignored when g_obsidianVaultName is set (URI launch is used instead).
global g_vaultPath := "everything\Welcome"

; If non-empty, cold launch uses obsidian://open?vault=... (must match the name
; in Obsidian's vault list). Enables obsidian://search for RControl & Shift & o.
global g_obsidianVaultName := ""

; --- Hotkeys (match sibling scripts: RControl & letter) ---
RControl & o::ObsidianOpenOrActivate()
RControl & Shift & o::ObsidianSearchPrompt()

ObsidianOpenOrActivate() {
    if hwnd := WinExist("ahk_exe Obsidian.exe") {
        WinActivate hwnd
        return
    }
    if !FileExist(g_obsidianExe) {
        MsgBox "Obsidian executable not found:`n" g_obsidianExe, "Obsidian", "Icon! T5"
        return
    }
    if (g_obsidianVaultName != "") {
        Run "obsidian://open?vault=" ObsidianUriEncode(g_obsidianVaultName)
        return
    }
    vault := g_vaultPath
    if ObsidianVaultPathLooksAbsolute(vault) && !DirExist(vault) {
        MsgBox "Vault folder not found:`n" vault, "Obsidian", "Icon! T5"
        return
    }
    Run Format('"{}" "{}"', g_obsidianExe, vault)
}

ObsidianSearchPrompt() {
    if (g_obsidianVaultName = "") {
        MsgBox "Set g_obsidianVaultName to use search (obsidian:// URI).", "Obsidian", "Iconi T5"
        return
    }
    ib := InputBox("Search query (opens in Obsidian)", "Obsidian search", , "")
    if ib.Result != "OK" || ib.Value = ""
        return
    query := ib.Value
    Run "obsidian://search?vault=" ObsidianUriEncode(g_obsidianVaultName) "&query=" ObsidianUriEncode(query)
}

ObsidianVaultPathLooksAbsolute(path) {
    return SubStr(path, 2, 1) = ":" || SubStr(path, 1, 1) = "\"
}

; Percent-encode for obsidian:// query parts (UTF-8 bytes; RFC 3986 unreserved left as-is).
ObsidianUriEncode(str) {
    if str = ""
        return ""
    size := StrPut(str, "UTF-8")
    buf := Buffer(size)
    StrPut(str, buf, "UTF-8")
    out := ""
    Loop size - 1 {
        b := NumGet(buf, A_Index - 1, "UChar")
        if (b >= 0x30 && b <= 0x39) || (b >= 0x41 && b <= 0x5A) || (b >= 0x61 && b <= 0x7A) || b = 0x2D || b = 0x5F || b = 0x2E || b = 0x7E
            out .= Chr(b)
        else
            out .= Format("%{:02X}", b)
    }
    return out
}
