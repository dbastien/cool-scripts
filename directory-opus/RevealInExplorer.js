// RevealInExplorer - Open the current folder in Windows Explorer
// Useful when you need Explorer for certain integrations or to share the path.

function OnInit(initData) {
    var cmd = initData.AddCommand();
    cmd.name = "RevealInExplorer";
    cmd.method = "OnRevealInExplorer";
    cmd.desc = "Open the current folder in Windows Explorer";
    cmd.label = "Reveal in Explorer";
}

function OnRevealInExplorer(scriptCmdData) {
    var srcPath = scriptCmdData.func.source.path;
    if (!srcPath) {
        DOpus.Output("Could not get current folder.");
        return;
    }

    var pathObj = DOpus.FSUtil.NewPath(srcPath);
    pathObj.Resolve("j");
    var targetPath = pathObj.path;

    var safePath = targetPath.replace(/"/g, '\\"');
    DOpus.FSUtil.Run('explorer.exe /e,"' + safePath + '"', 1);
}
