#Requires AutoHotkey v2.0
#SingleInstance Force

; Same pattern as terminal.ahk / obsidian.ahk: RControl & letter + Shift branch.
RControl & r:: {
    if GetKeyState("Shift", "P")
        EmptyRecycleBin()
    else
        OpenRecycleBin()
}

OpenRecycleBin(*) {
    Run "explorer.exe shell:RecycleBinFolder"
}

EmptyRecycleBin(*) {
    DllCall("shell32\SHEmptyRecycleBin", "Ptr", A_ScriptHwnd, "Ptr", 0, "UInt", 0)
}
