# FlowCraft

**ReactFlow-style interactive node-based flow diagrams for Flutter.**

[![pub.dev](https://img.shields.io/pub/v/flowcraft.svg)](https://pub.dev/packages/flowcraft)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-%E2%89%A51.17.0-02569B.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%E2%89%A53.10.0-0175C2.svg)](https://dart.dev)

FlowCraft is an open-source Flutter package that brings fully interactive, animated, node-based flow diagram capabilities to your Flutter app — **with zero external dependencies**.

```
 ┌──────────────┐          ┌──────────────┐          ┌──────────────┐
 │  ▶ Start      │──bezier─►│  Process     │──step───►│  ■ End        │
 └──────────────┘          └──────────────┘          └──────────────┘
       input                   default                    output
```

---

## ✨ Features

- **Interactive Canvas** — Infinite 2D workspace with pan, zoom, and configurable grid
- **Node System** — 4 built-in types (default, input, output, custom) + custom node registry
- **Edge Routing** — Bezier curves, smooth step (right-angle), and straight lines
- **Animated Edges** — Flowing dashed animations using `PathMetrics`
- **Undo/Redo** — Command Pattern history with configurable depth
- **Serialization** — Full JSON save/load of the entire graph state
- **Multi-Select** — Lasso selection and group drag
- **Overlays** — Minimap, zoom controls, and floating toolbar
- **Theming** — Complete light/dark themes + fully customizable `FlowTheme`
- **Zero Dependencies** — Only Flutter SDK. No external packages.

---

## 🚀 Quick Start

### Install

```bash
flutter pub add flowcraft
```

### Use

```dart
import 'package:flowcraft/flowcraft.dart';

class MyFlowScreen extends StatefulWidget {
  @override
  State<MyFlowScreen> createState() => _MyFlowScreenState();
}

class _MyFlowScreenState extends State<MyFlowScreen> {
  late final FlowController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FlowController();

    final nodeA = _controller.addNode(
      label: 'Start',
      type: NodeType.input,
      position: const Offset(100, 100),
    );

    final nodeB = _controller.addNode(
      label: 'Process',
      position: const Offset(400, 250),
    );

    _controller.addEdge(
      sourceNodeId: nodeA.id,
      targetNodeId: nodeB.id,
      sourceHandleId: nodeA.handles[1].id,
      targetHandleId: nodeB.handles[0].id,
      style: const EdgeStyle(animated: true, color: Color(0xFF6366F1)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FlowCanvas(
        controller: _controller,
        theme: FlowTheme.dark(),
        showMiniMap: true,
        showControls: true,
        gridType: GridType.dots,
      ),
    );
  }
}
```

---

## 🏗️ Architecture Overview

```
flowcraft/lib/
├── core/          ← Data models, enums, utilities
├── controller/    ← FlowController, HistoryManager, SelectionManager
├── canvas/        ← Canvas widget, gestures, viewport, grid
├── edges/         ← Edge routing (Bezier, SmoothStep, Straight) + animation
├── nodes/         ← Node widgets, registry, header, fields
├── handles/       ← Connection point widgets
├── interactions/  ← Drag, connect, select, context menu
├── overlays/      ← Minimap, controls, toolbar
└── theme/         ← Light/dark themes + customization
```

---

## 📚 Documentation

Full documentation is available in the [`documentation/`](documentation/) directory:

| #  | Topic                | Description                                              |
|----|----------------------|----------------------------------------------------------|
| 01 | [Overview](documentation/01_overview.md) | Project overview, core concepts, features, tech stack |
| 02 | [Architecture](documentation/02_architecture.md) | Module structure, dependency graph, data flow, layer stack |
| 03 | [Getting Started](documentation/03_getting_started.md) | Installation, quick start guide, FlowCanvas parameters |
| 04 | [Core Models](documentation/04_core_models.md) | FlowNode, FlowEdge, FlowHandle, EdgeStyle, enums, utils |
| 05 | [Controller API](documentation/05_controller_api.md) | Complete FlowController public API reference |
| 06 | [Canvas](documentation/06_canvas.md) | Canvas engine, gestures, viewport transforms, grid |
| 07 | [Edges](documentation/07_edges.md) | Edge routing algorithms, animated dashes, arrows, labels |
| 08 | [Nodes](documentation/08_nodes.md) | Node types, custom registry, headers, fields, resize |
| 09 | [Interactions](documentation/09_interactions.md) | Drag, connection creation, lasso selection, context menu |
| 10 | [Overlays](documentation/10_overlays.md) | Minimap, zoom controls, node toolbar |
| 11 | [Theming](documentation/11_theming.md) | Light/dark themes, custom themes, FlowTheme properties |
| 12 | [Serialization](documentation/12_serialization.md) | JSON save/load, format specification |
| 13 | [Performance](documentation/13_performance.md) | Optimization strategies and best practices |

---

## 🎨 Theming

FlowCraft includes built-in Light and Dark themes:

```dart
FlowCanvas(controller: controller, theme: FlowTheme.light());
FlowCanvas(controller: controller, theme: FlowTheme.dark());
```

Create custom themes with `copyWith()`:

```dart
final custom = FlowTheme.dark().copyWith(
  canvasColor: const Color(0xFF000000),
  nodeSelectedBorderColor: const Color(0xFFFF6B6B),
);
```

---

## 💾 Serialization

Save and load the entire graph state as JSON:

```dart
// Save
final json = controller.toJson();

// Load
controller.fromJson(json);
```

---

## 🔧 Controller API Highlights

```dart
final controller = FlowController();

// Nodes
controller.addNode(label: 'Step 1', position: Offset(100, 200));
controller.removeNode(nodeId);
controller.renameNode(nodeId, 'New Name');
controller.moveNode(nodeId, Offset(300, 400));

// Edges
controller.addEdge(
  sourceNodeId: sourceId,
  targetNodeId: targetId,
  sourceHandleId: srcHandle,
  targetHandleId: tgtHandle,
);
controller.removeEdge(edgeId);

// Viewport
controller.zoomIn();
controller.zoomOut();
controller.fitView(canvasSize);

// History
controller.undo();
controller.redo();
```

---

## 📦 Package Details

| Property       | Value                                                     |
|----------------|-----------------------------------------------------------|
| **Name**       | `flowcraft`                                               |
| **Version**    | `0.1.0`                                                   |
| **SDK**        | Dart ≥ 3.10.0, Flutter ≥ 1.17.0                          |
| **Dependencies** | Flutter SDK only (zero external dependencies)           |
| **License**    | MIT                                                       |
| **Repository** | [github.com/alisheraxmedov/flowcraft](https://github.com/alisheraxmedov/flowcraft) |
| **Issues**     | [github.com/alisheraxmedov/flowcraft/issues](https://github.com/alisheraxmedov/flowcraft/issues) |

---

## 🤝 Contributing

Contributions are welcome! Please see the [repository](https://github.com/alisheraxmedov/flowcraft) for guidelines.

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
