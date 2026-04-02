#Requires AutoHotkey v2.0
#SingleInstance Force
Loop Files, A_ScriptDir "\autorun\*.ahk" {
    Run '"' A_AhkPath '" "' A_LoopFileFullPath '"'
}