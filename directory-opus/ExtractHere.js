// ExtractHere - Extract selected archives into the current folder (no subfolder per archive)
// Select one or more zip/7z/etc files, then run. Contents extract directly into current folder.

function OnInit(initData) {
    var cmd = initData.AddCommand();
    cmd.name = "ExtractHere";
    cmd.method = "OnExtractHere";
    cmd.desc = "Extract selected archives into the current folder (no subfolder per archive)";
    cmd.label = "Extract Here";
}

function OnExtractHere(scriptCmdData) {
    var items = scriptCmdData.func.command.files;
    if (!items || items.Count === 0) {
        DOpus.Output("No archives selected.");
        return;
    }

    var destPath = scriptCmdData.func.source.path;
    if (!destPath) {
        DOpus.Output("Could not get current folder.");
        return;
    }

    var pathObj = DOpus.FSUtil.NewPath(destPath);
    pathObj.Resolve("j");
    destPath = pathObj.path;

    var cmd = scriptCmdData.func.command;
    cmd.SetDest(destPath);
    cmd.RunCommand("Copy EXTRACT=here");
}
