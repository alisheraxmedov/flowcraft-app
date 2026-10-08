# Changelog

All notable user-facing changes to FlowCraft are recorded here. The format
follows [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and the
project uses [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

The section for a tag becomes that tag's GitHub Release notes — the release
workflow extracts it verbatim and appends GitHub's generated pull-request list
underneath. Day-by-day engineering notes, with the reasoning behind each
decision, live in [`CHANGESLOGS/`](CHANGESLOGS/).

## [Unreleased]

### Changed

- **Glass Canvas redesign.** The whole interface is rebuilt as floating glass islands:
  - Top-left: logo, project name and the **Projects** popover (replaces the project drawer; a row's
    **…** menu has Rename, Link to file… / Unlink file and Delete).
  - Top-centre: a tool pill with all 14 tools.
  - Top-right: the **Agents** chip and popover (MCP server switch, animate-drawing switch, and the
    endpoint, Copy connect and Setup while the server runs; the reason and Retry if it fails to
    start), the **Edit** menu and **Export**. The Connect dialog is now four tabs.
  - Left: one **Inspector** island for style, arrow, position, kind and font settings. It works on
    one or many elements, or on the next shape you draw when a drawing tool is active, and keeps
    **Edit JSON**.
  - Bottom-right: Undo, Redo, Grid and Theme.
  - Every control now lives in exactly one place: Undo/Redo only bottom-right (shortcuts
    unchanged), Delete only in the Edit menu, and **Clear canvas** in the Edit menu's Canvas group
    with an Undo snackbar. The Edit menu no longer has a History group.
  - New UI typeface Geist (and Geist Mono); the canvas fonts are unchanged. Interface icons are the
    design's Lucide icons, drawn 1:1. The light theme is hand-tuned and the default.

### Added

- **Read/edit MCP surface.** Three new tools join `flowcraft_draw`, so an AI
  agent can correct a diagram instead of clearing it and starting over:
  `flowcraft_read` returns every element on the canvas with its `id`, `type`,
  geometry, text and colours; `flowcraft_update` edits existing elements in
  place by `id`, changing only the fields you pass and leaving everything else
  untouched; and `flowcraft_delete` removes specific elements by `id`. Reading
  and editing use the same field names as drawing, and an element's type
  cannot be changed through an update — delete it and draw a new one instead.
- **Automatic layout.** A new `flowcraft_diagram` MCP tool takes nodes and
  edges, with no coordinates, and lays the graph out itself: ranked, ordered
  to limit crossings and evenly spaced, in any of four directions, with
  optional frames and elbow connectors. Arrows come back bound to their boxes.
- **Arrows stay attached.** An arrow drawn or dragged onto a rectangle,
  ellipse, diamond, triangle or sticky note binds to it and re-anchors on its
  outline when the shape moves, resizes or rotates. Hold Cmd/Ctrl to leave an
  end unattached; over MCP use `fromId` / `toId`. Straight arrows do not route
  around obstacles. Older scenes load unchanged.
- **Zoom to fit** (Shift+1, or Edit › Align & view › Zoom to fit), and the view re-frames
  onto what an agent has just drawn when it landed off-screen.
- **Align and distribute.** Align edges or centres of a multi-selection and
  distribute three or more items evenly, from the Edit menu's Align & view submenu or the keyboard
  (Cmd/Ctrl+Shift+arrows, Alt+H, Alt+V, Alt+Shift+H, Alt+Shift+V).
- **See and verify over MCP.** `flowcraft_screenshot` returns a PNG of the
  canvas or of a selection, so an agent can check its own drawing, and
  `flowcraft_guide` hands it the drawing conventions in one call.
- **Checkpoints.** A snapshot of the canvas is taken before every MCP tool that
  changes it (the last 20, in memory); `flowcraft_checkpoint` lists, creates
  and restores them, and a restore is one undo step.
- **Export from MCP.** `flowcraft_export` produces PNG, SVG or JSON, inline or
  written to a checked absolute path (matching extension, existing folder,
  `overwrite: true` to replace, `~/.flowcraft` off limits).
- **Projects over MCP.** `flowcraft_project` lists, opens, creates, renames,
  links and unlinks saved whiteboards.
- **Import Mermaid, DBML and Excalidraw.** The `flowcraft_import` tool and the
  paste dialog take Mermaid flowcharts and `erDiagram`, DBML, Excalidraw scenes
  (import only) and FlowCraft JSON, detected from the text. Mermaid and DBML
  are laid out automatically, subgraphs become frames, and a syntax error is
  reported with its line number without touching the canvas.
- **Filtered, paginated `flowcraft_read`.** Narrow by `ids`, `types`, `frame`
  or `region`; page with `limit` and `offset`.
- **Live draw animation.** Agent drawings draw themselves on; a switch on the
  System card turns it off. Undo, autosave and export are unaffected.
- **Frames** (F). Named containers drawn behind what they wrap; dragging a frame
  moves what is inside it.
- **Elbow arrows.** A per-arrow switch (and `elbow` over MCP) routes arrows
  with right-angle bends.
- **Icon library** (I). 24 built-in glyphs placed from the tool rail or by name
  over MCP.
- **Images.** Export › Insert image from file… (Cmd/Ctrl+Shift+I) and MCP `image`
  elements embed PNG, JPEG, WebP and GIF files, up to 4 MiB each and 16 MiB per
  scene. There is no paste or drag-and-drop: the app has no plugins, and
  Flutter's clipboard is text-only.
- **ER diagrams.** Entity tables with typed attribute rows and PK/FK tags,
  crow's-foot cardinality ends, and relationship edges that attach to a
  specific row.
- **SVG export** from the Export menu and over MCP. Hand-drawn strokes are
  kept; text references Inter and JetBrains Mono by name, and icons are
  embedded as raster images.
- **Richer text.** Sans (Inter) or mono (JetBrains Mono), bold, and
  left/centre/right alignment for free text.
- **Link a board to a file in a repo.** Link a project to a `.flowcraft` or
  `.json` file: every save mirrors the scene there, and a newer linked file
  wins on load. Linking to an existing scene file adopts it and never
  overwrites it. Available from the project sidebar and as `flowcraft_project`
  `link` / `unlink`.

### Changed

- **MCP surface.** Tool handlers are asynchronous. Tools can reply with image
  content blocks (`flowcraft_screenshot`, and PNG exports returned inline).
  `flowcraft_draw` now lists the ids of the elements it created. `flowcraft_read`
  is paginated (500 elements per page by default, `nextOffset` when more
  remain) and omits image bytes unless `includeImageData` is true. The server
  now exposes thirteen tools, up from six.
- The paste dialog now reads Excalidraw, Mermaid and DBML as well as JSON.

## [1.0.0] - 2026-08-22

First public release.

FlowCraft is a free, open-source whiteboard and diagramming desktop app for
macOS, Windows and Linux. It gives you an infinite canvas with a hand-drawn,
sketchy rendering style — shapes, arrows, sticky notes, freehand strokes and
text — plus a **built-in MCP (Model Context Protocol) server**, so AI coding
agents such as Claude Code, Codex CLI, Gemini CLI and Claude Desktop can
analyse your codebase and draw its architecture diagram straight onto the
running canvas. There is no second binary to install, no account, and no cloud
service in the loop: the server binds `127.0.0.1` only, every request is
token-authenticated, and the app makes no outbound network request at all.

### Downloads

| Platform | File | Minimum OS |
| --- | --- | --- |
| macOS (Apple Silicon and Intel) | `FlowCraft-macOS-1.0.0.dmg` | macOS 10.15 Catalina |
| Windows (x64) | `FlowCraft-Windows-Setup-1.0.0.exe` | Windows 10 |
| Linux (Debian / Ubuntu, x64) | `flowcraft_1.0.0_amd64.deb` | Any distribution with GTK 3 (Ubuntu 22.04 or later) |

Every file is built from this tag by the public
[GitHub Actions workflow](https://github.com/alisheraxmedov/flowcraft-app/blob/main/.github/workflows/build-desktop.yml).

### The binaries are not signed — read this before the first launch

FlowCraft is built by one person and is **not signed with a paid Apple or
Microsoft certificate**. Both operating systems will object the first time you
open it. This is expected.

- **macOS.** Open the `.dmg` and drag **flowcraft** into **Applications**. The
  first launch says *"Apple could not verify 'flowcraft' is free of malware"*
  and offers only **Done**. Click Done, open **System Settings → Privacy &
  Security**, scroll to the *Security* section, click **Open Anyway** next to
  the FlowCraft message, then confirm. You only do this once. From the
  terminal, `xattr -d com.apple.quarantine /Applications/flowcraft.app` does
  the same thing. On macOS 13 and earlier, Control-click the app → **Open**
  → **Open**.
- **Windows.** SmartScreen shows *"Windows protected your PC"*. Click **More
  info**, then **Run anyway**. The installer offers an install-for-me-only
  option that needs no administrator password.
- **Linux.** `sudo apt install ./flowcraft_1.0.0_amd64.deb` — this also pulls
  in GTK 3 if it is missing. The package installs to `/usr/lib/flowcraft`,
  puts a `flowcraft` launcher on your `PATH` and adds an application-menu
  entry.

Code signing and notarization are on the roadmap.

### Connect your AI agent

The MCP server starts with the app and serves a spec-compliant endpoint over
the **Streamable HTTP** transport at `http://127.0.0.1:5199/mcp`. For Claude
Code:

```bash
claude mcp add --transport http flowcraft http://127.0.0.1:5199/mcp \
  --header "X-Flowcraft-Token: <your-token>"
```

The **System** card in the bottom-right corner of the window shows the live
status, a **Copy connect** button that fills in the real token, and a
**Setup** dialog with ready-made config for Claude Code, Claude Desktop, Codex
CLI and Gemini CLI. The token is in `~/.flowcraft/control.token`; treat it as
a secret — anything holding it can draw on your canvas.

Three tools are exposed:

| Tool | What it does |
| --- | --- |
| `flowcraft_status` | Confirms the app is running and reports how many elements are on the canvas. |
| `flowcraft_draw` | Draws rectangles, ellipses, diamonds, triangles, sticky notes, text, lines and arrows. `mode: "add"` (default) appends; `mode: "replace"` clears the canvas first. |
| `flowcraft_clear` | Removes every element from the canvas. |

### What is in the box

- Infinite canvas with pan, pinch-zoom and wheel-zoom (0.1× to 4×), a
  toggleable dot grid, and a roughness dial from clean geometry to very rough.
- Tools: select, hand, rectangle, ellipse, diamond, triangle, sticky note,
  line, arrow, freehand, text, eraser — with Excalidraw's single-letter
  shortcuts so muscle memory carries over.
- Stroke and fill colour, stroke width, opacity, solid/dashed/dotted strokes,
  and none/solid/hachure/cross-hatch fills. Every style control applies to the
  whole selection as one undo entry.
- Click, Shift-click and marquee selection; eight resize handles with Shift to
  keep the aspect ratio; draggable line and arrow endpoints; grouping; z-order;
  copy, cut, paste and duplicate through the system clipboard; snapping to the
  grid and to other elements with guide lines, `Alt` to place freely; 50-step
  undo/redo.
- Sticky notes drawn as chat bubbles that collapse to a badge so a board can
  carry many notes without them swamping the diagram.
- Saved projects with autosave, a project sidebar, and click-to-rename in the
  top bar. Export to PNG (the whole scene, 2×) or JSON, and import a scene back
  from a file or pasted JSON.
- Light and dark themes; bundled Inter and JetBrains Mono typefaces, so there
  is no first-run font download.

### Where FlowCraft keeps your data

| What | Where |
| --- | --- |
| Saved whiteboards | `~/.flowcraft/projects/` — one JSON file each, written atomically, plus a rebuildable `index.json` cache |
| PNG and JSON exports | `~/Documents/FlowCraft/`, timestamped so nothing is overwritten |
| MCP auth token | `~/.flowcraft/control.token`, owner-readable only |

### Known limitations

- **No automatic layout.** The agent chooses every x/y coordinate itself, and
  language models are poor at spatial packing, so first attempts can overlap.
  Give the agent a size budget in the prompt and ask for `mode: replace` with
  more spacing if it does. Auto-layout is the top roadmap item.
- **Arrows do not follow shapes.** Moving a box leaves its arrows where they
  were; drag the endpoints or group the box with its arrows. The file format
  already reserves the binding fields, so saved scenes will survive the change.
- **No SVG export**, no Mermaid/DBML/PlantUML import, no zoom-to-fit, no
  align/distribute, no first-class ER diagrams, and no real-time collaboration
  (by design — FlowCraft is single-user and local-first).
- **Fixed port.** The MCP server always uses `5199`. If another FlowCraft
  window already holds it, the System card says so and offers a Retry.
- The bundled legacy stdio bridge in `mcp_server/` exists only for MCP clients
  that cannot speak HTTP; most people should ignore it.

[Unreleased]: https://github.com/alisheraxmedov/flowcraft-app/compare/v1.0.0...HEAD
[1.0.0]: https://github.com/alisheraxmedov/flowcraft-app/releases/tag/v1.0.0
