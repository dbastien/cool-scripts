#Requires AutoHotkey v2.0
; =============================================================================
; AUTO-CORRECT (run this file)
; =============================================================================
; Double-click: ahk\autocorrect\autocorrect.ahk
; Via startup:  ahk\startup.ahk runs everything in ahk\autorun\ — including
;               autorun\autocorrect.ahk, which #Include's this script.
;
; Folder layout (not "old monoliths" — the big Jim list lives in fragments):
;   autocorrect\jim\*.ahk     Jim typo sections (ign, endings, main list, …)
;   autocorrect\AutoCorrect_Word.ahk   MS-Word-style list
;   autocorrect\AutoCorrect_Shorthand.ahk   netspeak / abbreviations
;   autocorrect\AutoCorrect_Softer.ahk   rough language → milder wording
;   autocorrect\AutoCorrect_User.ahk  your hotkey additions (gitignored if listed)
;   autocorrect\AutoCorrectsLog.txt  -- kept / << backspaced soon after (gitignored)
;   autocorrect\AutoCorrect_LogCore.ahk  f() + log; AC_LoggingEnabled := false to disable
;
; Toggle lists: comment/uncomment the #Include block at the bottom (Jim-only = jim\*.ahk only, etc.).
;
; Unrelated utilities in ahk\: nocaps.ahk, autoclick.ahk, startup.ahk, autorun\*
; Credits: Jim Biancolo typo data (2006) + community lists — see git history.
; Optional snapshot: autocorrect\reference\AutoCorrect2_AutoCorrectSystem.ahk
; Full upstream tree (reference): AutoCorrect2-main\ in repo if present — not loaded by this script.
; =============================================================================

#SingleInstance Force

global UserHotstringFile := A_ScriptDir "\AutoCorrect_User.ahk"
global gHotstringForCaret := ""
global gNewHsDefault := ""

; ---------------------------------------------------------------------------
; OPTIONAL MODULES — comment/uncomment #Include lines (order matters for Jim).
; Jim-only: disable AutoCorrect_Word + Shorthand + Softer includes at bottom.
; Shorthand-only: disable jim\*.ahk and AutoCorrect_Word; keep LogCore + shorthand file.
; Softer-only: disable jim\*.ahk, Word, Shorthand; keep LogCore + AutoCorrect_Softer.ahk.
; ---------------------------------------------------------------------------
;#Include %A_ScriptDir%\jim\AutoCorrect_Jim_Caps.ahk   ; two caps fix (risky in code)

; New hotstring: select trigger text, then Right Ctrl+H (avoids Win+H = voice typing).
>^h:: {
    global UserHotstringFile, gHotstringForCaret, gNewHsDefault
    oldClip := ClipboardAll()
    A_Clipboard := ""
    Send("^c")
    if !ClipWait(1) {
        A_Clipboard := oldClip
        return
    }
    hot := A_Clipboard
    A_Clipboard := oldClip
    hot := StrReplace(hot, "``", "````")
    hot := StrReplace(hot, "`r`n", "``r")
    hot := StrReplace(hot, "`n", "``r")
    hot := StrReplace(hot, "`t", "``t")
    hot := StrReplace(hot, ";", "```;")
    gHotstringForCaret := hot
    esc0 := StrReplace(StrReplace(hot, "\", "\\"), '"', '\"')
    def := ":B0:" hot "::f(`"" esc0 "`")"
    gNewHsDefault := def
    SetTimer(MoveCaret, -10)
    ib := InputBox("Edit the replacement inside f(`"…`"). Plain ::a::b is OK (auto-wrapped).", "New Hotstring",, def)
    if ib.Result = "Cancel"
        return
    line := NormalizeUserHotstring(ib.Value)
    try FileAppend("`n" line, UserHotstringFile)
    catch {
        MsgBox("Could not write to:`n" UserHotstringFile, "AutoCorrect", "Icon!")
        return
    }
    Reload()
    Sleep(200)
    if MsgBox("The hotstring just added appears to be improperly formatted. Open the user file to fix it?", "AutoCorrect", "YesNo Icon?") = "Yes"
        Run('notepad.exe "' UserHotstringFile '"')
}

MoveCaret() {
    global gHotstringForCaret, gNewHsDefault
    if !WinActive("New Hotstring")
        return
    Send("{Home}")
    p := InStr(gNewHsDefault, 'f("')
    if p
        Loop (p + 1)
            SendInput("{Right}")
    else
        Loop (gHotstringForCaret.Length + 4)
            SendInput("{Right}")
    SetTimer(MoveCaret, 0)
}

NormalizeUserHotstring(s) {
    s := Trim(s, " `t`r`n")
    if InStr(s, 'f("')
        return s
    if !RegExMatch(s, "^:([^:]*):([^:]+)::(.*)$", &m)
        return s
    rep := m[3]
    if (rep = "")
        return s
    esc := StrReplace(StrReplace(rep, "\", "\\"), '"', '\"')
    opt := m[1]
    newOpt := (SubStr(opt, 1, 2) = "B0") ? opt : "B0" opt
    return ":" newOpt ":" m[2] "::f(`"" esc "`")"
}

#Include %A_ScriptDir%\AutoCorrect_LogCore.ahk

#Hotstring R

; --- Jim list (keep order: nullifiers before :?:ign::ing, etc.) ---
#Include %A_ScriptDir%\jim\AutoCorrect_Jim_Ign.ahk
#Include %A_ScriptDir%\jim\AutoCorrect_Jim_WordEndings.ahk
#Include %A_ScriptDir%\jim\AutoCorrect_Jim_WordBeginnings.ahk
#Include %A_ScriptDir%\jim\AutoCorrect_Jim_WordMiddles.ahk
#Include %A_ScriptDir%\jim\AutoCorrect_Jim_Accented.ahk
#Include %A_ScriptDir%\jim\AutoCorrect_Jim_Main.ahk
;#Include %A_ScriptDir%\jim\AutoCorrect_Jim_Ambiguous.ahk   ; edit file to uncomment entries inside first
#Include %A_ScriptDir%\jim\AutoCorrect_Jim_Dates.ahk

; --- Extra lists (comment out to disable: Word, Shorthand, Softer) ---
#Include %A_ScriptDir%\AutoCorrect_Word.ahk
#Include %A_ScriptDir%\AutoCorrect_Shorthand.ahk
#Include %A_ScriptDir%\AutoCorrect_Softer.ahk
; --- Your additions (optional file; *i = skip if missing) ---
#Include *i %A_ScriptDir%\AutoCorrect_User.ahk
