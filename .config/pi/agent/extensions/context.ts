/**
 * Context Extension
 *
 * Loads context files from ~/bin/contexts and injects them into the
 * conversation before the user's prompt.
 *
 * Usage:
 *   /context                        - Interactive multi-select + prompt
 *   /context name1,name2            - Pick contexts, then type prompt
 *   /context name1,name2 <prompt>   - Inline contexts + prompt
 */

import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { readdir, readFile } from "node:fs/promises";
import { join, basename } from "node:path";
import { matchesKey, Key, truncateToWidth } from "@earendil-works/pi-tui";

const CONTEXTS_DIR = "/home/mseller/bin/contexts";

async function getAvailableContexts(): Promise<string[]> {
	try {
		const files = await readdir(CONTEXTS_DIR);
		return files
			.filter((f) => f.endsWith(".md"))
			.map((f) => basename(f, ".md"))
			.sort();
	} catch {
		return [];
	}
}

async function readContext(name: string): Promise<string | null> {
	try {
		const content = await readFile(join(CONTEXTS_DIR, `${name}.md`), "utf-8");
		return `<context name="${name}">\n${content}\n</context>`;
	} catch {
		return null;
	}
}

function parseContextsAndPrompt(
	args: string,
	available: string[],
): { contexts: string[]; prompt: string } {
	const contexts: string[] = [];
	let prompt = "";

	if (!args.trim()) return { contexts, prompt };

	const segments = args.split(",");
	let promptStarted = false;

	for (let i = 0; i < segments.length; i++) {
		const segment = segments[i].trim();
		if (promptStarted) {
			prompt += (prompt ? ", " : "") + segment;
			continue;
		}

		const exact = available.find((n) => n === segment);
		if (exact) {
			contexts.push(exact);
			continue;
		}

		const sortedByLength = [...available].sort((a, b) => b.length - a.length);
		let matched = false;
		for (const name of sortedByLength) {
			if (segment === name) {
				contexts.push(name);
				matched = true;
				break;
			}
			if (segment.startsWith(name + " ")) {
				contexts.push(name);
				prompt = segment.slice(name.length).trim();
				promptStarted = true;
				matched = true;
				break;
			}
		}
		if (!matched) {
			prompt = segment;
			promptStarted = true;
		}
	}

	return { contexts, prompt };
}

export default function contextExtension(pi: ExtensionAPI) {
	pi.registerCommand("context", {
		description: "Load context files and send a prompt with them prepended. Usage: /context [name1,name2,...] [prompt]",
		getArgumentCompletions: async (prefix) => {
			const available = await getAvailableContexts();
			if (available.length === 0) return null;
			const lastSegment = prefix.split(",").pop()?.trim() ?? "";
			const filtered = available.filter((n) => n.startsWith(lastSegment));
			return filtered.map((n) => ({ value: n, label: n }));
		},

		handler: async (commandArgs, ctx) => {
			const args = commandArgs ?? "";
			const available = await getAvailableContexts();
			if (available.length === 0) {
				ctx.ui.notify(`No .md contexts found in ${CONTEXTS_DIR}`, "warning");
				return;
			}

			let contextNames: string[];
			let userPrompt: string;

			// Parse inline args
			const parsed = parseContextsAndPrompt(args, available);
			contextNames = parsed.contexts;
			userPrompt = parsed.prompt;

			// Interactive multi-select if no contexts specified inline
			if (contextNames.length === 0) {
				const result = await ctx.ui.custom<string[] | null>((tui, theme, _kb, done) => {
					let index = 0;
					const selected = new Set<string>();
					let cachedLines: string[] | undefined;
					let cachedWidth = -1;

					function refresh() {
						cachedLines = undefined;
						cachedWidth = -1;
						tui.requestRender();
					}

					return {
						render(width: number): string[] {
							if (cachedLines && cachedWidth === width) return cachedLines;

							const lines: string[] = [];

							// Title
							lines.push(truncateToWidth("  " + theme.fg("accent", "Select contexts"), width));
							lines.push(truncateToWidth(
								"  " + theme.fg("muted", `Available: ${available.join(", ")}`),
								width
							));
							lines.push("");

							// Checkbox list
							for (let i = 0; i < available.length; i++) {
								const name = available[i];
								const isSelected = selected.has(name);
								const isFocused = i === index;

								const checkbox = isSelected ? theme.fg("success", "[x]") : theme.fg("dim", "[ ]");
								const prefix = isFocused
									? theme.fg("accent", "> ")
									: "  ";
								const nameStyled = isFocused ? theme.fg("accent", name) : theme.fg("text", name);

								const line = `${prefix}${checkbox} ${nameStyled}`;
								lines.push(truncateToWidth(line, width));
							}

							// Footer
							lines.push("");
							const count = selected.size;
							lines.push(
								truncateToWidth(
									"  " +
									theme.fg("dim",
										`${count} selected · ↑↓/Ctrl+n/p navigate · space toggle · Enter confirm · Esc cancel`
									),
								width
								)
							);

							cachedLines = lines;
							cachedWidth = width;
							return lines;
						},

						invalidate(): void {
							cachedLines = undefined;
							cachedWidth = -1;
						},

						handleInput(data: string): void {
							if (matchesKey(data, Key.up) || matchesKey(data, Key.ctrl("p"))) {
								index = Math.max(0, index - 1);
								refresh();
							} else if (matchesKey(data, Key.down) || matchesKey(data, Key.ctrl("n"))) {
								index = Math.min(available.length - 1, index + 1);
								refresh();
							} else if (matchesKey(data, Key.space)) {
								const name = available[index];
								if (selected.has(name)) {
									selected.delete(name);
								} else {
									selected.add(name);
								}
								refresh();
							} else if (matchesKey(data, Key.enter)) {
								done(Array.from(selected));
							} else if (matchesKey(data, Key.escape)) {
								done(null);
							}
						},
					};
				});

				if (!result || result.length === 0) {
					if (result !== null) {
						ctx.ui.notify("No contexts selected.", "info");
					}
					return;
				}
				contextNames = result;
			}

			// Validate selected contexts
			const validNames = contextNames.filter((n) => available.includes(n));
			const invalid = contextNames.filter((n) => !available.includes(n));
			if (invalid.length > 0) {
				ctx.ui.notify(`Unknown context(s): ${invalid.join(", ")}`, "warning");
			}
			if (validNames.length === 0) {
				ctx.ui.notify("No valid contexts selected.", "error");
				return;
			}

			// Get prompt if not inline
			if (!userPrompt.trim()) {
				const editorPrompt = await ctx.ui.editor(`Prompt (contexts: ${validNames.join(", ")}):`);
				if (!editorPrompt?.trim()) {
					ctx.ui.notify("No prompt provided.", "info");
					return;
				}
				userPrompt = editorPrompt;
			}

			// Read context files
			const parts: string[] = [];
			for (const name of validNames) {
				const content = await readContext(name);
				if (content) parts.push(content);
			}

			if (parts.length === 0) {
				ctx.ui.notify("Failed to read context files.", "error");
				return;
			}

			// Build combined message
			const combined = [
				"The following context files have been loaded. Please consider them when responding.",
				"",
				...parts,
				"",
				"--- User Request ---",
				userPrompt,
			].join("\n");

			ctx.ui.notify(`Loaded contexts: ${validNames.join(", ")}. Sending prompt...`, "info");
			pi.sendUserMessage(combined);
			// Defer adding to history so it goes in AFTER the "/context" command
			// that the editor already added via the normal submit flow.
			await new Promise((r) => setTimeout(r, 0));
			(ctx.ui as any).addToHistory?.(combined);
		},
	});
}
