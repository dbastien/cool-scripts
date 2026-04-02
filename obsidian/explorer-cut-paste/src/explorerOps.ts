import { App, Notice, TFolder, TFile, TAbstractFile, View, Vault } from "obsidian";

/** Core file explorer view (not a public API — may break on Obsidian updates). */
const FILE_EXPLORER = "file-explorer";

interface TreeItem {
	focusedItem?: FileRow;
	selectedDoms: Set<FileRow>;
}

interface FileRow {
	file: TAbstractFile;
}

interface FileExplorerView extends View {
	activeDom?: FileRow;
	fileItems: Record<string, FileRow>;
	tree: TreeItem;
}

export type ClipboardMode = "cut" | "copy";

export class ExplorerOps {
	constructor(private readonly app: App) {}

	getExplorer(): FileExplorerView | null {
		const leaves = this.app.workspace.getLeavesOfType(FILE_EXPLORER);
		if (!leaves.length) return null;
		return leaves[0].view as unknown as FileExplorerView;
	}

	isExplorerActive(): boolean {
		const v = this.app.workspace.getActiveViewOfType(View);
		return v?.getViewType() === FILE_EXPLORER;
	}

	private activeFileOrFolder(): TAbstractFile | null {
		const ex = this.getExplorer();
		if (!ex) return null;
		return ex.tree.focusedItem?.file ?? ex.activeDom?.file ?? null;
	}

	hasActiveRow(): boolean {
		return this.activeFileOrFolder() !== null;
	}

	/** Selected rows, or the focused row if selection is empty. */
	getSourcesForOperation(): TAbstractFile[] {
		const ex = this.getExplorer();
		if (!ex) return [];
		if (ex.tree.selectedDoms.size === 0) {
			const one = this.activeFileOrFolder();
			return one ? [one] : [];
		}
		return [...ex.tree.selectedDoms].map((row) => row.file);
	}

	/** Map source vault path → destination basename (prune nested selections). */
	buildClipboardMap(files: TAbstractFile[]): Map<string, string> {
		const paths = pruneDescendantPaths(files.map((f) => f.path));
		const m = new Map<string, string>();
		for (const p of paths) {
			const base = p.split("/").pop();
			if (base) m.set(p, base);
		}
		return m;
	}

	/** Folder to receive pasted items: focused folder, or parent of focused file. */
	getPasteFolder(): TFolder | null {
		const f = this.activeFileOrFolder();
		if (!f) return null;
		if (f instanceof TFolder) return f;
		return f.parent instanceof TFolder ? f.parent : null;
	}
}

function pruneDescendantPaths(paths: string[]): string[] {
	const sorted = [...paths].sort(
		(a, b) => a.split("/").length - b.split("/").length
	);
	const kept: string[] = [];
	for (const p of sorted) {
		const under = kept.some((k) => p === k || p.startsWith(k + "/"));
		if (!under) kept.push(p);
	}
	return kept;
}

function joinVault(folderPath: string, name: string): string {
	if (!folderPath) return name;
	return `${folderPath}/${name}`;
}

function addSuffixBeforeExtension(path: string, suffix: string): string {
	const slash = path.lastIndexOf("/");
	const dot = path.lastIndexOf(".");
	if (dot > slash) {
		return `${path.slice(0, dot)}${suffix}.${path.slice(dot + 1)}`;
	}
	return path + suffix;
}

function uniqueDestPath(
	vault: Vault,
	desired: string,
	isFile: boolean
): string {
	let candidate = desired;
	for (let i = 1; vault.getAbstractFileByPath(candidate); i++) {
		candidate = isFile
			? addSuffixBeforeExtension(desired, ` ${i}`)
			: `${desired} ${i}`;
	}
	return candidate;
}

async function copyFolderTree(
	vault: Vault,
	folder: TFolder,
	destRoot: string
): Promise<void> {
	if (!vault.getAbstractFileByPath(destRoot)) {
		await vault.createFolder(destRoot);
	}
	const children: TAbstractFile[] = [];
	Vault.recurseChildren(folder, (c) => {
		children.push(c);
	});
	children.sort(
		(a, b) => a.path.split("/").length - b.path.split("/").length
	);
	for (const child of children) {
		const rel = child.path.slice(folder.path.length).replace(/^\//, "");
		const fullDest = joinVault(destRoot, rel);
		if (child instanceof TFolder) {
			if (!vault.getAbstractFileByPath(fullDest)) {
				await vault.createFolder(fullDest);
			}
		} else {
			await vault.copy(child, fullDest);
		}
	}
}

function invalidMoveIntoSelf(
	src: TAbstractFile,
	destDirPath: string
): boolean {
	if (!(src instanceof TFolder)) return false;
	const s = src.path;
	return destDirPath === s || destDirPath.startsWith(s + "/");
}

export async function pasteClipboard(
	app: App,
	clipboard: Map<string, string>,
	mode: ClipboardMode
): Promise<void> {
	const ops = new ExplorerOps(app);
	const destFolder = ops.getPasteFolder();
	if (!destFolder) {
		new Notice("Select a file or folder in the file explorer first.");
		return;
	}
	if (clipboard.size === 0) {
		new Notice("Nothing in the explorer clipboard.");
		return;
	}

	const destDirPath = destFolder.path;
	const vault = app.vault;
	const fm = app.fileManager;

	for (const [srcPath, baseName] of clipboard) {
		const src = vault.getAbstractFileByPath(srcPath);
		if (!src) {
			new Notice(`Missing: ${srcPath}`);
			continue;
		}

		if (mode === "cut" && invalidMoveIntoSelf(src, destDirPath)) {
			new Notice(`Cannot move a folder into itself: ${baseName}`);
			continue;
		}

		let desired = joinVault(destDirPath, baseName);
		const isFile = src instanceof TFile;
		if (vault.getAbstractFileByPath(desired)) {
			desired = uniqueDestPath(vault, desired, isFile);
		}

		if (mode === "cut") {
			if (srcPath === desired) continue;
			await fm.renameFile(src, desired);
		} else if (src instanceof TFile) {
			await vault.copy(src, desired);
		} else {
			await copyFolderTree(vault, src as TFolder, desired);
		}
	}

	new Notice(mode === "cut" ? "Moved." : "Pasted.");
}
