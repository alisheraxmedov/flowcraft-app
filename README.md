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

FlowCraft is also a perfectly ordinary whiteboard. If you never connect an AI agent, it is still an offline sketching app with saved projects, autosave, undo/redo and PNG/JSON export.

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

Installers for all three desktop platforms are built by GitHub Actions on every push to `main`
([`.github/workflows/build-desktop.yml`](.github/workflows/build-desktop.yml)) and published as
**workflow artifacts**. Open the repository's **Actions** tab, pick the latest successful
*Build Desktop Installers* run, and download the artifact for your platform:

| Platform | Artifact name | Contents |
| --- | --- | --- |
| macOS | `flowcraft-macos-installer` | `FlowCraft-macOS-<version>.dmg` |
| Windows | `flowcraft-windows-installer` | Inno Setup installer (`.exe`) |
| Linux | `flowcraft-linux-installer` | Debian package (`.deb`) |

GitHub requires you to be signed in to download workflow artifacts.

> **Note on macOS:** the `.dmg` is not yet code-signed or notarized, so Gatekeeper will warn
> the first time you open it. Signing and notarization are on the [roadmap](#roadmap).

Prefer to build it yourself? See [Build from source](#build-from-source).

---

## Connect your AI agent

**The MCP server is the app.** It starts with FlowCraft and serves a spec-compliant MCP endpoint
over the **Streamable HTTP** transport at:

```
http://127.0.0.1:5199/mcp
```

The **System** card in the bottom-right corner of the window shows the live status, the endpoint,
a **Copy connect** button and a **Setup** dialog with ready-made config for each CLI — all with the
real port and token already filled in. The switch on that card turns the server off if you would
rather it not listen.

Every request must carry the app's auth token, which FlowCraft writes to `~/.flowcraft/control.token`
on first start. In the snippets below, replace `<your-token>` with that value (or just use the
card's **Copy connect** / **Setup** buttons, which paste it for you).

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

### If the System card shows an error

Something else already holds port `5199` — usually a FlowCraft window you forgot was open. The port
is deliberately fixed rather than falling back to a random free one: the config you saved in your
CLI has to keep working across restarts, and a port that silently changed every launch would break
it without ever saying so. Close the other instance and press **Retry**.

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

**Getting better results.** FlowCraft does not lay diagrams out for you yet — the agent chooses the
coordinates itself, and models are famously bad at spatial packing. Two things that help:

- Give it a budget in the prompt: *"use 260×120 boxes with at least 80px of space between them."*
- If the result overlaps, say *"redraw it with `mode: replace` and more vertical spacing"* rather
  than asking for nudges. Automatic layout is the top item on the [roadmap](#roadmap).

---

## MCP tool reference

FlowCraft exposes three tools:

| Tool | Arguments | What it does |
| --- | --- | --- |
| `flowcraft_status` | none | Confirms the app is running and reachable, and reports how many elements are on the canvas. |
| `flowcraft_draw` | `{ mode?: "add" \| "replace", elements: [...] }` | Draws elements. `add` (the default) appends; `replace` clears the canvas first. Any unrecognised mode is treated as `add`, so a typo can never wipe your work. |
| `flowcraft_clear` | none | Removes every element from the canvas. |

Each entry in `elements` is an object with a required `type` and the fields that type uses:

| `type` | Fields |
| --- | --- |
| `rectangle`, `ellipse`, `diamond`, `triangle`, `sticky` | `x`, `y`, `width`, `height`, `text`, `fontSize`, `strokeColor`, `fillColor` |
| `text` | `x`, `y`, `text` (required), `fontSize`, `strokeColor` |
| `arrow`, `line` | `fromX`, `fromY`, `toX`, `toY`, `strokeColor` |

Coordinates are canvas-space pixels. Colours are hex strings such as `"#1E1E1E"` (3-byte `RRGGBB`
is expanded to opaque). Bounded shapes default to 160×80 when no size is given. Arrows and lines
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
  text, eraser.
- Text as a centred label inside any shape or sticky note, or as free-floating text, edited inline
  on the canvas.

**Styling**

- Stroke colour, fill colour, stroke width, opacity.
- Stroke patterns: solid, dashed, dotted.
- Fill patterns: none, solid, hachure, cross-hatch.
- Every style control applies to the whole current selection as a **single undo entry**, and the
  toolbar reflects the selection (with a neutral indicator when a multi-selection disagrees).

**Editing**

- Click, `Shift`-click and marquee to select; drag to move; eight resize handles on bounded shapes,
  with `Shift` to keep the aspect ratio; draggable endpoints on lines and arrows.
- Group and ungroup — clicking one member selects the whole group.
- Copy, cut, paste and duplicate through the system clipboard, so it works between two FlowCraft
  windows. Z-order: bring forward, send backward, bring to front, send to back.
- Snapping to the grid and to other elements' edges and centres, with a guide line showing why, and
  `Alt` to place something freely.
- Snapshot-based undo/redo, 50 steps deep by default. One continuous drag is one undo entry.
- Light and dark themes.

**Files**

- Saved projects with autosave (see [below](#projects-autosave-and-export)).
- Export to PNG or JSON, copy the JSON to the clipboard, and import a scene back from a file or
  pasted JSON.

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

**Edit, history and arrange:**

| Shortcut | Action |
| --- | --- |
| `Cmd`+`C` / `Cmd`+`X` / `Cmd`+`V` | Copy / cut / paste — via the system clipboard, so it works between two FlowCraft windows |
| `Cmd`+`D` | Duplicate the selection |
| `Cmd`+`A` | Select all |
| `Delete` / `Backspace` | Delete the selection |
| `Esc` | Clear the selection |
| `Cmd`+`Z` / `Cmd`+`Shift`+`Z` / `Ctrl`+`Y` | Undo / redo |
| `Cmd`+`]` / `Cmd`+`[` | Bring forward / send backward |
| `Cmd`+`Shift`+`]` / `Cmd`+`Shift`+`[` | Bring to front / send to back |
| `Cmd`+`G` / `Cmd`+`Shift`+`G` | Group / ungroup |
| Arrow keys | Nudge the selection 1px (`Shift` for 10px) |
| `?` | Shortcut reference |

Everything here is also reachable from the top bar's **Edit** menu, which shows each binding beside
its command.

**On the canvas:** `Shift`-click adds to or removes from the selection, and `Shift`-drag extends a
marquee instead of replacing it. Clicking any member of a group selects the whole group. Moves,
resizes and endpoint drags snap to the grid and to other elements' edges and centres, with a guide
line showing why — hold `Alt` to place something freely.

---

## Projects, autosave and export

Every whiteboard is a named project. The menu button in the top bar opens the project sidebar —
**new**, rename in place, delete, and switch. The canvas swaps instantly and the outgoing project is
flushed to disk on the way out. The open project's name sits in the top bar and is click-to-rename.
Nothing needs saving manually; edits are written behind you as you draw, and again when the app
exits.

Projects live in `~/.flowcraft/projects/`, one JSON file each, written atomically (temp file +
rename). The `index.json` beside them is only a cache that makes the sidebar fast — if it is lost or
corrupt it is rebuilt by scanning the scene files themselves, so a bad index can never cost you a
whiteboard.

The **Export** button offers three destinations:

| Choice | Result |
| --- | --- |
| PNG | The whole scene — not just the visible viewport — at 2×, with a padded margin, capped at 8192px on the longest side. |
| JSON | The versioned `SketchSerializer` format: re-importable and diff-able. |
| Clipboard | The same JSON, straight to the clipboard. |

Files land in `~/Documents/FlowCraft/`, timestamped so a second export never silently overwrites
the first, and the confirmation offers **Reveal** to open the containing folder. There is no native
save dialog on purpose: the app ships with zero Flutter plugins, and a file-picker plugin would end
that.

The same menu **imports** a scene back: pick one of your exports from a list of
`~/Documents/FlowCraft/`, or type a path to a `.flowcraft.json` someone sent you, or paste the JSON
directly. Either add it to the current canvas or replace the canvas with it. Loading is tolerant —
an element FlowCraft cannot read is skipped rather than failing the whole file, and you are told how
many were dropped instead of finding out later.

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

macOS, Windows and Linux. Installers are built for all three by CI. The repository also contains
iOS, Android and web runners, but the desktop platforms are the supported targets — the MCP server
needs `dart:io` sockets and a filesystem, which the web build does not have.

### Where are my whiteboards stored?

In `~/.flowcraft/projects/`, one JSON file per whiteboard, plus a rebuildable `index.json` cache.
Exports go to `~/Documents/FlowCraft/`. The MCP auth token is in `~/.flowcraft/control.token`.

### Can I use FlowCraft without any AI at all?

Yes. Turn the MCP server off with the switch on the System card — or simply never register it with a
CLI — and FlowCraft is an ordinary offline whiteboard.

### Can I export diagrams as PNG or SVG?

PNG and JSON today; SVG is on the [roadmap](#roadmap). PNG exports the entire scene rather than the
visible viewport, so nothing off-screen is silently cropped. JSON goes back in again — the same menu
imports a scene from a file or from pasted text.

### Does FlowCraft collect telemetry or analytics?

No. There is no analytics SDK, no crash reporter, no update ping and no FlowCraft-operated server to
report to.

### Why is the MCP port fixed at 5199?

Because you paste the endpoint into a CLI config once and it has to keep working. A port that
changed on every launch would silently break that saved config. If the bind fails, the System card
says so and offers a Retry instead of showing a green light over a dead endpoint.

### Can FlowCraft draw ER diagrams or database schemas?

Not as a first-class feature yet. An agent can draw an approximate ER diagram today using
rectangles, text and arrows, but there are no entity boxes with typed attribute rows, no
primary/foreign-key markers and no crow's-foot cardinality. Proper ER support is on the
[roadmap](#roadmap).

### Can FlowCraft import Mermaid, DBML or PlantUML?

Not yet. Today the MCP interface takes explicit shapes and coordinates. Text-format import is on the
[roadmap](#roadmap).

### If I move a shape, do the connected arrows follow?

Not yet. Arrows are independent elements, so moving a box leaves its arrows where they were. Two
things soften it in the meantime: an arrow's endpoints are draggable, so a connector is fixable
without redrawing it, and grouping a box with its arrows makes them move together. Real
arrow-to-shape binding is on the [roadmap](#roadmap) — the file format already reserves the fields
for it, so scenes you save today will not be invalidated when it lands.

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
FlowCraft does not: connectors that stay bound to shapes when you move them, distribute-and-align
commands, large shape and icon libraries, SVG export, Mermaid import, layers, frames, collaboration,
and — in several cases — automatic layout, so the model does not have to invent coordinates.
draw.io and Miro also cover diagram types FlowCraft has no notion of. If you want the most capable
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
  the bundle. Its entire runtime dependency list is `flutter_riverpod` and `material_symbols_icons`.
- **No outbound requests.** The Inter and JetBrains Mono typefaces are bundled as assets
  (`assets/fonts/`, both SIL OFL 1.1) rather than loaded from a font CDN, so there is no first-run
  download and no host to contact. Grep the source for an outbound URL and you will not find one.

**Treat the token as a secret.** Anything that holds it can draw on, and clear, your canvas. Do not
commit it to a shared repository — use the System card's **Copy connect** button, which fills in the
real value at the moment you need it.

---

## Roadmap

Honest about what is not there yet. No dates — this is an ordering, not a schedule.

**Next**

- **Automatic layout.** The single biggest gap. Today the agent has to choose x/y coordinates for
  every box, which is the thing language models are worst at; the result is overlapping shapes and
  crossing arrows. The fix is for the app to lay out a described graph itself so the agent can send
  semantics instead of geometry.
- **Arrow-to-shape binding.** Connectors that stay attached and re-route when you move or resize a
  shape — with a modifier key to suppress binding when you do not want it. The file format already
  reserves the fields, so enabling it will not invalidate scenes you saved before it lands.
- **Zoom-to-fit**, and re-framing the viewport onto whatever an agent just drew, so an MCP diagram
  can never land off-screen.
- **Align and distribute** across a multi-selection.

**After that**

- **ER diagrams.** Entity boxes with typed attribute rows, primary/foreign-key markers, crow's-foot
  cardinality, and relationship edges that anchor to a specific attribute row rather than the box
  edge.
- **Text-format import** so an agent can send a diagram as text: Mermaid (including `erDiagram`) and
  DBML are the formats language models produce most reliably.
- **Richer MCP surface** — reading the canvas back and updating existing elements, not only creating
  new ones.
- **SVG export.**
- **Richer text styling** on canvas elements.

**Packaging and distribution**

- macOS code signing and notarization; a signed Windows installer.
- Published GitHub Releases instead of CI workflow artifacts.

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
│   │   ├── sketch_element.dart          (shapes, text, freedraw)
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
│   │   └── mcp_view_model.dart          (MCP control-server lifecycle)
│   │
│   ├── views/                        ← Screens + presentation widgets
│   │   ├── splash_view.dart             (awaits real startup work)
│   │   ├── whiteboard_view.dart         (canvas + tool panel)
│   │   └── widgets/                     (toolbars, text editor, sketch layer,
│   │                                     project drawer, export menu, MCP card)
│   │
│   ├── services/                     ← External I/O boundary
│   │   ├── app_control.dart              (conditional import: io/web)
│   │   ├── flowcraft_control_server.dart (loopback HTTP router)
│   │   ├── mcp_http_handler.dart         (MCP over Streamable HTTP)
│   │   ├── mcp_tools.dart                (the three canvas tools)
│   │   ├── project_repository.dart       (saved projects on disk)
│   │   ├── canvas_exporter.dart          (scene → PNG / JSON file)
│   │   └── diagram_spec.dart             (JSON → SketchElement)
│   │
│   └── core/                         ← Framework-agnostic infrastructure
│       ├── canvas/                      (pan/zoom host, grid painter)
│       ├── domain/                      (geometry, hit-testing, stroke simplify)
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
- **Keep the pubspec dependency list where it is.** The MCP protocol is hand-rolled on `dart:io`
  precisely so the app does not take an SDK dependency.
- **Any test that pumps the app must override `mcpServerPortProvider` with `0`.** Reading
  `mcpViewModelProvider` starts a real `HttpServer`, and `flutter test` runs files in parallel — a
  fixed port makes two test files race each other and lose to a FlowCraft window you have open.
- `flutter analyze` and `flutter test` must both be clean; CI gates all three platform builds on
  them.

---

## License

MIT — see [LICENSE](LICENSE).
