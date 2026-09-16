#!/usr/bin/env node
/**
 * Patch pi-coding-agent to pin the input prompt to the right side
 * in fullscreen TUI mode when the terminal is wider than the threshold.
 *
 * Modifies the bundled chunk and the source module in the globally-installed pi package.
 * Run after updating pi (e.g. `npm install -g pi-coding-agent`).
 */
const fs = require("fs");
const path = require("path");

const WIDE_THRESHOLD = 120;
const DOCK_MAX_WIDTH = 55;

const piModuleBase = path.resolve(
  require("os").homedir(),
  ".local/lib/node_modules/@earendil-works/pi-coding-agent"
);

const candidates = [
  path.join(piModuleBase, "dist/bundle/chunks/chunk-JVUZSMYM.js"),
  path.join(piModuleBase, "dist/modes/interactive/chat-viewport.js"),
];

// --- Readable source variant ---
const oldReadableStart = 'import { ScrollView, VStack } from "@earendil-works/pi-tui";\n/** Shared fullscreen transcript and fixed input-dock layout. */';
const oldReadableEnd = 'root: new VStack([\n            { component: transcript, basis: 0, grow: 1, shrink: 1, minSize: 1 },\n            { component: dock, basis: "auto", grow: 0, shrink: 1, minSize: 1 },\n        ]),\n    };\n}';

const newReadable = `import { HStack, ScrollView, VStack } from "@earendil-works/pi-tui";
/** Shared fullscreen transcript and fixed input-dock layout. */
export function createChatViewport(options) {
    const transcript = new ScrollView(options.document, {
        follow: "end",
        primary: true,
        overscroll: "chain",
        scrollbar: options.scrollbar ?? "auto",
        ...(options.scrollbarTrackStyle === undefined ? {} : { scrollbarTrackStyle: options.scrollbarTrackStyle }),
        ...(options.scrollbarThumbStyle === undefined ? {} : { scrollbarThumbStyle: options.scrollbarThumbStyle }),
    });
    const dock = new VStack([
        { component: options.pendingMessages, shrink: 1, minSize: 0 },
        { component: options.status, shrink: 1, minSize: 0 },
        ...(options.widgetsAbove === undefined ? [] : [{ component: options.widgetsAbove, shrink: 1, minSize: 0 }]),
        { component: options.editor, shrink: 1, minSize: 3 },
        ...(options.widgetsBelow === undefined ? [] : [{ component: options.widgetsBelow, shrink: 1, minSize: 0 }]),
        { component: options.footer, shrink: 1, minSize: 1 },
    ]);
    return {
        transcript,
        root: new VStack([
            {
                component: new VStack([
                    { component: transcript, basis: 0, grow: 1, shrink: 1, minSize: 1 },
                    { component: dock, basis: "auto", grow: 0, shrink: 1, minSize: 1 },
                ]),
                basis: 0,
                grow: 1,
                shrink: 1,
                minSize: 1,
                visible: (vp) => vp.width < ${WIDE_THRESHOLD},
            },
            {
                component: new HStack([
                    { component: transcript, basis: 0, grow: 1, shrink: 1, minSize: 30 },
                    { component: dock, basis: "auto", grow: 0, shrink: 1, minSize: 1, maxSize: ${DOCK_MAX_WIDTH} },
                ], { gap: 1 }),
                basis: 0,
                grow: 1,
                shrink: 1,
                minSize: 1,
                visible: (vp) => vp.width >= ${WIDE_THRESHOLD},
            },
        ]),
    };
}`;

let patched = false;
for (const file of candidates) {
  if (!fs.existsSync(file)) {
    console.warn(`Skip (not found): ${file}`);
    continue;
  }
  let js = fs.readFileSync(file, "utf-8");

  // --- Bundle variant (minified) ---
  // Try to patch the minified bundle by replacing the old nested VStack root with the new responsive V+H root.
  const oldBundlePattern = /function createChatViewport\(options\)\{let transcript=new ScrollView\(options\.document,\{follow:"end",primary:!0,overscroll:"chain",[^}]*\}\),dock=new VStack\(\[.*?\]\);return\{transcript,root:new VStack\(\[\{component:transcript,basis:0,grow:1,shrink:1,minSize:1\},\{component:dock,basis:"auto",grow:0,shrink:1,minSize:1\}\]\)\}\}/s;

  if (oldBundlePattern.test(js)) {
    const newMinified = `function createChatViewport(options){let transcript=new ScrollView(options.document,{follow:"end",primary:!0,overscroll:"chain",scrollbar:options.scrollbar??"auto",...options.scrollbarTrackStyle===void 0?{}:{scrollbarTrackStyle:options.scrollbarTrackStyle},...options.scrollbarThumbStyle===void 0?{}:{scrollbarThumbStyle:options.scrollbarThumbStyle}}),dock=new VStack([{component:options.pendingMessages,shrink:1,minSize:0},{component:options.status,shrink:1,minSize:0},...options.widgetsAbove===void 0?[]:[{component:options.widgetsAbove,shrink:1,minSize:0}],{component:options.editor,shrink:1,minSize:3},...options.widgetsBelow===void 0?[]:[{component:options.widgetsBelow,shrink:1,minSize:0}],{component:options.footer,shrink:1,minSize:1}]);return{transcript,root:new VStack([{component:new VStack([{component:transcript,basis:0,grow:1,shrink:1,minSize:1},{component:dock,basis:"auto",grow:0,shrink:1,minSize:1}]),basis:0,grow:1,shrink:1,minSize:1,visible:vp=>vp.width<${WIDE_THRESHOLD}},{component:new HStack([{component:transcript,basis:0,grow:1,shrink:1,minSize:30},{component:dock,basis:"auto",grow:0,shrink:1,minSize:1,maxSize:${DOCK_MAX_WIDTH}}],{gap:1}),basis:0,grow:1,shrink:1,minSize:1,visible:vp=>vp.width>=${WIDE_THRESHOLD}}])}}`;
    js = js.replace(oldBundlePattern, newMinified);
    fs.writeFileSync(file, js);
    console.log(`Patched (bundle): ${file}`);
    patched = true;
  } else if (js.includes(oldReadableStart) && js.includes(oldReadableEnd)) {
    // Readable source
    const idxStart = js.indexOf(oldReadableStart);
    const idxEnd = js.indexOf(oldReadableEnd) + oldReadableEnd.length;
    js = js.slice(0, idxStart) + newReadable + js.slice(idxEnd);
    fs.writeFileSync(file, js);
    console.log(`Patched (source): ${file}`);
    patched = true;
  } else if (js.includes(`maxSize:${DOCK_MAX_WIDTH}`) || js.includes(`maxSize: ${DOCK_MAX_WIDTH}`)) {
    console.log(`Already patched: ${file}`);
    patched = true;
  } else {
    console.warn(`Skip (text not found): ${file}`);
  }
}

if (!patched) {
  console.error("No pi file was patched. Is pi installed globally?");
  process.exit(1);
}
