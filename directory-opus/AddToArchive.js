// AddToArchive - Add selected files to archive with compressor choice
// Shows a dialog to pick format (Zip, 7z, Tar, etc.) then opens Add to Archive with that format.

function OnInit(initData) {
    var cmd = initData.AddCommand();
    cmd.name = "AddToArchive";
    cmd.method = "OnAddToArchive";
    cmd.desc = "Add selected files to archive; choose compressor (Zip, 7z, Tar, etc.)";
    cmd.label = "Add to Archive...";
}

function OnAddToArchive(scriptCmdData) {
    var dlg = DOpus.Dlg;
    if (scriptCmdData.func.sourcetab && scriptCmdData.func.sourcetab.lister) {
        dlg.window = scriptCmdData.func.sourcetab.lister;
    }
    dlg.title = "Add to Archive";
    dlg.message = "Choose archive format:";
    dlg.buttons = "OK|Cancel";
    dlg.choices = DOpus.Create.Vector(
        "Zip (.zip)",
        "7-Zip (.7z)",
        "Tar (.tar)",
        "Tar Gzip (.tar.gz)",
        "Tar Bzip2 (.tar.bz2)",
        "Tar XZ (.tar.xz)"
    );
    dlg.selection = 0;

    if (dlg.Show() !== "ok") return;

    var extMap = [".zip", ".7z", ".tar", ".tar.gz", ".tar.bz2", ".tar.xz"];
    var ext = extMap[dlg.selection];

    var cmd = scriptCmdData.func.command;
    cmd.RunCommand("Copy ADDTOARCHIVE=" + ext);
}
