// ChecksumSelected - Show SHA256 (or MD5) hash of selected files
// Copies result to clipboard. Use template: HASH/K (md5|sha256) for algorithm choice.

function OnInit(initData) {
    var cmd = initData.AddCommand();
    cmd.name = "ChecksumSelected";
    cmd.method = "OnChecksumSelected";
    cmd.desc = "Show SHA256 hash of selected files (copy to clipboard)";
    cmd.label = "Checksum Selected";
    cmd.template = "HASH/K";
}

function OnChecksumSelected(scriptCmdData) {
    var items = scriptCmdData.func.command.files;
    if (!items || items.Count === 0) {
        DOpus.Output("No files selected.");
        return;
    }

    var algo = "sha256";
    if (scriptCmdData.func.args && scriptCmdData.func.args.got_arg && scriptCmdData.func.args.got_arg.hash) {
        var h = (scriptCmdData.func.args.hash || "").toLowerCase();
        if (h === "md5") algo = "md5";
        else if (h === "sha256" || h === "sha1") algo = h;
    }

    var lines = [];
    for (var i = 0; i < items.Count; i++) {
        var item = items.Item(i);
        if (item.is_dir) continue;
        var hash = DOpus.FSUtil.Hash(item.path, algo);
        if (hash) {
            lines.push(hash + "  " + item.name);
        }
    }

    if (lines.length === 0) {
        DOpus.Output("No files hashed (folders skipped).");
        return;
    }

    var text = lines.join("\r\n");
    DOpus.SetClip(text);
    DOpus.Output("Copied " + lines.length + " hash(es) to clipboard (" + algo + ").");
}
