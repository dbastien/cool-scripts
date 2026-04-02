/* explorer-cut-paste */
var __defProp = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __export = (target, all) => {
  for (var name in all)
    __defProp(target, name, { get: all[name], enumerable: true });
};
var __copyProps = (to, from, except, desc) => {
  if (from && typeof from === "object" || typeof from === "function") {
    for (let key of __getOwnPropNames(from))
      if (!__hasOwnProp.call(to, key) && key !== except)
        __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
  }
  return to;
};
var __toCommonJS = (mod) => __copyProps(__defProp({}, "__esModule", { value: true }), mod);

// src/main.ts
var main_exports = {};
__export(main_exports, {
  default: () => ExplorerCutPastePlugin
});
module.exports = __toCommonJS(main_exports);
var import_obsidian2 = require("obsidian");

// src/explorerOps.ts
var import_obsidian = require("obsidian");
var FILE_EXPLORER = "file-explorer";
var ExplorerOps = class {
  constructor(app) {
    this.app = app;
  }
  getExplorer() {
    const leaves = this.app.workspace.getLeavesOfType(FILE_EXPLORER);
    if (!leaves.length)
      return null;
    return leaves[0].view;
  }
  isExplorerActive() {
    const v = this.app.workspace.getActiveViewOfType(import_obsidian.View);
    return v?.getViewType() === FILE_EXPLORER;
  }
  activeFileOrFolder() {
    const ex = this.getExplorer();
    if (!ex)
      return null;
    return ex.tree.focusedItem?.file ?? ex.activeDom?.file ?? null;
  }
  hasActiveRow() {
    return this.activeFileOrFolder() !== null;
  }
  /** Selected rows, or the focused row if selection is empty. */
  getSourcesForOperation() {
    const ex = this.getExplorer();
    if (!ex)
      return [];
    if (ex.tree.selectedDoms.size === 0) {
      const one = this.activeFileOrFolder();
      return one ? [one] : [];
    }
    return [...ex.tree.selectedDoms].map((row) => row.file);
  }
  /** Map source vault path → destination basename (prune nested selections). */
  buildClipboardMap(files) {
    const paths = pruneDescendantPaths(files.map((f) => f.path));
    const m = /* @__PURE__ */ new Map();
    for (const p of paths) {
      const base = p.split("/").pop();
      if (base)
        m.set(p, base);
    }
    return m;
  }
  /** Folder to receive pasted items: focused folder, or parent of focused file. */
  getPasteFolder() {
    const f = this.activeFileOrFolder();
    if (!f)
      return null;
    if (f instanceof import_obsidian.TFolder)
      return f;
    return f.parent instanceof import_obsidian.TFolder ? f.parent : null;
  }
};
function pruneDescendantPaths(paths) {
  const sorted = [...paths].sort(
    (a, b) => a.split("/").length - b.split("/").length
  );
  const kept = [];
  for (const p of sorted) {
    const under = kept.some((k) => p === k || p.startsWith(k + "/"));
    if (!under)
      kept.push(p);
  }
  return kept;
}
function joinVault(folderPath, name) {
  if (!folderPath)
    return name;
  return `${folderPath}/${name}`;
}
function addSuffixBeforeExtension(path, suffix) {
  const slash = path.lastIndexOf("/");
  const dot = path.lastIndexOf(".");
  if (dot > slash) {
    return `${path.slice(0, dot)}${suffix}.${path.slice(dot + 1)}`;
  }
  return path + suffix;
}
function uniqueDestPath(vault, desired, isFile) {
  let candidate = desired;
  for (let i = 1; vault.getAbstractFileByPath(candidate); i++) {
    candidate = isFile ? addSuffixBeforeExtension(desired, ` ${i}`) : `${desired} ${i}`;
  }
  return candidate;
}
async function copyFolderTree(vault, folder, destRoot) {
  if (!vault.getAbstractFileByPath(destRoot)) {
    await vault.createFolder(destRoot);
  }
  const children = [];
  import_obsidian.Vault.recurseChildren(folder, (c) => {
    children.push(c);
  });
  children.sort(
    (a, b) => a.path.split("/").length - b.path.split("/").length
  );
  for (const child of children) {
    const rel = child.path.slice(folder.path.length).replace(/^\//, "");
    const fullDest = joinVault(destRoot, rel);
    if (child instanceof import_obsidian.TFolder) {
      if (!vault.getAbstractFileByPath(fullDest)) {
        await vault.createFolder(fullDest);
      }
    } else {
      await vault.copy(child, fullDest);
    }
  }
}
function invalidMoveIntoSelf(src, destDirPath) {
  if (!(src instanceof import_obsidian.TFolder))
    return false;
  const s = src.path;
  return destDirPath === s || destDirPath.startsWith(s + "/");
}
async function pasteClipboard(app, clipboard, mode) {
  const ops = new ExplorerOps(app);
  const destFolder = ops.getPasteFolder();
  if (!destFolder) {
    new import_obsidian.Notice("Select a file or folder in the file explorer first.");
    return;
  }
  if (clipboard.size === 0) {
    new import_obsidian.Notice("Nothing in the explorer clipboard.");
    return;
  }
  const destDirPath = destFolder.path;
  const vault = app.vault;
  const fm = app.fileManager;
  for (const [srcPath, baseName] of clipboard) {
    const src = vault.getAbstractFileByPath(srcPath);
    if (!src) {
      new import_obsidian.Notice(`Missing: ${srcPath}`);
      continue;
    }
    if (mode === "cut" && invalidMoveIntoSelf(src, destDirPath)) {
      new import_obsidian.Notice(`Cannot move a folder into itself: ${baseName}`);
      continue;
    }
    let desired = joinVault(destDirPath, baseName);
    const isFile = src instanceof import_obsidian.TFile;
    if (vault.getAbstractFileByPath(desired)) {
      desired = uniqueDestPath(vault, desired, isFile);
    }
    if (mode === "cut") {
      if (srcPath === desired)
        continue;
      await fm.renameFile(src, desired);
    } else if (src instanceof import_obsidian.TFile) {
      await vault.copy(src, desired);
    } else {
      await copyFolderTree(vault, src, desired);
    }
  }
  new import_obsidian.Notice(mode === "cut" ? "Moved." : "Pasted.");
}

// src/main.ts
var ExplorerCutPastePlugin = class extends import_obsidian2.Plugin {
  constructor() {
    super(...arguments);
    this.clipboard = null;
    this.mode = "copy";
  }
  ops() {
    return new ExplorerOps(this.app);
  }
  async onload() {
    this.addCommand({
      id: "cut",
      name: "Explorer clipboard: Cut",
      checkCallback: (checking) => {
        if (!this.ops().isExplorerActive())
          return false;
        const files = this.ops().getSourcesForOperation();
        if (!files.length)
          return false;
        if (!checking) {
          this.clipboard = this.ops().buildClipboardMap(files);
          this.mode = "cut";
          new import_obsidian2.Notice("Cut (explorer clipboard)");
        }
        return true;
      }
    });
    this.addCommand({
      id: "copy",
      name: "Explorer clipboard: Copy",
      checkCallback: (checking) => {
        if (!this.ops().isExplorerActive())
          return false;
        const files = this.ops().getSourcesForOperation();
        if (!files.length)
          return false;
        if (!checking) {
          this.clipboard = this.ops().buildClipboardMap(files);
          this.mode = "copy";
          new import_obsidian2.Notice("Copied (explorer clipboard)");
        }
        return true;
      }
    });
    this.addCommand({
      id: "paste",
      name: "Explorer clipboard: Paste into folder",
      checkCallback: (checking) => {
        if (!this.ops().isExplorerActive())
          return false;
        if (!this.ops().hasActiveRow())
          return false;
        if (!this.clipboard?.size)
          return false;
        if (!checking) {
          void (async () => {
            const clip = this.clipboard;
            const mode = this.mode;
            await pasteClipboard(this.app, clip, mode);
            if (mode === "cut")
              this.clipboard = null;
          })();
        }
        return true;
      }
    });
  }
};
//# sourceMappingURL=data:application/json;base64,ewogICJ2ZXJzaW9uIjogMywKICAic291cmNlcyI6IFsic3JjL21haW4udHMiLCAic3JjL2V4cGxvcmVyT3BzLnRzIl0sCiAgInNvdXJjZXNDb250ZW50IjogWyJpbXBvcnQgeyBOb3RpY2UsIFBsdWdpbiB9IGZyb20gXCJvYnNpZGlhblwiO1xyXG5pbXBvcnQgeyBFeHBsb3Jlck9wcywgcGFzdGVDbGlwYm9hcmQsIHR5cGUgQ2xpcGJvYXJkTW9kZSB9IGZyb20gXCIuL2V4cGxvcmVyT3BzXCI7XHJcblxyXG5leHBvcnQgZGVmYXVsdCBjbGFzcyBFeHBsb3JlckN1dFBhc3RlUGx1Z2luIGV4dGVuZHMgUGx1Z2luIHtcclxuXHRwcml2YXRlIGNsaXBib2FyZDogTWFwPHN0cmluZywgc3RyaW5nPiB8IG51bGwgPSBudWxsO1xyXG5cdHByaXZhdGUgbW9kZTogQ2xpcGJvYXJkTW9kZSA9IFwiY29weVwiO1xyXG5cclxuXHRwcml2YXRlIG9wcygpOiBFeHBsb3Jlck9wcyB7XHJcblx0XHRyZXR1cm4gbmV3IEV4cGxvcmVyT3BzKHRoaXMuYXBwKTtcclxuXHR9XHJcblxyXG5cdGFzeW5jIG9ubG9hZCgpOiBQcm9taXNlPHZvaWQ+IHtcclxuXHRcdHRoaXMuYWRkQ29tbWFuZCh7XHJcblx0XHRcdGlkOiBcImN1dFwiLFxyXG5cdFx0XHRuYW1lOiBcIkV4cGxvcmVyIGNsaXBib2FyZDogQ3V0XCIsXHJcblx0XHRcdGNoZWNrQ2FsbGJhY2s6IChjaGVja2luZykgPT4ge1xyXG5cdFx0XHRcdGlmICghdGhpcy5vcHMoKS5pc0V4cGxvcmVyQWN0aXZlKCkpIHJldHVybiBmYWxzZTtcclxuXHRcdFx0XHRjb25zdCBmaWxlcyA9IHRoaXMub3BzKCkuZ2V0U291cmNlc0Zvck9wZXJhdGlvbigpO1xyXG5cdFx0XHRcdGlmICghZmlsZXMubGVuZ3RoKSByZXR1cm4gZmFsc2U7XHJcblx0XHRcdFx0aWYgKCFjaGVja2luZykge1xyXG5cdFx0XHRcdFx0dGhpcy5jbGlwYm9hcmQgPSB0aGlzLm9wcygpLmJ1aWxkQ2xpcGJvYXJkTWFwKGZpbGVzKTtcclxuXHRcdFx0XHRcdHRoaXMubW9kZSA9IFwiY3V0XCI7XHJcblx0XHRcdFx0XHRuZXcgTm90aWNlKFwiQ3V0IChleHBsb3JlciBjbGlwYm9hcmQpXCIpO1xyXG5cdFx0XHRcdH1cclxuXHRcdFx0XHRyZXR1cm4gdHJ1ZTtcclxuXHRcdFx0fSxcclxuXHRcdH0pO1xyXG5cclxuXHRcdHRoaXMuYWRkQ29tbWFuZCh7XHJcblx0XHRcdGlkOiBcImNvcHlcIixcclxuXHRcdFx0bmFtZTogXCJFeHBsb3JlciBjbGlwYm9hcmQ6IENvcHlcIixcclxuXHRcdFx0Y2hlY2tDYWxsYmFjazogKGNoZWNraW5nKSA9PiB7XHJcblx0XHRcdFx0aWYgKCF0aGlzLm9wcygpLmlzRXhwbG9yZXJBY3RpdmUoKSkgcmV0dXJuIGZhbHNlO1xyXG5cdFx0XHRcdGNvbnN0IGZpbGVzID0gdGhpcy5vcHMoKS5nZXRTb3VyY2VzRm9yT3BlcmF0aW9uKCk7XHJcblx0XHRcdFx0aWYgKCFmaWxlcy5sZW5ndGgpIHJldHVybiBmYWxzZTtcclxuXHRcdFx0XHRpZiAoIWNoZWNraW5nKSB7XHJcblx0XHRcdFx0XHR0aGlzLmNsaXBib2FyZCA9IHRoaXMub3BzKCkuYnVpbGRDbGlwYm9hcmRNYXAoZmlsZXMpO1xyXG5cdFx0XHRcdFx0dGhpcy5tb2RlID0gXCJjb3B5XCI7XHJcblx0XHRcdFx0XHRuZXcgTm90aWNlKFwiQ29waWVkIChleHBsb3JlciBjbGlwYm9hcmQpXCIpO1xyXG5cdFx0XHRcdH1cclxuXHRcdFx0XHRyZXR1cm4gdHJ1ZTtcclxuXHRcdFx0fSxcclxuXHRcdH0pO1xyXG5cclxuXHRcdHRoaXMuYWRkQ29tbWFuZCh7XHJcblx0XHRcdGlkOiBcInBhc3RlXCIsXHJcblx0XHRcdG5hbWU6IFwiRXhwbG9yZXIgY2xpcGJvYXJkOiBQYXN0ZSBpbnRvIGZvbGRlclwiLFxyXG5cdFx0XHRjaGVja0NhbGxiYWNrOiAoY2hlY2tpbmcpID0+IHtcclxuXHRcdFx0XHRpZiAoIXRoaXMub3BzKCkuaXNFeHBsb3JlckFjdGl2ZSgpKSByZXR1cm4gZmFsc2U7XHJcblx0XHRcdFx0aWYgKCF0aGlzLm9wcygpLmhhc0FjdGl2ZVJvdygpKSByZXR1cm4gZmFsc2U7XHJcblx0XHRcdFx0aWYgKCF0aGlzLmNsaXBib2FyZD8uc2l6ZSkgcmV0dXJuIGZhbHNlO1xyXG5cdFx0XHRcdGlmICghY2hlY2tpbmcpIHtcclxuXHRcdFx0XHRcdHZvaWQgKGFzeW5jICgpID0+IHtcclxuXHRcdFx0XHRcdFx0Y29uc3QgY2xpcCA9IHRoaXMuY2xpcGJvYXJkITtcclxuXHRcdFx0XHRcdFx0Y29uc3QgbW9kZSA9IHRoaXMubW9kZTtcclxuXHRcdFx0XHRcdFx0YXdhaXQgcGFzdGVDbGlwYm9hcmQodGhpcy5hcHAsIGNsaXAsIG1vZGUpO1xyXG5cdFx0XHRcdFx0XHRpZiAobW9kZSA9PT0gXCJjdXRcIikgdGhpcy5jbGlwYm9hcmQgPSBudWxsO1xyXG5cdFx0XHRcdFx0fSkoKTtcclxuXHRcdFx0XHR9XHJcblx0XHRcdFx0cmV0dXJuIHRydWU7XHJcblx0XHRcdH0sXHJcblx0XHR9KTtcclxuXHR9XHJcbn1cclxuIiwgImltcG9ydCB7IEFwcCwgTm90aWNlLCBURm9sZGVyLCBURmlsZSwgVEFic3RyYWN0RmlsZSwgVmlldywgVmF1bHQgfSBmcm9tIFwib2JzaWRpYW5cIjtcclxuXHJcbi8qKiBDb3JlIGZpbGUgZXhwbG9yZXIgdmlldyAobm90IGEgcHVibGljIEFQSSBcdTIwMTQgbWF5IGJyZWFrIG9uIE9ic2lkaWFuIHVwZGF0ZXMpLiAqL1xyXG5jb25zdCBGSUxFX0VYUExPUkVSID0gXCJmaWxlLWV4cGxvcmVyXCI7XHJcblxyXG5pbnRlcmZhY2UgVHJlZUl0ZW0ge1xyXG5cdGZvY3VzZWRJdGVtPzogRmlsZVJvdztcclxuXHRzZWxlY3RlZERvbXM6IFNldDxGaWxlUm93PjtcclxufVxyXG5cclxuaW50ZXJmYWNlIEZpbGVSb3cge1xyXG5cdGZpbGU6IFRBYnN0cmFjdEZpbGU7XHJcbn1cclxuXHJcbmludGVyZmFjZSBGaWxlRXhwbG9yZXJWaWV3IGV4dGVuZHMgVmlldyB7XHJcblx0YWN0aXZlRG9tPzogRmlsZVJvdztcclxuXHRmaWxlSXRlbXM6IFJlY29yZDxzdHJpbmcsIEZpbGVSb3c+O1xyXG5cdHRyZWU6IFRyZWVJdGVtO1xyXG59XHJcblxyXG5leHBvcnQgdHlwZSBDbGlwYm9hcmRNb2RlID0gXCJjdXRcIiB8IFwiY29weVwiO1xyXG5cclxuZXhwb3J0IGNsYXNzIEV4cGxvcmVyT3BzIHtcclxuXHRjb25zdHJ1Y3Rvcihwcml2YXRlIHJlYWRvbmx5IGFwcDogQXBwKSB7fVxyXG5cclxuXHRnZXRFeHBsb3JlcigpOiBGaWxlRXhwbG9yZXJWaWV3IHwgbnVsbCB7XHJcblx0XHRjb25zdCBsZWF2ZXMgPSB0aGlzLmFwcC53b3Jrc3BhY2UuZ2V0TGVhdmVzT2ZUeXBlKEZJTEVfRVhQTE9SRVIpO1xyXG5cdFx0aWYgKCFsZWF2ZXMubGVuZ3RoKSByZXR1cm4gbnVsbDtcclxuXHRcdHJldHVybiBsZWF2ZXNbMF0udmlldyBhcyB1bmtub3duIGFzIEZpbGVFeHBsb3JlclZpZXc7XHJcblx0fVxyXG5cclxuXHRpc0V4cGxvcmVyQWN0aXZlKCk6IGJvb2xlYW4ge1xyXG5cdFx0Y29uc3QgdiA9IHRoaXMuYXBwLndvcmtzcGFjZS5nZXRBY3RpdmVWaWV3T2ZUeXBlKFZpZXcpO1xyXG5cdFx0cmV0dXJuIHY/LmdldFZpZXdUeXBlKCkgPT09IEZJTEVfRVhQTE9SRVI7XHJcblx0fVxyXG5cclxuXHRwcml2YXRlIGFjdGl2ZUZpbGVPckZvbGRlcigpOiBUQWJzdHJhY3RGaWxlIHwgbnVsbCB7XHJcblx0XHRjb25zdCBleCA9IHRoaXMuZ2V0RXhwbG9yZXIoKTtcclxuXHRcdGlmICghZXgpIHJldHVybiBudWxsO1xyXG5cdFx0cmV0dXJuIGV4LnRyZWUuZm9jdXNlZEl0ZW0/LmZpbGUgPz8gZXguYWN0aXZlRG9tPy5maWxlID8/IG51bGw7XHJcblx0fVxyXG5cclxuXHRoYXNBY3RpdmVSb3coKTogYm9vbGVhbiB7XHJcblx0XHRyZXR1cm4gdGhpcy5hY3RpdmVGaWxlT3JGb2xkZXIoKSAhPT0gbnVsbDtcclxuXHR9XHJcblxyXG5cdC8qKiBTZWxlY3RlZCByb3dzLCBvciB0aGUgZm9jdXNlZCByb3cgaWYgc2VsZWN0aW9uIGlzIGVtcHR5LiAqL1xyXG5cdGdldFNvdXJjZXNGb3JPcGVyYXRpb24oKTogVEFic3RyYWN0RmlsZVtdIHtcclxuXHRcdGNvbnN0IGV4ID0gdGhpcy5nZXRFeHBsb3JlcigpO1xyXG5cdFx0aWYgKCFleCkgcmV0dXJuIFtdO1xyXG5cdFx0aWYgKGV4LnRyZWUuc2VsZWN0ZWREb21zLnNpemUgPT09IDApIHtcclxuXHRcdFx0Y29uc3Qgb25lID0gdGhpcy5hY3RpdmVGaWxlT3JGb2xkZXIoKTtcclxuXHRcdFx0cmV0dXJuIG9uZSA/IFtvbmVdIDogW107XHJcblx0XHR9XHJcblx0XHRyZXR1cm4gWy4uLmV4LnRyZWUuc2VsZWN0ZWREb21zXS5tYXAoKHJvdykgPT4gcm93LmZpbGUpO1xyXG5cdH1cclxuXHJcblx0LyoqIE1hcCBzb3VyY2UgdmF1bHQgcGF0aCBcdTIxOTIgZGVzdGluYXRpb24gYmFzZW5hbWUgKHBydW5lIG5lc3RlZCBzZWxlY3Rpb25zKS4gKi9cclxuXHRidWlsZENsaXBib2FyZE1hcChmaWxlczogVEFic3RyYWN0RmlsZVtdKTogTWFwPHN0cmluZywgc3RyaW5nPiB7XHJcblx0XHRjb25zdCBwYXRocyA9IHBydW5lRGVzY2VuZGFudFBhdGhzKGZpbGVzLm1hcCgoZikgPT4gZi5wYXRoKSk7XHJcblx0XHRjb25zdCBtID0gbmV3IE1hcDxzdHJpbmcsIHN0cmluZz4oKTtcclxuXHRcdGZvciAoY29uc3QgcCBvZiBwYXRocykge1xyXG5cdFx0XHRjb25zdCBiYXNlID0gcC5zcGxpdChcIi9cIikucG9wKCk7XHJcblx0XHRcdGlmIChiYXNlKSBtLnNldChwLCBiYXNlKTtcclxuXHRcdH1cclxuXHRcdHJldHVybiBtO1xyXG5cdH1cclxuXHJcblx0LyoqIEZvbGRlciB0byByZWNlaXZlIHBhc3RlZCBpdGVtczogZm9jdXNlZCBmb2xkZXIsIG9yIHBhcmVudCBvZiBmb2N1c2VkIGZpbGUuICovXHJcblx0Z2V0UGFzdGVGb2xkZXIoKTogVEZvbGRlciB8IG51bGwge1xyXG5cdFx0Y29uc3QgZiA9IHRoaXMuYWN0aXZlRmlsZU9yRm9sZGVyKCk7XHJcblx0XHRpZiAoIWYpIHJldHVybiBudWxsO1xyXG5cdFx0aWYgKGYgaW5zdGFuY2VvZiBURm9sZGVyKSByZXR1cm4gZjtcclxuXHRcdHJldHVybiBmLnBhcmVudCBpbnN0YW5jZW9mIFRGb2xkZXIgPyBmLnBhcmVudCA6IG51bGw7XHJcblx0fVxyXG59XHJcblxyXG5mdW5jdGlvbiBwcnVuZURlc2NlbmRhbnRQYXRocyhwYXRoczogc3RyaW5nW10pOiBzdHJpbmdbXSB7XHJcblx0Y29uc3Qgc29ydGVkID0gWy4uLnBhdGhzXS5zb3J0KFxyXG5cdFx0KGEsIGIpID0+IGEuc3BsaXQoXCIvXCIpLmxlbmd0aCAtIGIuc3BsaXQoXCIvXCIpLmxlbmd0aFxyXG5cdCk7XHJcblx0Y29uc3Qga2VwdDogc3RyaW5nW10gPSBbXTtcclxuXHRmb3IgKGNvbnN0IHAgb2Ygc29ydGVkKSB7XHJcblx0XHRjb25zdCB1bmRlciA9IGtlcHQuc29tZSgoaykgPT4gcCA9PT0gayB8fCBwLnN0YXJ0c1dpdGgoayArIFwiL1wiKSk7XHJcblx0XHRpZiAoIXVuZGVyKSBrZXB0LnB1c2gocCk7XHJcblx0fVxyXG5cdHJldHVybiBrZXB0O1xyXG59XHJcblxyXG5mdW5jdGlvbiBqb2luVmF1bHQoZm9sZGVyUGF0aDogc3RyaW5nLCBuYW1lOiBzdHJpbmcpOiBzdHJpbmcge1xyXG5cdGlmICghZm9sZGVyUGF0aCkgcmV0dXJuIG5hbWU7XHJcblx0cmV0dXJuIGAke2ZvbGRlclBhdGh9LyR7bmFtZX1gO1xyXG59XHJcblxyXG5mdW5jdGlvbiBhZGRTdWZmaXhCZWZvcmVFeHRlbnNpb24ocGF0aDogc3RyaW5nLCBzdWZmaXg6IHN0cmluZyk6IHN0cmluZyB7XHJcblx0Y29uc3Qgc2xhc2ggPSBwYXRoLmxhc3RJbmRleE9mKFwiL1wiKTtcclxuXHRjb25zdCBkb3QgPSBwYXRoLmxhc3RJbmRleE9mKFwiLlwiKTtcclxuXHRpZiAoZG90ID4gc2xhc2gpIHtcclxuXHRcdHJldHVybiBgJHtwYXRoLnNsaWNlKDAsIGRvdCl9JHtzdWZmaXh9LiR7cGF0aC5zbGljZShkb3QgKyAxKX1gO1xyXG5cdH1cclxuXHRyZXR1cm4gcGF0aCArIHN1ZmZpeDtcclxufVxyXG5cclxuZnVuY3Rpb24gdW5pcXVlRGVzdFBhdGgoXHJcblx0dmF1bHQ6IFZhdWx0LFxyXG5cdGRlc2lyZWQ6IHN0cmluZyxcclxuXHRpc0ZpbGU6IGJvb2xlYW5cclxuKTogc3RyaW5nIHtcclxuXHRsZXQgY2FuZGlkYXRlID0gZGVzaXJlZDtcclxuXHRmb3IgKGxldCBpID0gMTsgdmF1bHQuZ2V0QWJzdHJhY3RGaWxlQnlQYXRoKGNhbmRpZGF0ZSk7IGkrKykge1xyXG5cdFx0Y2FuZGlkYXRlID0gaXNGaWxlXHJcblx0XHRcdD8gYWRkU3VmZml4QmVmb3JlRXh0ZW5zaW9uKGRlc2lyZWQsIGAgJHtpfWApXHJcblx0XHRcdDogYCR7ZGVzaXJlZH0gJHtpfWA7XHJcblx0fVxyXG5cdHJldHVybiBjYW5kaWRhdGU7XHJcbn1cclxuXHJcbmFzeW5jIGZ1bmN0aW9uIGNvcHlGb2xkZXJUcmVlKFxyXG5cdHZhdWx0OiBWYXVsdCxcclxuXHRmb2xkZXI6IFRGb2xkZXIsXHJcblx0ZGVzdFJvb3Q6IHN0cmluZ1xyXG4pOiBQcm9taXNlPHZvaWQ+IHtcclxuXHRpZiAoIXZhdWx0LmdldEFic3RyYWN0RmlsZUJ5UGF0aChkZXN0Um9vdCkpIHtcclxuXHRcdGF3YWl0IHZhdWx0LmNyZWF0ZUZvbGRlcihkZXN0Um9vdCk7XHJcblx0fVxyXG5cdGNvbnN0IGNoaWxkcmVuOiBUQWJzdHJhY3RGaWxlW10gPSBbXTtcclxuXHRWYXVsdC5yZWN1cnNlQ2hpbGRyZW4oZm9sZGVyLCAoYykgPT4ge1xyXG5cdFx0Y2hpbGRyZW4ucHVzaChjKTtcclxuXHR9KTtcclxuXHRjaGlsZHJlbi5zb3J0KFxyXG5cdFx0KGEsIGIpID0+IGEucGF0aC5zcGxpdChcIi9cIikubGVuZ3RoIC0gYi5wYXRoLnNwbGl0KFwiL1wiKS5sZW5ndGhcclxuXHQpO1xyXG5cdGZvciAoY29uc3QgY2hpbGQgb2YgY2hpbGRyZW4pIHtcclxuXHRcdGNvbnN0IHJlbCA9IGNoaWxkLnBhdGguc2xpY2UoZm9sZGVyLnBhdGgubGVuZ3RoKS5yZXBsYWNlKC9eXFwvLywgXCJcIik7XHJcblx0XHRjb25zdCBmdWxsRGVzdCA9IGpvaW5WYXVsdChkZXN0Um9vdCwgcmVsKTtcclxuXHRcdGlmIChjaGlsZCBpbnN0YW5jZW9mIFRGb2xkZXIpIHtcclxuXHRcdFx0aWYgKCF2YXVsdC5nZXRBYnN0cmFjdEZpbGVCeVBhdGgoZnVsbERlc3QpKSB7XHJcblx0XHRcdFx0YXdhaXQgdmF1bHQuY3JlYXRlRm9sZGVyKGZ1bGxEZXN0KTtcclxuXHRcdFx0fVxyXG5cdFx0fSBlbHNlIHtcclxuXHRcdFx0YXdhaXQgdmF1bHQuY29weShjaGlsZCwgZnVsbERlc3QpO1xyXG5cdFx0fVxyXG5cdH1cclxufVxyXG5cclxuZnVuY3Rpb24gaW52YWxpZE1vdmVJbnRvU2VsZihcclxuXHRzcmM6IFRBYnN0cmFjdEZpbGUsXHJcblx0ZGVzdERpclBhdGg6IHN0cmluZ1xyXG4pOiBib29sZWFuIHtcclxuXHRpZiAoIShzcmMgaW5zdGFuY2VvZiBURm9sZGVyKSkgcmV0dXJuIGZhbHNlO1xyXG5cdGNvbnN0IHMgPSBzcmMucGF0aDtcclxuXHRyZXR1cm4gZGVzdERpclBhdGggPT09IHMgfHwgZGVzdERpclBhdGguc3RhcnRzV2l0aChzICsgXCIvXCIpO1xyXG59XHJcblxyXG5leHBvcnQgYXN5bmMgZnVuY3Rpb24gcGFzdGVDbGlwYm9hcmQoXHJcblx0YXBwOiBBcHAsXHJcblx0Y2xpcGJvYXJkOiBNYXA8c3RyaW5nLCBzdHJpbmc+LFxyXG5cdG1vZGU6IENsaXBib2FyZE1vZGVcclxuKTogUHJvbWlzZTx2b2lkPiB7XHJcblx0Y29uc3Qgb3BzID0gbmV3IEV4cGxvcmVyT3BzKGFwcCk7XHJcblx0Y29uc3QgZGVzdEZvbGRlciA9IG9wcy5nZXRQYXN0ZUZvbGRlcigpO1xyXG5cdGlmICghZGVzdEZvbGRlcikge1xyXG5cdFx0bmV3IE5vdGljZShcIlNlbGVjdCBhIGZpbGUgb3IgZm9sZGVyIGluIHRoZSBmaWxlIGV4cGxvcmVyIGZpcnN0LlwiKTtcclxuXHRcdHJldHVybjtcclxuXHR9XHJcblx0aWYgKGNsaXBib2FyZC5zaXplID09PSAwKSB7XHJcblx0XHRuZXcgTm90aWNlKFwiTm90aGluZyBpbiB0aGUgZXhwbG9yZXIgY2xpcGJvYXJkLlwiKTtcclxuXHRcdHJldHVybjtcclxuXHR9XHJcblxyXG5cdGNvbnN0IGRlc3REaXJQYXRoID0gZGVzdEZvbGRlci5wYXRoO1xyXG5cdGNvbnN0IHZhdWx0ID0gYXBwLnZhdWx0O1xyXG5cdGNvbnN0IGZtID0gYXBwLmZpbGVNYW5hZ2VyO1xyXG5cclxuXHRmb3IgKGNvbnN0IFtzcmNQYXRoLCBiYXNlTmFtZV0gb2YgY2xpcGJvYXJkKSB7XHJcblx0XHRjb25zdCBzcmMgPSB2YXVsdC5nZXRBYnN0cmFjdEZpbGVCeVBhdGgoc3JjUGF0aCk7XHJcblx0XHRpZiAoIXNyYykge1xyXG5cdFx0XHRuZXcgTm90aWNlKGBNaXNzaW5nOiAke3NyY1BhdGh9YCk7XHJcblx0XHRcdGNvbnRpbnVlO1xyXG5cdFx0fVxyXG5cclxuXHRcdGlmIChtb2RlID09PSBcImN1dFwiICYmIGludmFsaWRNb3ZlSW50b1NlbGYoc3JjLCBkZXN0RGlyUGF0aCkpIHtcclxuXHRcdFx0bmV3IE5vdGljZShgQ2Fubm90IG1vdmUgYSBmb2xkZXIgaW50byBpdHNlbGY6ICR7YmFzZU5hbWV9YCk7XHJcblx0XHRcdGNvbnRpbnVlO1xyXG5cdFx0fVxyXG5cclxuXHRcdGxldCBkZXNpcmVkID0gam9pblZhdWx0KGRlc3REaXJQYXRoLCBiYXNlTmFtZSk7XHJcblx0XHRjb25zdCBpc0ZpbGUgPSBzcmMgaW5zdGFuY2VvZiBURmlsZTtcclxuXHRcdGlmICh2YXVsdC5nZXRBYnN0cmFjdEZpbGVCeVBhdGgoZGVzaXJlZCkpIHtcclxuXHRcdFx0ZGVzaXJlZCA9IHVuaXF1ZURlc3RQYXRoKHZhdWx0LCBkZXNpcmVkLCBpc0ZpbGUpO1xyXG5cdFx0fVxyXG5cclxuXHRcdGlmIChtb2RlID09PSBcImN1dFwiKSB7XHJcblx0XHRcdGlmIChzcmNQYXRoID09PSBkZXNpcmVkKSBjb250aW51ZTtcclxuXHRcdFx0YXdhaXQgZm0ucmVuYW1lRmlsZShzcmMsIGRlc2lyZWQpO1xyXG5cdFx0fSBlbHNlIGlmIChzcmMgaW5zdGFuY2VvZiBURmlsZSkge1xyXG5cdFx0XHRhd2FpdCB2YXVsdC5jb3B5KHNyYywgZGVzaXJlZCk7XHJcblx0XHR9IGVsc2Uge1xyXG5cdFx0XHRhd2FpdCBjb3B5Rm9sZGVyVHJlZSh2YXVsdCwgc3JjIGFzIFRGb2xkZXIsIGRlc2lyZWQpO1xyXG5cdFx0fVxyXG5cdH1cclxuXHJcblx0bmV3IE5vdGljZShtb2RlID09PSBcImN1dFwiID8gXCJNb3ZlZC5cIiA6IFwiUGFzdGVkLlwiKTtcclxufVxyXG4iXSwKICAibWFwcGluZ3MiOiAiOzs7Ozs7Ozs7Ozs7Ozs7Ozs7OztBQUFBO0FBQUE7QUFBQTtBQUFBO0FBQUE7QUFBQSxJQUFBQSxtQkFBK0I7OztBQ0EvQixzQkFBd0U7QUFHeEUsSUFBTSxnQkFBZ0I7QUFtQmYsSUFBTSxjQUFOLE1BQWtCO0FBQUEsRUFDeEIsWUFBNkIsS0FBVTtBQUFWO0FBQUEsRUFBVztBQUFBLEVBRXhDLGNBQXVDO0FBQ3RDLFVBQU0sU0FBUyxLQUFLLElBQUksVUFBVSxnQkFBZ0IsYUFBYTtBQUMvRCxRQUFJLENBQUMsT0FBTztBQUFRLGFBQU87QUFDM0IsV0FBTyxPQUFPLENBQUMsRUFBRTtBQUFBLEVBQ2xCO0FBQUEsRUFFQSxtQkFBNEI7QUFDM0IsVUFBTSxJQUFJLEtBQUssSUFBSSxVQUFVLG9CQUFvQixvQkFBSTtBQUNyRCxXQUFPLEdBQUcsWUFBWSxNQUFNO0FBQUEsRUFDN0I7QUFB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
