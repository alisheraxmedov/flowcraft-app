# FlowCraft

**Local-first whiteboard and diagramming desktop app for macOS, Windows and Linux, with a built-in MCP server — so AI coding agents can read your repo and draw its architecture diagram live on an infinite canvas.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Built%20with-Flutter-02569B.svg)](https://flutter.dev)
[![Dart SDK](https://img.shields.io/badge/Dart%20SDK-%5E3.10.8-0175C2.svg)](https://dart.dev)
[![Platforms](https://img.shields.io/badge/Platforms-macOS%20%7C%20Windows%20%7C%20Linux-lightgrey.svg)](#install)
[![MCP](https://img.shields.io/badge/MCP-Streamable%20HTTP-6E56CF.svg)](#connect-your-ai-agent)

---

FlowCraft is a free, open-source **whiteboard and diagramming desktop app** for **macOS, Windows and Linux**, built with Flutter. It gives you an infinite canvas with a hand-drawn, sketchy rendering style — shapes, arrows, sticky notes, freehand strokes and text — plus a **built-in MCP (Model Context Protocol) server**, so AI coding agents such as **Claude Code, Codex CLI, Gemini CLI and Claude Desktop** can analyse your codebase and draw its **architecture diagram** straight onto the running canvas.

The MCP server is part of the app: there is no second binary to install, no account to create, and no cloud service in the loop. It binds to `127.0.0.1` only, authenticates every request with a token stored on your machine, and works with the network switched off. Your code and your diagrams stay local.

FlowCraft is also a perfectly ordinary whiteboard. If you never connect an AI agent, it is still an offline sketching app with saved projects, autosave, undo/redo and PNG/SVG/JSON export.

---

## Contents

- [Install](#install)
- [Connect your AI agent](#connect-your-ai-agent)
- [Ask your agent to draw](#ask-your-agent-to-draw)
- [MCP tool reference](#mcp-tool-reference)
- [Features](#features)
- [Keyboard shortcuts](#keyboard-shortcuts)
- [Projects, autosave and export](#projects-autosave-and-export)
- [FAQ](#faq)
- [How FlowCraft compares](#how-flowcraft-compares)
- [Security and privacy](#security-and-privacy)
- [Roadmap](#roadmap)
- [Architecture](#architecture)
- [Build from source](#build-from-source)
- [Contributing](#contributing)
- [License](#license)

---

## Install

Download the installer for your platform from the
[**latest release**](https://github.com/alisheraxmedov/flowcraft-app/releases/latest):

| Platform | File | Minimum OS |
| --- | --- | --- |
| macOS (Apple Silicon and Intel) | `FlowCraft-macOS-<version>.dmg` | macOS 10.15 Catalina |
| Windows (x64) | `FlowCraft-Windows-Setup-<version>.exe` | Windows 10 |
| Linux (Debian / Ubuntu, x64) | `flowcraft_<version>_amd64.deb` | Ubuntu 22.04 or any distro with GTK 3 |

FlowCraft is free software built by one person, and the binaries are **not signed with a
paid Apple or Microsoft certificate**. Both operating systems will object the first time you
open it. This is expected; here is how to get past it.

**macOS.** Open the `.dmg` and drag **flowcraft** into **Applications**. The first launch will
say *"Apple could not verify 'flowcraft' is free of malware"* and offer only **Done**. Click
Done, then open **System Settings → Privacy & Security**, scroll to the *Security* section and
click **Open Anyway** next to the FlowCraft message, then confirm. You only do this once. If
you prefer the terminal:

```bash
xattr -d com.apple.quarantine /Applications/flowcraft.app
```

On macOS 13 and earlier, Control-click the app → **Open** → **Open** does the same thing.

**Windows.** SmartScreen shows *"Windows protected your PC"*. Click **More info**, then
**Run anyway**. The installer offers an install-for-me-only option that needs no administrator
password.

**Linux.** `sudo apt install ./flowcraft_<version>_amd64.deb` (this also pulls in GTK 3 if
it is missing). It installs to `/usr/lib/flowcraft` with a `flowcraft` launcher on your PATH
and an entry in your application menu.

Every release is built from a tagged commit by the public
[GitHub Actions workflow](.github/workflows/build-desktop.yml); you can compare the checksum
of what you downloaded against the build log, or [build it yourself](#build-from-source).
Code signing and notarization are on the [roadmap](#roadmap).

---

## Connect your AI agent

**The MCP server is the app.** It starts with FlowCraft and serves a spec-compliant MCP endpoint
over the **Streamable HTTP** transport at:

```
http://127.0.0.1:5199/mcp
```

The **Agents** chip in the top-right corner of the window shows the live status; click it to open
the Agents popover, which has the **MCP Server** switch, the endpoint, a **Copy connect** button and
a **Setup** dialog with ready-made config for each CLI (one tab each) — all with the real port and
token already filled in. The switch turns the server off if you would rather it not listen; the
endpoint, **Copy connect** and **Setup** only appear while it is running.

Every request must carry the app's auth token, which FlowCraft writes to `~/.flowcraft/control.token`
on first start. In the snippets below, replace `<your-token>` with that value (or just use the
Agents popover's **Copy connect** / **Setup** buttons, which paste it for you).

### Claude Code

```bash
claude mcp add --transport http flowcraft http://127.0.0.1:5199/mcp \
  --header "X-Flowcraft-Token: <your-token>"
```

### Claude Code / Claude Desktop — JSON

For `.mcp.json` or `claude_desktop_config.json`:

```json
{
  "mcpServers": {
    "flowcraft": {
      "type": "http",
      "url": "http://127.0.0.1:5199/mcp",
      "headers": { "X-Flowcraft-Token": "<your-token>" }
    }
  }
}
```

### Codex CLI — TOML

In `~/.codex/config.toml`:

```toml
[mcp_servers.flowcraft]
url = "http://127.0.0.1:5199/mcp"

[mcp_servers.flowcraft.http_headers]
"X-Flowcraft-Token" = "<your-token>"
```

### Gemini CLI — JSON

In `~/.gemini/settings.json`. Gemini CLI keys Streamable HTTP servers off `httpUrl`; plain `url`
selects its older SSE transport, which this server does not speak:

```json
{
  "mcpServers": {
    "flowcraft": {
      "httpUrl": "http://127.0.0.1:5199/mcp",
      "headers": { "X-Flowcraft-Token": "<your-token>" }
    }
  }
}
```

Field names occasionally change between CLI versions — check your CLI's own MCP documentation if a
snippet is rejected. Keep the token out of shared repositories: anything holding it can draw on
your canvas.

### If the Agents chip shows an error

Something else already holds port `5199` — usually a FlowCraft window you forgot was open. The port
is deliberately fixed rather than falling back to a random free one: the config you saved in your
CLI has to keep working across restarts, and a port that silently changed every launch would break
it without ever saying so. Close the other instance and press **Retry** in the Agents popover, which shows the reason.

---

## Ask your agent to draw

Once the server is registered, talk to your agent normally. These prompts work with the tools
FlowCraft actually exposes today:

> Study the `lib/services/` folder and draw a box-and-arrow diagram on FlowCraft showing how an
> MCP request reaches the canvas.

> Analyse this repository's top-level structure and draw its architecture on FlowCraft — one
> rectangle per layer, arrows for dependencies, and a text label above each group.

> Clear the FlowCraft canvas, then draw the class model for `models/sketch_element.dart`: a
> rectangle per class with the class name inside, and arrows pointing from each subclass to its
> base class.

> On FlowCraft, sketch a three-column board with sticky notes for this week's tasks — one column
> per status, a text heading above each column.

**Let FlowCraft do the layout.** For anything that is boxes and arrows, ask for `flowcraft_diagram`:
the agent sends nodes and edges, no coordinates, and FlowCraft ranks, orders and spaces them and
binds each arrow to its boxes.

```json
{
  "direction": "LR",
  "nodes": [
    { "id": "app", "label": "App" },
    { "id": "mcp", "label": "MCP server" },
    { "id": "db", "label": "Projects", "shape": "ellipse" }
  ],
  "edges": [ { "from": "app", "to": "mcp" }, { "from": "mcp", "to": "db" } ],
  "frames": [ { "name": "Backend", "members": ["mcp", "db"] } ]
}
```

Or hand it text you already have. `flowcraft_import` takes Mermaid, DBML or an Excalidraw scene and
lays it out the same way:

```json
{ "text": "flowchart LR\n  a[Client] --> b{Auth?}\n  b --> c((DB))\n  subgraph Backend\n    b\n    c\n  end" }
```

**Getting better results.** Use `flowcraft_diagram` or `flowcraft_import` for graphs and
`flowcraft_draw` only when you need exact coordinates. With `flowcraft_draw` the agent chooses the
coordinates itself, and models are famously bad at spatial packing, so give it a budget: *"use
260×120 boxes with at least 80px of space between them."* Ask it to call `flowcraft_screenshot`
after drawing to look at its own work, and to fix single elements with `flowcraft_update` rather
than clearing and redrawing. `flowcraft_guide` hands the agent the house conventions in one call.
The view scrolls to whatever the agent just drew, and the strokes animate in (the Agents popover
has an *Animate agent drawing* switch).

---

## MCP tool reference

FlowCraft exposes thirteen tools:

| Tool | Arguments | What it does |
| --- | --- | --- |
| `flowcraft_status` | none | Confirms the app is running and reachable, and reports how many elements are on the canvas. |
| `flowcraft_read` | `{ ids?, types?, frame?, region?, limit?, offset?, includeImageData? }` | Returns elements with their `id`, `type`, geometry, text and colours — the same field names `flowcraft_draw` accepts. Filter by `ids`, `types`, a `frame` (id or name, returns the frame and what is inside it) or a `region` `{x, y, width, height}`. Paged: `limit` 1–2000 (default 500) and `offset`; the reply carries `count`, `total`, `offset`, `limit` and, when more remain, `nextOffset`. Image bytes are left out (only their size is reported) unless `includeImageData` is true. Call it before editing so `flowcraft_update`/`flowcraft_delete` can target elements by `id`. |
| `flowcraft_draw` | `{ mode?: "add" \| "replace", elements: [...] }` | Draws elements at explicit coordinates. `add` (the default) appends; `replace` clears the canvas first. Any unrecognised mode is treated as `add`, so a typo can never wipe your work. The reply lists the new element ids, in order. |
| `flowcraft_diagram` | `{ nodes, edges?, frames?, direction?, connectors?, mode? }` | Lays out a graph for you. See below. |
| `flowcraft_import` | `{ text, format?, mode?, direction?, connectors? }` | Imports Mermaid, DBML, an Excalidraw scene or a FlowCraft JSON scene. See below. |
| `flowcraft_update` | `{ elements: [{ id, ...fields }] }` | Edits existing elements in place, each addressed by its `id`. Only the fields you include change; everything else, and every other element, is left untouched. An element's `type` cannot be changed this way. |
| `flowcraft_delete` | `{ ids: [string] }` | Removes specific elements by `id`, leaving the rest in place. |
| `flowcraft_clear` | none | Removes every element from the canvas. |
| `flowcraft_screenshot` | `{ ids?, types?, frame?, region?, maxSide? }` | Returns a PNG image of the canvas, or of just the matching elements, so the agent can check its own drawing. `maxSide` is the longest side in pixels (64–8192, default 1568). Fails when nothing matches. |
| `flowcraft_export` | `{ format, path?, ids?, types?, frame?, region?, overwrite?, pixelRatio?, background? }` | Exports the canvas, or a selection, as `png`, `svg` or `json`. Without `path` the result comes back inline (PNG as an image, SVG/JSON as text). With `path` it is written to disk: an absolute path (or `~/…`) whose extension matches the format, in an existing folder. An existing file needs `overwrite: true`, and `~/.flowcraft` is off limits. `pixelRatio` is 0.25–4 (default 2, PNG only). |
| `flowcraft_guide` | `{ topic?: "all" \| "tools" \| "vocabulary" \| "layout" \| "style" \| "examples" }` | Returns the drawing guide: every tool, the element vocabulary, layout and colour conventions, and examples. |
| `flowcraft_checkpoint` | `{ action: "list" \| "create" \| "restore", id?, label? }` | Canvas snapshots. One is taken automatically before every tool that changes the canvas; the last 20 are kept, in memory only (they are gone when the app quits). `restore` brings a scene back as a single undo step in the app, and only in the project the checkpoint was taken in. |
| `flowcraft_project` | `{ action, id?, name?, path? }` | Manages saved whiteboards: `list`, `current`, `open` (by `id` or unique `name`), `create` (with a `name`), `rename`, and `link` / `unlink` (see [Projects](#projects-autosave-and-export)). Switching saves the outgoing project first. |

Every tool that changes the canvas is one undo step in the app, however many elements it touched.

**`flowcraft_diagram`** takes `nodes` (`id`, optional `label`, `shape` of `rectangle`, `ellipse`,
`diamond` or `triangle`, `fillColor`, `strokeColor`, and `attributes` to make the node an ER table),
`edges` (`from`, `to`, optional `strokeColor`, and the ER fields `fromCardinality`, `toCardinality`,
`fromAttribute`, `toAttribute`), `frames` (`name` and the `members` node ids it wraps), `direction`
(`TB` default, `LR`, `BT`, `RL`), `connectors` (`straight` default, or `elbow`) and `mode` (`add`
places the graph to the right of existing content, `replace` clears first). Edges have no labels.
Arrows are bound to their boxes, so they follow when a box is moved. The reply maps your node ids
to element ids, and lists the edge and frame ids, `count` and `bounds`.

**`flowcraft_import`** takes `text` and a `format` of `auto` (the default, detected from the text),
`mermaid`, `dbml`, `excalidraw` or `json`. Mermaid and DBML are laid out like `flowcraft_diagram`
(`direction` and `connectors` override the defaults); `mode` is `add` or `replace`. A syntax error is
reported with its line number and leaves the canvas untouched. The reply gives the new ids and how
many source elements were dropped as unsupported.

Each entry in a `flowcraft_draw` `elements` array is an object with a required `type` and the
fields that type uses; a `flowcraft_update` entry uses the same fields but is keyed by `id` instead
of `type`:

| `type` | Fields |
| --- | --- |
| `rectangle`, `ellipse`, `diamond`, `triangle`, `sticky` | `x`, `y`, `width`, `height`, `text`, `fontSize`, `fontFamily`, `bold`, `strokeColor`, `fillColor` |
| `text` | `x`, `y`, `text` (required), `fontSize`, `fontFamily`, `bold`, `align`, `strokeColor` |
| `arrow`, `line` | `fromX`, `fromY`, `toX`, `toY`, `strokeColor`; arrows also `fromId`, `toId`, `elbow`, `startHead`, `endHead`, `fromAttribute`, `toAttribute` |
| `frame` | `x`, `y`, `width`, `height`, `name` |
| `icon` | `x`, `y`, `width`, `height`, `name` — one of `database`, `server`, `cloud`, `user`, `queue`, `lock`, `api`, `storage`, `cache`, `function`, `web`, `mobile`, `mail`, `schedule`, `warning`, `key`, `file`, `folder`, `globe`, `gear`, `bug`, `chart`, `robot`, `terminal` |
| `image` | `x`, `y`, `path` (absolute or `~/…`, `.png` `.jpg` `.jpeg` `.webp` `.gif`) or `dataUrl`, optional `width`/`height`; at most 4 MiB |
| `entity` | `x`, `y`, `width`, `name`, `attributes: [{ name, type, pk, fk }]` — height follows the rows |

`fromId`/`toId` attach an arrow end to an existing rectangle, ellipse, diamond, triangle or sticky
(ids come from `flowcraft_read`, a `flowcraft_draw` reply or the `flowcraft_diagram` key map): the
tip snaps to the outline and follows the shape when it moves; `""` detaches. They override
`fromX`/`fromY`/`toX`/`toY` for that end. Shapes created in the same `flowcraft_draw` call cannot be
referenced — use `flowcraft_diagram` for that. `startHead`/`endHead` are `none`, `arrow`, `one`,
`many`, `zeroOrOne`, `zeroOrMany` or `oneOrMany` (crow's-foot ends); with `fromAttribute` or
`toAttribute` naming an entity row, the arrow end attaches to that row. `fontFamily` is `sans`
(Inter, the default) or `mono` (JetBrains Mono); `align` is `left`, `center` or `right` and applies
to `text` elements only (shape labels stay centred). Entities, icons and frames are listed by
`flowcraft_read` with the same fields.

Coordinates are canvas-space pixels. Colours are hex strings such as `"#1E1E1E"` (`RRGGBB` is
expanded to opaque, `AARRGGBB` is accepted too). Bounded shapes default to 160×80 when no size is given. Arrows and lines
carry no label of their own — place a separate `text` element beside one if you need a caption.

The endpoint supports MCP protocol revisions `2025-06-18`, `2025-03-26` and `2024-11-05`, accepts
`POST` and `DELETE`, replies with plain `application/json` (the spec-permitted alternative to an
SSE stream), and accepts the token either as an `X-Flowcraft-Token` header or as
`Authorization: Bearer`.

---

## Features

**Canvas**

- Infinite canvas with pan, pinch-zoom and mouse-wheel zoom, from 0.1× to 4×.
- Toggleable dot grid background.
- Sketchy, hand-drawn rendering with a roughness dial — 0 for clean geometry, 2 for very rough.

**Tools**

- Select, hand (pan), rectangle, ellipse, diamond, triangle, sticky note, line, arrow, freehand,
  text, frame, icon, eraser.
- **Frames** (`F`): a named container drawn behind what it wraps. Membership is containment —
  whatever lies wholly inside a frame belongs to it, and dragging the frame moves its contents.
- **Icon library** (`I`): 24 built-in glyphs (database, server, cloud, user, queue, …) chosen from
  a grid on the tool pill.
- **Images**: **Export › Insert image from file…** (`Cmd`+`Shift`+`I`) embeds a PNG, JPEG, WebP or GIF
  by path, up to 4 MiB each and 16 MiB per scene. See the [FAQ](#faq) for why there is no
  paste or drag-and-drop.
- **ER diagrams**: entity tables with typed attribute rows and PK/FK tags, crow's-foot
  cardinality ends (one, many, zero-or-one, zero-or-many, one-or-many), and relationship arrows
  that attach to a specific row.
- **Elbow arrows**: a per-arrow switch that routes with right-angle bends.
- Text as a centred label inside any shape or sticky note, or as free-floating text, edited inline
  on the canvas. Sans (Inter) or mono (JetBrains Mono), bold, and left/centre/right alignment for
  free text.
- **Arrows that stay attached.** An arrow drawn or dragged onto a rectangle, ellipse, diamond,
  triangle or sticky note binds to it; move or resize the shape and the arrow re-anchors on its
  outline. Straight arrows only re-anchor — they do not route around obstacles. Hold `Cmd`/`Ctrl`
  while drawing or dropping an endpoint to leave it unattached.

**Styling**

- Stroke colour, fill colour, stroke width, opacity.
- Stroke patterns: solid, dashed, dotted.
- Fill patterns: none, solid, hachure, cross-hatch.
- Styling lives in the **Inspector** island on the left. Every control applies to the whole current
  selection as a **single undo entry**, and the Inspector reflects the selection (with a neutral
  indicator when a multi-selection disagrees). With a drawing tool active and nothing selected, it
  styles the next shape you draw instead.

**Editing**

- Click, `Shift`-click and marquee to select; drag to move; eight resize handles on bounded shapes,
  with `Shift` to keep the aspect ratio; draggable endpoints on lines and arrows.
- Group and ungroup — clicking one member selects the whole group.
- Copy, cut, paste and duplicate through the system clipboard, so it works between two FlowCraft
  windows. Z-order: bring forward, send backward, bring to front, send to back.
- Snapping to the grid and to other elements' edges and centres, with a guide line showing why, and
  `Alt` to place something freely.
- **Zoom to fit** (`Shift`+`1`, or **Edit › Align & view › Zoom to fit**), and the view re-frames onto whatever an
  agent has just drawn if it landed off-screen.
- **Align and distribute** a multi-selection from the **Edit** menu's *Align & view* submenu or the keyboard: align edges
  or centres, and space three or more items evenly.
- Snapshot-based undo/redo, 50 steps deep by default. One continuous drag is one undo entry.
- Light and dark themes (light by default), toggled from the bottom-right island, which also holds
  Undo, Redo and the grid switch.

**Files**

- Saved projects with autosave (see [below](#projects-autosave-and-export)).
- Export to PNG, SVG or JSON, copy the JSON to the clipboard, and import a scene back from a file or
  from pasted JSON, Excalidraw, Mermaid or DBML.
- **Link a board to a file in your repo** (a `.flowcraft` or `.json` file), so the diagram is
  versioned with the code that it describes.

**For agents**

- **Automatic layout** (`flowcraft_diagram`): send nodes and edges, not coordinates.
- **Import Mermaid** (flowchart and `erDiagram`), **DBML** and **Excalidraw** scenes.
- **See and verify**: `flowcraft_screenshot` returns a PNG of the canvas, and `flowcraft_export`
  writes PNG, SVG or JSON inline or to a path.
- **Checkpoints** before every canvas-changing tool call, restorable as one undo step.
- **Live draw animation**: agent drawings draw themselves on, with a switch in the Agents popover.

**Under the hood**

- **Zero Flutter plugins.** No third-party native code in the app bundle. Everything platform-facing
  goes through `dart:io` behind conditional-import boundaries.
- MVVM with [Riverpod](https://riverpod.dev): canvas state, theme, projects and the MCP server each
  sit behind their own view model.
- The MCP protocol is hand-rolled on `dart:io` + `dart:convert` — no MCP SDK dependency.

---

## Keyboard shortcuts

`Cmd` on macOS, `Ctrl` everywhere else. Press `?` in the app for the same table, always generated
from the live bindings so it cannot drift.

**Tools** — the same single letters Excalidraw uses, so muscle memory carries over:

| Key | Tool | Key | Tool |
| --- | --- | --- | --- |
| `V` | Select | `L` | Line |
| `H` | Hand (pan) | `A` | Arrow |
| `R` | Rectangle | `P` | Freehand draw |
| `O` | Ellipse | `T` | Text |
| `D` | Diamond | `E` | Eraser |
| `G` | Triangle | `N` | Sticky note |
| `F` | Frame | `I` | Icon |

**Edit, history and arrange:**

| Shortcut | Action |
| --- | --- |
| `Cmd`+`C` / `Cmd`+`X` / `Cmd`+`V` | Copy / cut / paste — via the system clipboard, so it works between two FlowCraft windows |
| `Cmd`+`Shift`+`I` | Insert image from file… |
| `Cmd`+`D` | Duplicate the selection |
| `Cmd`+`A` | Select all |
| `Delete` / `Backspace` | Delete the selection |
| `Esc` | Clear the selection |
| `Cmd`+`Z` / `Cmd`+`Shift`+`Z` / `Ctrl`+`Y` | Undo / redo |
| `Cmd`+`]` / `Cmd`+`[` | Bring forward / send backward |
| `Cmd`+`Shift`+`]` / `Cmd`+`Shift`+`[` | Bring to front / send to back |
| `Cmd`+`G` / `Cmd`+`Shift`+`G` | Group / ungroup |
| `Cmd`+`Shift`+`←` / `→` / `↑` / `↓` | Align left / right / top / bottom |
| `Alt`+`H` / `Alt`+`V` | Center horizontally / vertically |
| `Alt`+`Shift`+`H` / `Alt`+`Shift`+`V` | Distribute horizontally / vertically (three or more items) |
| `Shift`+`1` | Zoom to fit |
| Arrow keys | Nudge the selection 1px (`Shift` for 10px) |
| `?` | Shortcut reference |

Everything here except Undo and Redo is also reachable from the top bar's **Edit** menu (Insert image
from file… lives in the **Export** menu), which shows each binding beside its command; Undo and Redo live in the bottom-right island (the shortcuts work
everywhere). **Clear canvas** is in the Edit menu's *Canvas* group and shows an Undo snackbar.

**On the canvas:** `Shift`-click adds to or removes from the selection, and `Shift`-drag extends a
marquee instead of replacing it. Clicking any member of a group selects the whole group. Moves,
resizes and endpoint drags snap to the grid and to other elements' edges and centres, with a guide
line showing why — hold `Alt` to place something freely. Hold `Cmd`/`Ctrl` while drawing an arrow
or dropping one of its endpoints to leave that end unattached to any shape.

---

## Projects, autosave and export

Every whiteboard is a named project. The project name in the top-left island opens the Projects popover —
**new**, rename, delete, and switch. The canvas swaps instantly and the outgoing project is
flushed to disk on the way out. The open project's name sits beside the logo and is click-to-rename.
Nothing needs saving manually; edits are written behind you as you draw, and again when the app
exits.

Projects live in `~/.flowcraft/projects/`, one JSON file each, written atomically (temp file +
rename). The `index.json` beside them is only a cache that makes the Projects popover fast — if it is lost or
corrupt it is rebuilt by scanning the scene files themselves, so a bad index can never cost you a
whiteboard.

The **Export** button offers four destinations:

| Choice | Result |
| --- | --- |
| PNG | The whole scene — not just the visible viewport — at 2×, with a padded margin, capped at 8192px on the longest side. |
| SVG | The whole scene as a vector file that keeps the hand-drawn strokes (they are sampled from the very paths the canvas draws). Text references the Inter and JetBrains Mono typefaces by name, so a machine without them substitutes another font; icons are embedded as raster images. |
| JSON | The versioned `SketchSerializer` format: re-importable and diff-able. |
| Clipboard | The same JSON, straight to the clipboard. |

Files land in `~/Documents/FlowCraft/`, timestamped so a second export never silently overwrites
the first, and the confirmation offers **Reveal** to open the containing folder. There is no native
save dialog on purpose: the app ships with zero Flutter plugins, and a file-picker plugin would end
that.

The same menu **imports** a scene back: pick one of your exports from a list of
`~/Documents/FlowCraft/`, or type a path to a `.flowcraft.json` someone sent you, or paste the JSON
directly — JSON, an Excalidraw scene, Mermaid (flowchart and `erDiagram`) or DBML, detected from the
text. Either add it to the current canvas or replace the canvas with it. Loading is tolerant —
an element FlowCraft cannot read is skipped rather than failing the whole file, and you are told how
many were dropped instead of finding out later.

**Linking a board to a file.** A project row's **…** menu in the Projects popover has **Link to file…**: type an
absolute path ending in `.flowcraft` or `.json`, for example inside a repository. From then on every
save also writes the same scene to that file, so it can be committed. When the file is newer than
the project (you pulled, or edited it elsewhere), the file wins the next time the project loads.
If the path already holds a FlowCraft scene, FlowCraft **adopts** it — your board is replaced by
the file's contents and the file is never overwritten; any other existing file is refused. **Unlink
file** stops the mirroring and leaves the file where it is. An agent can do the same with
`flowcraft_project` actions `link` and `unlink`.

That tolerance extends to your saved projects, with a guard attached: if a project file loads with
elements missing, a banner says so and **autosave stops**, so the reduced scene can never overwrite
the original on disk. Nothing is written again until you accept the loss.

---

## FAQ

### What is FlowCraft?

FlowCraft is an open-source whiteboard and diagramming desktop app for macOS, Windows and Linux. It
combines an infinite canvas with hand-drawn-style rendering and a built-in MCP server, which lets AI
coding agents draw diagrams onto the live canvas while it is running. It is written in Flutter and
runs entirely on your own machine.

### How is FlowCraft different from a cloud whiteboard?

There is no server, no account and no sign-up. FlowCraft is a native desktop application; your
whiteboards are JSON files in your home directory, and the AI integration is a local HTTP endpoint
bound to `127.0.0.1` rather than a hosted API. That also means no real-time multiplayer — FlowCraft
is a single-user, local-first tool by design.

### Does FlowCraft work offline? Does my code leave my machine?

Yes, and no. FlowCraft makes **no outbound network requests at all** — the canvas, the saved
projects, the export pipeline and the MCP server all work with the network disabled, and the UI
typefaces are bundled with the app rather than fetched from a font CDN. The MCP server listens on
loopback only, so nothing outside your machine can reach it, and FlowCraft never uploads your
diagrams or your source code anywhere. See [Security and privacy](#security-and-privacy) for the
mechanisms behind each of those claims.

### Which AI tools can drive FlowCraft?

Any MCP client that speaks the Streamable HTTP transport and can send a custom header or a bearer
token. The **Setup** dialog ships ready-made config for **Claude Code**, **Claude Desktop**,
**Codex CLI** and **Gemini CLI**. Other MCP-capable clients — editors, agent frameworks — work too
if you point them at the same endpoint.

### Do I need to install a separate MCP server binary?

No. The MCP server runs inside the FlowCraft app itself. Install the app, register the endpoint with
your CLI, and you are done — there is no second process to launch, keep alive or update. (An
optional legacy stdio bridge lives in [`mcp_server/`](mcp_server/) for MCP clients that cannot speak
HTTP at all. Most people should ignore it.)

### Is FlowCraft free and open source?

Yes — MIT licensed. See [LICENSE](LICENSE).

### Which platforms does FlowCraft run on?

macOS, Windows and Linux. Installers for all three are published on the
[Releases page](https://github.com/alisheraxmedov/flowcraft-app/releases). The repository also contains
iOS, Android and web runners, but the desktop platforms are the supported targets — the MCP server
needs `dart:io` sockets and a filesystem, which the web build does not have.

### Where are my whiteboards stored?

In `~/.flowcraft/projects/`, one JSON file per whiteboard, plus a rebuildable `index.json` cache.
Exports go to `~/Documents/FlowCraft/`. The MCP auth token is in `~/.flowcraft/control.token`.

### Can I use FlowCraft without any AI at all?

Yes. Turn the MCP server off with the switch in the Agents popover — or simply never register it with a
CLI — and FlowCraft is an ordinary offline whiteboard.

### Can I export diagrams as PNG or SVG?

Yes, both, plus JSON. PNG and SVG export the entire scene rather than the visible viewport, so
nothing off-screen is silently cropped. SVG keeps the hand-drawn strokes; its text names the Inter
and JetBrains Mono fonts rather than embedding them, and icons are embedded as raster images. JSON
goes back in again — the same menu imports a scene from a file or from pasted text.

### Does FlowCraft collect telemetry or analytics?

No. There is no analytics SDK, no crash reporter, no update ping and no FlowCraft-operated server to
report to.

### Why is the MCP port fixed at 5199?

Because you paste the endpoint into a CLI config once and it has to keep working. A port that
changed on every launch would silently break that saved config. If the bind fails, the Agents popover
says so and offers a Retry instead of showing a green light over a dead endpoint.

### Can FlowCraft draw ER diagrams or database schemas?

Yes. An entity is a table with typed attribute rows and PK/FK tags, relationships are arrows with
crow's-foot ends that attach to a specific row, and `flowcraft_diagram` or `flowcraft_import` will lay
a whole schema out for you. You can also build them by hand from the Inspector, which takes
one `name type [PK] [FK]` row per line.

### Can FlowCraft import Mermaid or DBML?

Yes, Mermaid and DBML, plus Excalidraw scenes, through the **Export** menu's paste dialog or the
`flowcraft_import` tool. Supported:

- **Mermaid flowcharts** (`graph` / `flowchart`, directions `TB`, `TD`, `LR`, `BT`, `RL`): the node
  shapes `[ ]`, `( )`, `([ ])`, `(( ))`, `{ }` and `>]`; links such as `-->`, `---`, `-.->`, `==>`
  and `--x`, chains and `&`; `subgraph … end` becomes a frame. Link labels are dropped, and
  `classDef`, `style`, `click` and `linkStyle` lines are ignored.
- **Mermaid `erDiagram`**: relationships with their cardinalities, and entity blocks with typed,
  PK/FK-tagged attributes.
- **DBML**: `Table` blocks with columns, `pk` and `ref:` settings, and top-level `Ref:` lines.
  `Enum`, `TableGroup` and `Project` are skipped.
- **Excalidraw** (import only): rectangles, ellipses, diamonds, arrows, lines, text and freehand
  strokes, including arrows bound to shapes. Anything else is dropped, and you are told how many.

Mermaid sequence, state and class diagrams, and PlantUML, are not supported yet. A syntax error is
reported with its line number and nothing is imported.

### If I move a shape, do the connected arrows follow?

Yes, since 1.1.0, for arrows that are attached. An arrow drawn from or onto a rectangle, ellipse,
diamond, triangle or sticky note is bound to it, and re-anchors on its outline when the shape moves,
resizes or rotates. Hold `Cmd`/`Ctrl` while drawing or dropping an endpoint to leave it unattached,
and dragging an attached arrow's body without its shape detaches that end. Straight arrows only
re-anchor; they do not route around other shapes. Scenes saved before 1.1.0 load unchanged — their
arrows are simply unattached.

### Can I paste or drag images in?

No. FlowCraft ships with zero Flutter plugins, and Flutter's own clipboard carries text only and
has no desktop drop target, so receiving a pasted or dropped image would need a plugin. Use **Export ›
Insert image from file…** (`Cmd`/`Ctrl`+`Shift`+`I`) and type the file's path, or have an agent send
an `image` element with a `path` or `dataUrl`. Images are embedded in the scene, so keep them small:
4 MiB each, 16 MiB per scene.

### Does FlowCraft support real-time collaboration?

No, and it is not planned. FlowCraft is deliberately a single-user, local-first tool.

---

## How FlowCraft compares

Several diagramming tools now ship MCP servers, and most of them are more mature than FlowCraft as
editors. The distinction worth knowing is **where the canvas actually lives**: nearly every option
renders in a browser, in a hosted cloud board, or inside the chat client's own window. FlowCraft is a
native desktop application on your machine, reached over loopback with a token.

| Tool | Where the canvas lives | Runs with the network off | Drawing stays on your machine |
| --- | --- | --- | --- |
| **FlowCraft** | Native desktop app (macOS/Windows/Linux), loopback HTTP + token auth | Yes | Yes |
| [Excalidraw MCP](https://github.com/excalidraw/excalidraw-mcp) (official) | Interactive canvas returned into the chat client via MCP Apps; hosted endpoint recommended, local install documented | Only if self-hosted | Depends on setup |
| [tldraw MCP App](https://tldraw.dev/blog/tldraw-mcp-app) (official) | Interactive canvas inside the chat client, served from a hosted endpoint | No | No |
| [draw.io MCP](https://www.drawio.com/docs/manual/generate/drawio-mcp-server/) (official) | draw.io editor in the browser; a separate Claude Code skill can write local `.drawio` files | Partly | Partly |
| [Miro MCP](https://developers.miro.com/docs/miro-mcp) (official) | Miro cloud board, OAuth account required | No | No |
| [yctimlin/mcp_excalidraw](https://github.com/yctimlin/mcp_excalidraw) (community) | Excalidraw web UI served from a local Node process on `127.0.0.1` | Yes | Yes |

**Where those tools are ahead.** Be realistic about this. The mature editors have years of work
FlowCraft does not: connectors that route around obstacles and carry labels, large shape and icon
libraries, layers, collaboration, and a wider range of Mermaid diagram types. FlowCraft now has
bound connectors, align and distribute, frames, SVG export, Mermaid and DBML import and automatic
layout, but in a smaller form. draw.io and Miro also cover diagram types FlowCraft has no notion of. If you want the most capable
canvas available, one of those is very likely the better answer today.

**Where FlowCraft is different.** It is a real desktop app rather than a browser tab or a chat
embed; it needs no account and no network; the MCP endpoint is bound to loopback and token-gated;
and your whiteboards are plain JSON files in your own home directory. If "the architecture of my
private codebase must not travel over the internet" is a hard constraint, that combination is the
point.

---

## Security and privacy

The MCP control server is deliberately small and deliberately closed off.

- **Loopback only.** The server binds `InternetAddress.loopbackIPv4` — `127.0.0.1`, never `0.0.0.0`.
  Nothing else on your network, Wi-Fi or LAN can reach it.
- **Token authentication.** Every mutating request must carry a shared token: 32 bytes from
  `Random.secure()`, base64url-encoded, generated on first start and stored at
  `~/.flowcraft/control.token`. Send it as the `X-Flowcraft-Token` header, or as
  `Authorization: Bearer <token>` on `/mcp`. Requests without it get a `401`.
- **DNS-rebinding defence.** Any request whose `Origin` header is not `localhost`, `127.0.0.1` or
  `::1` is rejected with `403`. This is the check MCP's transport specification requires of local
  servers: DNS rebinding lets a malicious page resolve its own domain to `127.0.0.1` and talk to
  you, but the browser still stamps the attacker's origin on the request and script cannot forge it.
  A missing `Origin` — the normal case for CLIs and other non-browser clients — passes.
- **No telemetry.** No analytics, no crash reporting, no usage pings, no update checks. There is no
  FlowCraft-operated server anywhere in the product.
- **No plugins.** The app ships with zero Flutter plugins, so there is no third-party native code in
  the bundle. Its entire runtime dependency list is `flutter_riverpod`, `material_symbols_icons` and `path_parsing` (pure Dart, used to draw the interface icons).
- **No outbound requests.** The Inter, JetBrains Mono, Geist and Geist Mono typefaces are bundled as assets
  (`assets/fonts/`, all SIL OFL 1.1) rather than loaded from a font CDN, so there is no first-run
  download and no host to contact. Grep the source for an outbound URL and you will not find one.

**Treat the token as a secret.** Anything that holds it can draw on, and clear, your canvas. Do not
commit it to a shared repository — use the Agents popover's **Copy connect** button, which fills in the
real value at the moment you need it.

---

## Roadmap

Honest about what is not there yet. No dates — this is an ordering, not a schedule.

**Next**

- **Edge labels.** Arrows have no text slot of their own, so Mermaid link labels are dropped on
  import and `flowcraft_diagram` edges cannot carry a caption.
- **Obstacle-avoiding routing.** Bound arrows re-anchor but go straight, and elbow arrows bend at
  the midpoint without looking at what is in the way.
- **More Mermaid.** Sequence, state and class diagrams; today only flowcharts and `erDiagram`.

**After that**

- **`.excalidraw` export.** Excalidraw scenes can be imported but not written back.
- **Persisted checkpoints.** `flowcraft_checkpoint` snapshots live in memory and vanish when the app
  quits.
- **Paste and drag-drop for images**, if it can be done without adding a plugin.
- **Reshaping freehand strokes** over MCP, which the current draw vocabulary cannot express.

**Packaging and distribution**

- macOS code signing and notarization; a signed Windows installer.

---

## Architecture

MVVM, with state managed by [Riverpod](https://riverpod.dev). `test/` mirrors `lib/` 1:1.

```
flowcraft/
├── lib/
│   ├── main.dart                     ← Entry point (wraps app in ProviderScope)
│   ├── app.dart                      ← MaterialApp host, reads ThemeViewModel
│   ├── flowcraft.dart                ← Barrel export of the public API
│   │
│   ├── models/                       ← Immutable data
│   │   ├── sketch_element.dart          (shapes, text, freedraw, frames, icons,
│   │   │                                 images, ER entities)
│   │   ├── icon_catalog.dart            (the built-in icon names)
│   │   ├── flow_project.dart            (saved-project metadata)
│   │   ├── sketch_style.dart
│   │   ├── sketch_tool.dart
│   │   └── flow_viewport.dart
│   │
│   ├── viewmodels/                   ← App state + Riverpod providers
│   │   ├── sketch_controller.dart       (canvas state — ChangeNotifier)
│   │   ├── sketch_history.dart
│   │   ├── theme_view_model.dart        (dark/light toggle)
│   │   ├── projects_view_model.dart     (project library + active project)
│   │   ├── project_autosave.dart        (debounced write-behind)
│   │   ├── scene_importer.dart          (JSON / Excalidraw / Mermaid / DBML → canvas)
│   │   ├── canvas_preferences.dart      (animate-agent-drawing switch)
│   │   └── mcp_view_model.dart          (MCP control-server lifecycle)
│   │
│   ├── views/                        ← Screens + presentation widgets
│   │   ├── splash_view.dart             (awaits real startup work)
│   │   ├── whiteboard_view.dart         (canvas + floating glass islands)
│   │   └── widgets/                     (tool pill, Inspector, Agents and Projects
│   │                                     popovers, Edit/Export menus, dialogs,
│   │                                     glass/ island widgets + Lucide icons)
│   │
│   ├── services/                     ← External I/O boundary
│   │   ├── app_control.dart              (conditional import: io/web)
│   │   ├── flowcraft_control_server.dart (loopback HTTP router)
│   │   ├── mcp_http_handler.dart         (MCP over Streamable HTTP)
│   │   ├── mcp_tools.dart                (the thirteen tools, as data + handlers)
│   │   ├── mcp_guide.dart                (text behind flowcraft_guide)
│   │   ├── mcp_checkpoints.dart          (in-memory snapshots, per project)
│   │   ├── mcp_host.dart                 (project operations the tools may call)
│   │   ├── project_repository.dart       (saved projects on disk, linked files)
│   │   ├── canvas_exporter.dart          (scene → PNG / JSON file)
│   │   ├── svg_exporter.dart             (scene → SVG)
│   │   ├── export_file_sink.dart         (checked write-to-path for exports)
│   │   ├── image_source.dart             (image path / data URL → bytes)
│   │   ├── diagram_spec.dart             (JSON → SketchElement)
│   │   ├── diagram_layout.dart           (nodes + edges → laid-out elements)
│   │   └── text_import/                  (Mermaid, DBML, Excalidraw parsers)
│   │
│   └── core/                         ← Framework-agnostic infrastructure (incl. theme/ with FcTokens)
│       ├── canvas/                      (pan/zoom host, grid painter)
│       ├── domain/                      (geometry, hit-testing, arrow binding, graph
│       │                                 layout, elbow routing, frame membership)
│       ├── rendering/                   (rough/sketchy painters + cache)
│       ├── interactions/                (pointer → viewmodel mutation)
│       ├── serialization/               (versioned JSON save/load)
│       └── utils/                       (id generation)
│
├── macos/, windows/, linux/, ios/, android/, web/   ← Platform runners
├── mcp_server/                        ← Optional legacy stdio bridge (see its README)
└── test/                              ← Mirrors lib/ 1:1
```

`FlowcraftControlServer` binds a single loopback `HttpServer` and serves two things on it: `/mcp`,
the MCP endpoint described above, and a small private REST API (`/health`, `/draw`, `/clear`) kept
for the legacy stdio bridge. Both land in the same place — mutations on the live `SketchController`
that the whiteboard UI is already watching.

### Working with the canvas in code

```dart
final sketch = SketchController(currentTool: SketchTool.rectangle);

// Programmatic elements
sketch.add(SketchRectangle.create(
  rect: const Rect.fromLTWH(100, 100, 200, 120),
  text: 'Idea',
));

// Serialization
final json = SketchSerializer.serialize(sketch.elements);
final restored = SketchSerializer.deserialize(json);
sketch.addAll(restored);

// History
sketch.undo();
sketch.redo();
```

---

## Build from source

Requires the Flutter SDK with desktop support enabled, and a Dart SDK matching `^3.10.8`.

```bash
flutter pub get
flutter run -d macos      # or -d windows / -d linux
```

Release builds and checks:

```bash
flutter analyze
flutter test
flutter build macos --release
flutter build windows --release
flutter build linux --release
```

> **macOS needs a three-step dance.** This app has zero Flutter plugins, so `flutter build macos`
> skips its usual CocoaPods bookkeeping — but the Xcode project's "Check Pods Manifest.lock" phase
> still runs and fails on a fresh checkout. Run `flutter build macos --release` once (it is expected
> to fail, but it applies the Podfile/Xcode-project migrations), then `pod install` inside `macos/`,
> then build again for real. This is already encoded in the CI workflow.

---

## Contributing

Issues and pull requests are welcome. **Please open an issue and wait for a reply before writing
code** — several things in this repository look like bugs and are deliberate, and the roadmap has an
order. [`CONTRIBUTING.md`](CONTRIBUTING.md) has the full workflow, and
[`CLAUDE.md`](CLAUDE.md) explains the architecture and the traps.

`main` is protected: changes land through a pull request, with a passing `Test` job and a review
from the maintainer. Found a security problem? Do not open a public issue — see
[`SECURITY.md`](SECURITY.md).

The constraints most likely to get a PR rejected:

- **Keep the app at zero Flutter plugins.** It is load-bearing: it is why the macOS build behaves the
  way it does, why export writes to a fixed folder instead of showing a native save dialog, and why
  `services/` uses `_io`/`_stub` conditional-import pairs instead of `path_provider`.
- **Keep the pubspec dependency list where it is.** The only addition beyond Riverpod and the icon
  font is `path_parsing`, approved deliberately to render the interface icons. The MCP protocol is
  hand-rolled on `dart:io` precisely so the app does not take an SDK dependency.
- **Any test that pumps the app must override `mcpServerPortProvider` with `0`.** Reading
  `mcpViewModelProvider` starts a real `HttpServer`, and `flutter test` runs files in parallel — a
  fixed port makes two test files race each other and lose to a FlowCraft window you have open.
- `dart format`, `flutter analyze --fatal-infos` and `flutter test` must all be clean; CI runs
  them on every pull request and gates all three platform builds on them.

---

## License

MIT — see [LICENSE](LICENSE).

Bundled third-party assets: the Inter, JetBrains Mono, Geist and Geist Mono typefaces (SIL OFL 1.1;
licences beside the fonts in `assets/fonts/`) and the interface icons from
[Lucide](https://lucide.dev) (ISC; `assets/icons/Lucide-LICENSE.txt`).
