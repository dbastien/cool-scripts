; AutoCorrect_LogCore.ahk — #Include before any :B0…::f("…") hotstrings.
; Same idea as AutoCorrect2-main\Includes\AutoCorrectSystem.ahk (f + InputHook); paths are local.

global AC_LoggingEnabled := true
global AC_LogFile := A_ScriptDir "\AutoCorrectsLog.txt"

#MaxThreadsPerHotkey 5

f(replace := "") {
    global AC_LoggingEnabled, AC_LogFile
    hk := A_ThisHotkey
    endchar := A_EndChar
    trigger := SubStr(hk, InStr(hk, ":",,, 2) + 1)
    logKey := trigger "::" replace
    TrigLen := StrLen(trigger) + StrLen(endchar)
    trigArr := StrSplit(trigger)
    replArr := StrSplit(replace)
    ignorLen := 0
    loop Min(trigArr.Length, replArr.Length) {
        if trigArr[A_Index] != replArr[A_Index]
            break
        ignorLen++
    }
    replace := SubStr(replace, ignorLen + 1)
    replace := StrReplace(replace, "'", "`'")
    endchar := StrReplace(endchar, "!", "{!}")
    SendInput("{BS " (TrigLen - ignorLen) "}" replace endchar)
    if AC_LoggingEnabled
        SetTimer(() => AC_LogKeepText(logKey), -1)
}

AC_LogKeepText(KeepForLog) {
    global AC_LogFile
    KeepForLog := StrReplace(KeepForLog, "`n", "``n")
    ih := InputHook("B V I1 E T1", "{Backspace}")
    ih.Start()
    ih.Wait()
    hyphen := (ih.EndKey = "Backspace") ? " << " : " -- "
    logEntry := "`n" A_YYYY "-" A_MM "-" A_DD hyphen KeepForLog
    try FileAppend(logEntry, AC_LogFile)
}

#MaxThreadsPerHotkey 1