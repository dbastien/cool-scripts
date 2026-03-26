// Directory Opus — Script add-in: compact size column
//
// Install: Preferences → Toolbars / Scripts → Script Add-Ins → Install (or copy this file into
//   %APPDATA%\GPSoftware\Directory Opus\Script AddIns and enable it).
// Use: Settings → File Displays → Columns → Add → Script → "CompactSize" (header: c.size).
//
// Shows sizes as short suffix notation only (B, K, M, G, T, P) — no spelled-out "bytes".
// Folders: blank (no recursive size scan — keeps it fast). Files only use item.size.
//
// Ref: https://docs.dopus.com/doku.php?id=scripting:example_scripts:adding_a_new_column

function formatCompact1024(n) {
    var bytes = Number(n);
    if (!isFinite(bytes) || bytes < 0) return "";
    if (bytes === 0) return "0";

    var units = ["B", "K", "M", "G", "T", "P"];
    var i = 0;
    var v = bytes;
    while (v >= 1024 && i < units.length - 1) {
        v /= 1024;
        i++;
    }

    if (i === 0) return String(Math.floor(bytes));

    var decimals = v >= 100 ? 0 : v >= 10 ? 1 : 2;
    var s = v.toFixed(decimals);
    var dot = s.indexOf(".");
    if (dot >= 0) {
        while (s.length > dot + 1 && (s.charAt(s.length - 1) === "0" || s.charAt(s.length - 1) === ".")) {
            s = s.substring(0, s.length - 1);
        }
    }
    return s + units[i];
}

function OnInit(initData) {
    initData.name = "Compact size column";
    initData.desc = "Human-readable file sizes (B/K/M/G/…) without the word 'bytes'; fast (no folder totals).";
    initData.version = 1;
    initData.default_enable = true;

    var col = initData.AddColumn();
    col.name = "CompactSize";
    col.method = "OnCompactSize";
    col.label = "c.size";
    col.header = "c.size";
    col.justify = "right";
    col.defwidth = 8;
    col.autogroup = false;
    col.autorefresh = true;
}

function OnCompactSize(scriptColData) {
    if (scriptColData.col != "CompactSize") return;

    var item = scriptColData.item;
    if (item.is_dir) {
        scriptColData.value = "";
        scriptColData.sort = 0;
        return;
    }

    var sz = item.size;
    var n = Number(sz);
    if (!isFinite(n)) {
        scriptColData.value = "";
        scriptColData.sort = 0;
        return;
    }

    scriptColData.sort = n;
    scriptColData.value = formatCompact1024(n);
}
