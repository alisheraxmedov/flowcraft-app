# FlowCraft

**An interactive whiteboard desktop app for macOS, Windows, and Linux — with
a built-in MCP control server so AI coding agents (Claude Code, Codex CLI,
Gemini CLI, ...) can draw diagrams live on the canvas.**

[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-%E2%89%A51.17.0-02569B.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%E2%89%A53.10.8-0175C2.svg)](https://dart.dev)

---

## ✨ Features

- **Infinite canvas** — pan, pinch-zoom, and mouse-wheel zoom with a
  configurable dot/line grid background.
- **Shapes** — rectangle, ellipse, diamond, triangle, sticky note, line, and
  arrow with sketchy (rough) rendering and resize handles.
- **Freehand drawing** — smooth, simplified strokes.
- **Text** — free-floating text or centred labels inside shapes, with an
  inline editor.
- **Styling** — stroke colour, fill colour, stroke width, roughness,
  solid/dashed/dotted strokes, and hachure fills.
- **Selection** — tap-to-select, marquee selection, and drag-to-move.
- **Undo / redo** — snapshot-based history with configurable depth.
- **Saved projects** — every whiteboard is a named project in a sidebar,
  autosaved as you draw and reopened where you left off.
- **Export** — PNG or JSON, of the whole scene rather than just what's
  on screen.
- **AI-drivable** — a built-in MCP server (HTTP transport, no extra binary)
  lets AI coding agents draw class diagrams, architecture maps, or anything
  else they've analyzed in your codebase directly onto the running app.
- **MVVM + Riverpod** — canvas state, theme, projects, and the MCP toggle
  are each a view model behind a provider; views only read/call them.

---

## 🚀 Run it

```bash
flutter pub get
flutter run -d macos   # or -d windows / -d linux
```

Pre-built installers for macOS (`.dmg`), Windows (installer `.exe`), and
Linux (`.deb`) are published as workflow artifacts by
[`.github/workflows/build-desktop.yml`](.github/workflows/build-desktop.yml)
on every push — see the repo's Actions tab.

---

## 💾 Projects and export

Whiteboards are saved automatically. The menu button in the top-left opens
the project sidebar: **New project**, rename in place, delete, and switch
between them — the canvas swaps instantly and the outgoing project is
flushed to disk on the way out. The open project's name sits in the top bar
and is click-to-rename.

Projects live in `~/.flowcraft/projects/`, one JSON file each, written
atomically. `index.json` beside them is only a cache to make the sidebar
fast — if it's lost or corrupt it is rebuilt by scanning the scene files, so
a bad index can never cost you a whiteboard.

The **Export** button offers three destinations:

| Choice | Result |
| --- | --- |
| PNG | The whole scene (not just the visible viewport) at 2× with a padded margin. |
| JSON | The versioned `SketchSerializer` format — re-importable, diff-able. |
| Clipboard | The same JSON, straight to the clipboard. |

Files land in `~/Documents/FlowCraft/`, timestamped so a second export never
silently overwrites the first, and the confirmation offers **Reveal** to
open the containing folder. There is no native save dialog on purpose: the
app ships with zero Flutter plugins (see `CLAUDE.md` for why that matters to
the macOS build), and a file-picker plugin would end that.

---

## 🤖 AI integration (MCP)

**The MCP server is the app.** There is nothing extra to download: flip the
**MCP Server** switch on the card in the bottom-right corner and the running
app serves a spec-compliant MCP endpoint over the Streamable HTTP transport
at `http://127.0.0.1:5199/mcp`.

Register it with Claude Code in one line — the card's **Copy connect**
button puts this on your clipboard with the real port and token filled in:

```bash
claude mcp add --transport http flowcraft http://127.0.0.1:5199/mcp \
  --header "X-Flowcraft-Token: <token>"
```

The equivalent JSON, for `.mcp.json` / `claude_desktop_config.json` (the
card's **Setup** button shows this too, plus the Codex CLI TOML and the
Gemini CLI variant):

```json
{
  "mcpServers": {
    "flowcraft": {
      "type": "http",
      "url": "http://127.0.0.1:5199/mcp",
      "headers": { "X-Flowcraft-Token": "<token>" }
    }
  }
}
```

Then just ask your agent to draw:

> Study `../my-project/` and draw its class model on FlowCraft.

| Tool | Purpose |
| --- | --- |
| `flowcraft_status` | Reports that the app is reachable and how full the canvas is. |
| `flowcraft_draw` | Draws shapes: `{mode?: "add"\|"replace", elements: [...]}`. |
| `flowcraft_clear` | Clears the canvas. |

**If the card shows an error**, something else already holds port 5199 —
usually a FlowCraft window you forgot was open. The port is deliberately
fixed rather than falling back to a random free one: the whole point of the
config you saved in your CLI is that it keeps working across restarts, and a
port that silently changes every launch would break it without ever saying
so. Close the other instance and press **Retry**.

**Security.** The server binds to loopback only, requires the shared token
(written to `~/.flowcraft/control.token`) on every request, and refuses any
browser request whose `Origin` isn't itself local — the DNS-rebinding
defense MCP's transport spec requires of local servers. Treat the token as
a secret: anything holding it can draw on your canvas.

[`mcp_server/`](mcp_server/) still exists as an **optional legacy stdio
bridge** for MCP clients that can't do HTTP transport. Most people should
ignore it.

---

## 🏗️ Architecture Overview

MVVM, with state managed by [Riverpod](https://riverpod.dev):

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
│   │   └── mcp_view_model.dart          (MCP control-server on/off)
│   │
│   ├── views/                        ← Screens + presentation widgets
│   │   ├── splash_view.dart             (awaits real startup work)
│   │   ├── whiteboard_view.dart         (canvas + tool panel)
│   │   └── widgets/                     (toolbars, text editor, sketch layer,
│   │                                     project drawer, export menu, MCP card)
│   │
│   ├── services/                     ← External I/O boundary
│   │   ├── app_control.dart             (conditional import: io/web)
│   │   ├── flowcraft_control_server.dart (loopback HTTP router)
│   │   ├── mcp_http_handler.dart        (MCP over Streamable HTTP)
│   │   ├── mcp_tools.dart               (the three canvas tools)
│   │   ├── project_repository.dart      (saved projects on disk)
│   │   ├── canvas_exporter.dart         (scene → PNG / JSON file)
│   │   └── diagram_spec.dart            (JSON → SketchElement)
│   │
│   └── core/                         ← Framework-agnostic infrastructure
│       ├── canvas/                      (pan/zoom host, grid painter)
│       ├── domain/                      (geometry, hit-testing, stroke simplify)
│       ├── rendering/                   (rough/sketchy painters + cache)
│       ├── interactions/                (pointer → viewmodel mutation)
│       ├── serialization/               (JSON save/load)
│       └── utils/                       (id generation)
│
├── macos/, windows/, linux/, ios/, android/, web/   ← Platform runners
├── mcp_server/                        ← Optional legacy stdio bridge (see its README)
└── test/                              ← Mirrors lib/ 1:1
```

---

## 🔧 API Highlights

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

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
