// NavigateSymlink - Navigate to the target of a selected symlink or junction
// Select one or more symlinks, then run this command. Navigates to the first valid target.
// For directory symlinks: Go to target folder. For file symlinks: Go to containing folder.

function OnInit(initData) {
    var cmd = initData.AddCommand();
    cmd.name = "NavigateSymlink";
    cmd.method = "OnNavigateSymlink";
    cmd.desc = "Navigate to the resolved target of selected symlink(s) or junction(s)";
    cmd.label = "Navigate Symlink Target";
}

function OnNavigateSymlink(scriptCmdData) {
    var items = scriptCmdData.func.command.files;
    if (!items || items.Count === 0) {
        DOpus.Output("No items selected. Select a symlink or junction first.");
        return;
    }

    var item = items.Item(0);
    var path = item.path;
    if (!path) return;

    var resolved = DOpus.FSUtil.Resolve(path, "j");
    if (!resolved || resolved === path) {
        DOpus.Output("Selected item is not a symlink or junction, or could not resolve: " + path);
        return;
    }

    var pathObj = DOpus.FSUtil.NewPath(resolved);
    var isDir = DOpus.FSUtil.GetType(resolved) === "dir";
    var targetPath = isDir ? resolved : pathObj.pathpart;
    var safePath = targetPath.replace(/"/g, '""');
    scriptCmdData.func.command.RunCommand('Go "' + safePath + '"');
}
