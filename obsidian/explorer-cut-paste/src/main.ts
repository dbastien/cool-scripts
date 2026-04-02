import { Notice, Plugin } from "obsidian";
import { ExplorerOps, pasteClipboard, type ClipboardMode } from "./explorerOps";

export default class ExplorerCutPastePlugin extends Plugin {
	private clipboard: Map<string, string> | null = null;
	private mode: ClipboardMode = "copy";

	private ops(): ExplorerOps {
		return new ExplorerOps(this.app);
	}

	async onload(): Promise<void> {
		this.addCommand({
			id: "cut",
			name: "Explorer clipboard: Cut",
			checkCallback: (checking) => {
				if (!this.ops().isExplorerActive()) return false;
				const files = this.ops().getSourcesForOperation();
				if (!files.length) return false;
				if (!checking) {
					this.clipboard = this.ops().buildClipboardMap(files);
					this.mode = "cut";
					new Notice("Cut (explorer clipboard)");
				}
				return true;
			},
		});

		this.addCommand({
			id: "copy",
			name: "Explorer clipboard: Copy",
			checkCallback: (checking) => {
				if (!this.ops().isExplorerActive()) return false;
				const files = this.ops().getSourcesForOperation();
				if (!files.length) return false;
				if (!checking) {
					this.clipboard = this.ops().buildClipboardMap(files);
					this.mode = "copy";
					new Notice("Copied (explorer clipboard)");
				}
				return true;
			},
		});

		this.addCommand({
			id: "paste",
			name: "Explorer clipboard: Paste into folder",
			checkCallback: (checking) => {
				if (!this.ops().isExplorerActive()) return false;
				if (!this.ops().hasActiveRow()) return false;
				if (!this.clipboard?.size) return false;
				if (!checking) {
					void (async () => {
						const clip = this.clipboard!;
						const mode = this.mode;
						await pasteClipboard(this.app, clip, mode);
						if (mode === "cut") this.clipboard = null;
					})();
				}
				return true;
			},
		});
	}
}
