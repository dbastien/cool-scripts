// Directory Opus — Advanced Rename script (JScript)
//
// Use: Rename dialog → enable Script → Script Type: JScript → paste this file.
// Collapses repeated identical extensions:  notes.txt.txt → notes.txt
// (case-insensitive on the repeated pair). Files only; folders unchanged.
//
// Ref: https://docs.dopus.com/doku.php?id=scripting:rename_scripts

function endsWithI(hay, needle) {
    if (needle.length === 0 || hay.length < needle.length) return false;
    var h = hay.toLowerCase();
    var n = needle.toLowerCase();
    return h.substring(h.length - n.length) === n;
}

// Repeatedly strip ".ext" when the stem already ends with the same ".ext".
function collapseRepeatedExtension(name) {
    var changed = true;
    while (changed) {
        changed = false;
        var dot = name.lastIndexOf(".");
        if (dot <= 0) break;
        var ext = name.substring(dot);
        if (ext.length < 2) break;
        var stem = name.substring(0, dot);
        if (endsWithI(stem, ext)) {
            name = stem;
            changed = true;
        }
    }
    return name;
}

function OnGetNewName(data) {
    if (data.item.is_dir) return false;

    var proposed = data.newname;
    var fixed = collapseRepeatedExtension(proposed);
    if (fixed !== proposed) return fixed;
    return false;
}
