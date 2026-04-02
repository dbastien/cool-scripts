#Requires AutoHotkey v2.0
#SingleInstance Force

; RControl & g — open current selection as a Google search in the default browser.

RControl & g::GoogleSearchSelection()

GoogleSearchSelection() {
    old := A_Clipboard
    A_Clipboard := ""
    Send "^c"
    if !ClipWait(1) {
        A_Clipboard := old
        MsgBox "No text was copied (nothing selected?).", "Google search", "Icon! T5"
        return
    }
    q := Trim(A_Clipboard)
    A_Clipboard := old
    if (q = "") {
        MsgBox "Selection was empty.", "Google search", "Icon! T5"
        return
    }
    Run "https://www.google.com/search?q=" GoogleUriEncode(q)
}

; Percent-encode for query string (UTF-8 bytes; RFC 3986 unreserved left as-is).
GoogleUriEncode(str) {
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
