#Requires AutoHotkey v2.0
#SingleInstance Force

; >^ = Right Ctrl; + = Shift
Hotkey ">^r", OpenRecycleBin
Hotkey ">^+r", EmptyRecycleBin

OpenRecycleBin(*) {
    Run "explorer.exe shell:RecycleBinFolder"
}

EmptyRecycleBin(*) {
    DllCall("shell32\SHEmptyRecycleBin", "Ptr", A_ScriptHwnd, "Ptr", 0, "UInt", 0)
}
