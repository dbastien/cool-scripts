// FlattenDirectory - Move all files from subdirectories into the current folder
// Run from the folder you want to flatten into. Subfolders remain; only files are moved.
// Name conflicts: Opus will auto-rename (e.g. file (1).txt).

function OnInit(initData) {
    var cmd = initData.AddCommand();
    cmd.name = "FlattenDirectory";
    cmd.method = "OnFlattenDirectory";
    cmd.desc = "Move all files from subdirectories into the current folder";
    cmd.label = "Flatten Directory";
}

function OnFlattenDirectory(scriptCmdData) {
    var srcPath = scriptCmdData.func.source.path;
    if (!srcPath) {
        DOpus.Output("Could not get current folder.");
        return;
    }

    var pathObj = DOpus.FSUtil.NewPath(srcPath);
    pathObj.Resolve("j");
    var basePath = pathObj.path;

    var result = DOpus.DlgMessage("Move all files from subdirectories into:\n" + basePath + "\n\nSubfolders will remain. Continue?", "Flatten Directory", "yesno");
    if (result !== "yes") return;

    var folderEnum = DOpus.FSUtil.ReadDir(basePath, "r");
    var files = [];
    while (!folderEnum.complete) {
        var item = folderEnum.Next();
        if (item && !item.is_dir) {
            files.push(item.path);
        }
    }

    var cmd = scriptCmdData.func.command;
    cmd.ClearFiles();
    var movedCount = 0;

    for (var i = 0; i < files.length; i++) {
        var filePath = files[i];
        var filePathPart = DOpus.FSUtil.NewPath(filePath).pathpart;
        if (filePathPart.toLowerCase() === basePath.toLowerCase()) continue;
        var runCmd = 'Copy FILE "' + filePath.replace(/"/g, '""') + '" MOVE TO "' + basePath.replace(/"/g, '""') + '"';
        cmd.RunCommand(runCmd);
        movedCount++;
    }

    DOpus.Output("Flattened " + movedCount + " file(s).");
}
