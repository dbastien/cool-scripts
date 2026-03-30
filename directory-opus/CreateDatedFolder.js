// CreateDatedFolder - Create a folder named YYYY-MM-DD and optionally move selected files into it

function OnInit(initData) {
    var cmd = initData.AddCommand();
    cmd.name = "CreateDatedFolder";
    cmd.method = "OnCreateDatedFolder";
    cmd.desc = "Create a folder named with today's date (YYYY-MM-DD) and optionally move selected files into it";
    cmd.label = "Create Dated Folder";
}

function OnCreateDatedFolder(scriptCmdData) {
    var srcPath = scriptCmdData.func.source.path;
    if (!srcPath) {
        DOpus.Output("Could not get current folder.");
        return;
    }

    var pathObj = DOpus.FSUtil.NewPath(srcPath);
    pathObj.Resolve("j");
    var basePath = pathObj.path;

    var now = new Date();
    var y = now.getFullYear();
    var m = (now.getMonth() + 1).toString();
    var d = now.getDate().toString();
    if (m.length < 2) m = "0" + m;
    if (d.length < 2) d = "0" + d;
    var folderName = y + "-" + m + "-" + d;
    var newFolderPath = basePath + "\\" + folderName;

    var cmd = scriptCmdData.func.command;
    var items = cmd.files;
    var hasSelection = items && items.Count > 0;
    var filesToMove = [];
    if (hasSelection) {
        for (var i = 0; i < items.Count; i++) {
            filesToMove.push(items.Item(i).path);
        }
    }

    cmd.RunCommand('CreateFolder "' + folderName.replace(/"/g, '""') + '"');

    if (filesToMove.length > 0) {
        cmd.ClearFiles();
        for (var i = 0; i < filesToMove.length; i++) {
            var runCmd = 'Copy FILE "' + filesToMove[i].replace(/"/g, '""') + '" MOVE TO "' + newFolderPath.replace(/"/g, '""') + '"';
            cmd.RunCommand(runCmd);
        }
    }

    cmd.RunCommand('Go "' + newFolderPath.replace(/"/g, '""') + '"');
}
