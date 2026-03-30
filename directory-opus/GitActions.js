// GitActions — Git pull / push / fetch / status / log / branch / gui for the repo containing the current folder.
// If the path is not inside a Git work tree, shows a short message and does nothing.
// Optional: GitActions ACTION=pull  (same for push, fetch, status, log, branch, gui)

function OnInit(initData) {
    initData.name = "Git Actions";
    initData.desc = "Git commands for the current folder when it is inside a repository";
    initData.default_enable = true;

    var cmd = initData.AddCommand();
    cmd.name = "GitActions";
    cmd.method = "OnGitActions";
    cmd.desc = initData.desc;
    cmd.label = "Git Actions...";
    cmd.template = "ACTION/K";
}

function gitQuotePath(p) {
    return String(p).replace(/"/g, '\\"');
}

function findGitRoot(folderPath) {
    var p = String(folderPath);
    while (p && p.length >= 2) {
        if (DOpus.FSUtil.Exists(p + "\\.git")) {
            return p;
        }
        var last = p.lastIndexOf("\\");
        if (last < 0) {
            break;
        }
        if (last === 2 && p.charAt(1) === ":") {
            p = p.substring(0, 3);
            if (DOpus.FSUtil.Exists(p + ".git")) {
                return p;
            }
            break;
        }
        p = p.substring(0, last);
        if (p.length === 2 && p.charAt(1) === ":") {
            p += "\\";
        }
    }
    return null;
}

function runGitInteractive(repoRoot, args) {
    DOpus.FSUtil.Run('cmd.exe /k git ' + args, 1, "", "", repoRoot);
}

function runGitCapture(repoRoot, args) {
    var qp = gitQuotePath(repoRoot);
    var line = 'git -C "' + qp + '" ' + args;
    var rr = DOpus.FSUtil.Run(line, 0, "rw");
    if (!rr) {
        return "(git failed — is Git on PATH?)";
    }
    var o = rr.output;
    if (typeof o === "undefined" || o === null) {
        o = "";
    } else {
        o = String(o);
    }
    if (typeof rr.error !== "undefined" && rr.error !== null && String(rr.error).length > 0) {
        o += (o ? "\n" : "") + String(rr.error);
    }
    return o.length ? o : "(no output)";
}

function showTextDlg(title, text) {
    var maxLen = 3800;
    var t = String(text);
    if (t.length > maxLen) {
        DOpus.Output(title + " (full):\n" + t);
        t = t.substring(0, maxLen) + "\n\n… (truncated; see script log)";
    }
    DOpus.DlgMessage(t, title, "icon0");
}

function dispatchAction(index, gitRoot) {
    switch (index) {
        case 0:
            runGitInteractive(gitRoot, "pull");
            break;
        case 1:
            runGitInteractive(gitRoot, "push");
            break;
        case 2:
            runGitInteractive(gitRoot, "fetch");
            break;
        case 3:
            showTextDlg("git status", runGitCapture(gitRoot, "status -sb"));
            break;
        case 4:
            showTextDlg("git log", runGitCapture(gitRoot, "log --oneline -n 20"));
            break;
        case 5:
            showTextDlg("git branch", runGitCapture(gitRoot, "branch -v"));
            break;
        case 6:
            DOpus.FSUtil.Run("git.exe gui", 1, "", "", gitRoot);
            break;
        default:
            break;
    }
}

function OnGitActions(scriptCmdData) {
    var srcPath = scriptCmdData.func.source.path;
    if (!srcPath) {
        DOpus.Output("Could not get current folder.");
        return;
    }

    var pathObj = DOpus.FSUtil.NewPath(srcPath);
    pathObj.Resolve("j");
    var folderPath = pathObj.path;

    var gitRoot = findGitRoot(folderPath);
    if (!gitRoot) {
        DOpus.DlgMessage("This folder is not inside a Git repository (no .git found).", "Git Actions", "icon0");
        return;
    }

    var args = scriptCmdData.func.args;
    if (args.got_arg.action) {
        var action = String(args.action).toLowerCase();
        var actionMap = {
            pull: 0,
            push: 1,
            fetch: 2,
            status: 3,
            log: 4,
            branch: 5,
            branches: 5,
            gui: 6
        };
        if (!actionMap.hasOwnProperty(action)) {
            DOpus.Output("GitActions: unknown ACTION=" + args.action);
            return;
        }
        dispatchAction(actionMap[action], gitRoot);
        return;
    }

    var dlg = DOpus.Dlg;
    if (scriptCmdData.func.sourcetab && scriptCmdData.func.sourcetab.lister) {
        dlg.window = scriptCmdData.func.sourcetab.lister;
    }
    dlg.title = "Git Actions";
    dlg.message = "Repository:\n" + gitRoot + "\n\nChoose an action:";
    dlg.buttons = "OK|Cancel";
    dlg.choices = DOpus.Create.Vector(
        "Pull",
        "Push",
        "Fetch",
        "Status",
        "Log (last 20 commits)",
        "Branches (local)",
        "Git GUI"
    );
    dlg.selection = 0;

    if (dlg.Show() !== "ok") {
        return;
    }

    dispatchAction(dlg.selection, gitRoot);
}
