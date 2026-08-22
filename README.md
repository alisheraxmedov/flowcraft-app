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
- **Serialization** — JSON save/load of every element.
- **AI-drivable** — an MCP server (see [`mcp_server/`](mcp_server/)) lets AI
  coding agents draw class diagrams, architecture maps, or anything else
  they've analyzed in your codebase directly onto the running app.
- **MVVM + Riverpod** — canvas state, theme, and the MCP toggle are each a
  view model behind a provider; views only read/call them.

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

## 🤖 AI integration (MCP)

The app starts a local control server automatically (toggle it from the
toolbar switch). A separate, isolated binary — `mcp_server/` — bridges that
server to any MCP-capable AI CLI over stdio. Pre-built binaries for all
three platforms are published alongside the app installers, so no Dart SDK
is required to use them.

See [`mcp_server/README.md`](mcp_server/README.md) for setup instructions
per CLI (Claude Code, Codex, Gemini) and the full tool list.

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
│   │   └── mcp_view_model.dart          (MCP control-server on/off)
│   │
│   ├── views/                        ← Screens + presentation widgets
│   │   ├── whiteboard_view.dart         (canvas + tool panel)
│   │   └── widgets/                     (toolbars, text editor, sketch layer)
│   │
│   ├── services/                     ← External I/O boundary
│   │   ├── app_control.dart             (conditional import: io/web)
│   │   ├── flowcraft_control_server.dart (loopback HTTP, MCP bridge target)
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
├── mcp_server/                        ← Isolated stdio MCP bridge (see its README)
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
