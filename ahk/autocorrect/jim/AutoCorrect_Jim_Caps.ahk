; Optional: two consecutive capitals fix (Laszlo). Enable from master via #Include.
keys := "abcdefghijklmnopqrstuvwxyz"
Loop Parse keys {
    HotKey("~+" A_LoopField, Hoty)
}

Hoty(ThisHotkey, *) {
    static CapCount := 0
    letter := SubStr(ThisHotkey, -1)
    CapCount := SubStr(A_PriorHotkey, 2, 1) = "+" && A_TimeSincePriorHotkey < 999 ? CapCount + 1 : 1
    if CapCount = 2
        SendInput("{BS}" letter)
    else if CapCount = 3
        SendInput("{Left}{BS}+" SubStr(A_PriorHotkey, -1) "{Right}")
}
