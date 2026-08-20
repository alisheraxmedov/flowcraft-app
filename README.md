# FlowCraft

**A Miro / Excalidraw-style interactive whiteboard for Flutter.**

[![pub.dev](https://img.shields.io/pub/v/flowcraft.svg)](https://pub.dev/packages/flowcraft)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-%E2%89%A51.17.0-02569B.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%E2%89%A53.10.0-0175C2.svg)](https://dart.dev)

FlowCraft is an open-source Flutter package that provides a self-contained
whiteboard canvas — draw shapes, arrows, and freehand strokes, drop text onto
the board or into shapes, and organize everything on an infinite pan/zoom
grid — **with zero external dependencies**.

---

## ✨ Features

- **Infinite canvas** — pan, pinch-zoom, and mouse-wheel zoom with a
  configurable dot/line grid background.
- **Shapes** — rectangle, ellipse, diamond, line, and arrow with sketchy
  (rough) rendering.
- **Freehand drawing** — smooth, simplified strokes.
- **Text** — free-floating text or centred labels inside shapes, with an
  inline editor.
- **Styling** — stroke colour, fill colour, stroke width, roughness,
  solid/dashed/dotted strokes, and hachure fills.
- **Selection** — tap-to-select, marquee selection, and drag-to-move.
- **Undo / redo** — snapshot-based history with configurable depth.
- **Serialization** — JSON save/load of every element.
- **Zero dependencies** — only the Flutter SDK. No external packages.

---

## 🚀 Quick Start

### Install

```bash
flutter pub add flowcraft
```

### Use

```dart
import 'package:flowcraft/flowcraft.dart';

class MyWhiteboardScreen extends StatefulWidget {
  @override
  State<MyWhiteboardScreen> createState() => _MyWhiteboardScreenState();
}

class _MyWhiteboardScreenState extends State<MyWhiteboardScreen> {
  late final SketchController _sketch;

  @override
  void initState() {
    super.initState();
    _sketch = SketchController(currentTool: SketchTool.rectangle);
  }

  @override
  void dispose() {
    _sketch.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        WhiteboardCanvas(sketchController: _sketch),
        Positioned(
          top: 12,
          left: 0,
          right: 0,
          child: Center(child: SketchToolbarRich(controller: _sketch)),
        ),
      ],
    );
  }
}
```

---

## 🏗️ Architecture Overview

```
flowcraft/lib/
├── canvas/
│   ├── whiteboard_canvas.dart   ← Pan/zoom/grid host + sketch layer
│   ├── grid_painter.dart        ← Dot/line background grid
│   └── viewport_transform.dart  ← Screen ⇄ canvas coordinate math
├── core/
│   ├── models/flow_viewport.dart ← Pan/zoom state
│   └── utils/id_generator.dart   ← Unique element ids
└── sketch/
    ├── models/                  ← Elements, styles, tools
    ├── domain/                  ← Geometry, hit-testing, stroke simplify
    ├── state/                   ← SketchController + history
    ├── rendering/               ← Rough/sketchy painters + cache
    ├── interactions/            ← Pointer → element mutation
    ├── serialization/           ← JSON save/load
    └── widgets/                 ← SketchLayer, toolbars, text editor
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

See the [`example/`](example/) directory for a runnable demo app.

---

## 📦 Package Details

| Property       | Value                                                     |
|----------------|-----------------------------------------------------------|
| **Name**       | `flowcraft`                                               |
| **Version**    | `0.1.0`                                                   |
| **SDK**        | Dart ≥ 3.10.0, Flutter ≥ 1.17.0                          |
| **Dependencies** | Flutter SDK only (zero external dependencies)           |
| **License**    | MIT                                                       |

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
