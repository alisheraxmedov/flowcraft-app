# FlowCraft — Getting Started

This guide walks you through installing FlowCraft and displaying your first interactive flow diagram.

---

## Prerequisites

| Requirement       | Minimum Version |
|-------------------|-----------------|
| Flutter SDK       | ≥ 1.17.0        |
| Dart SDK          | ≥ 3.10.0        |

---

## Installation

### Step 1: Add the Dependency

Add `flowcraft` to your `pubspec.yaml`:

```yaml
dependencies:
  flowcraft: ^0.1.0
```

Or install via the command line:

```bash
flutter pub add flowcraft
```

### Step 2: Import the Package

```dart
import 'package:flowcraft/flowcraft.dart';
```

This single import gives you access to **all** public classes, widgets, and utilities.

---

## Quick Start — Minimal Example

The simplest way to use FlowCraft is to create a `FlowController`, add some nodes, and embed the `FlowCanvas` widget:

```dart
import 'package:flutter/material.dart';
import 'package:flowcraft/flowcraft.dart';

class BasicFlowScreen extends StatefulWidget {
  const BasicFlowScreen({super.key});

  @override
  State<BasicFlowScreen> createState() => _BasicFlowScreenState();
}

class _BasicFlowScreenState extends State<BasicFlowScreen> {
  late final FlowController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FlowController();

    // Add two nodes
    final nodeA = _controller.addNode(
      label: 'Start',
      type: NodeType.input,
      position: const Offset(100, 100),
    );

    final nodeB = _controller.addNode(
      label: 'Process',
      position: const Offset(400, 250),
    );

    // Connect them with an edge
    _controller.addEdge(
      sourceNodeId: nodeA.id,
      targetNodeId: nodeB.id,
      sourceHandleId: nodeA.handles[1].id, // bottom handle
      targetHandleId: nodeB.handles[0].id, // top handle
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
        theme: FlowTheme.light(),
        showMiniMap: true,
        showControls: true,
        gridType: GridType.dots,
      ),
    );
  }
}
```

This produces an interactive canvas with:
- Two connected nodes
- A dot-grid background
- Pan, zoom, and scroll support
- Zoom controls in the bottom-left
- A minimap in the bottom-right

---

## Understanding the Result

```
┌─────────────────────────────────────────────────┐
│  · · · · · · · · · · · · · · · · · · · · · · ·  │
│  · · ┌──────────────┐ · · · · · · · · · · · ·  │
│  · · │  ▶ Start      │ · · · · · · · · · · · ·  │
│  · · └──────┬───────┘ · · · · · · · · · · · ·  │
│  · · · · · ·│· · · · · · · · · · · · · · · · ·  │
│  · · · · · ·│  (Bezier Edge) · · · · · · · · ·  │
│  · · · · · ·│· · · · · · · · · · · · · · · · ·  │
│  · · · · · ·▼· · · · · · · · · · · · · · · · ·  │
│  · · · · ┌──────────────┐ · · · · · · · · · ·  │
│  · · · · │  Process      │ · · · · · · · · · ·  │
│  · · · · └──────────────┘ · · · · · · · · · ·  │
│  · · · · · · · · · · · · · · · · · · · · · · ·  │
│ [+]                                    ┌──────┐ │
│ [−]                                    │minimap│ │
│ [⊡]                                    └──────┘ │
└─────────────────────────────────────────────────┘
```

---

## FlowCanvas Widget — Key Parameters

```dart
FlowCanvas(
  controller: controller,        // Required: FlowController instance
  theme: FlowTheme.dark(),       // Optional: visual theme (light/dark/custom)
  showMiniMap: true,             // Optional: show minimap overlay
  showControls: true,            // Optional: show zoom controls
  gridType: GridType.dots,       // Optional: dots, lines, or none
  minZoom: 0.1,                  // Optional: minimum zoom level
  maxZoom: 4.0,                  // Optional: maximum zoom level
  onNodeTap: (nodeId) { },       // Optional: callback on node tap
  onEdgeTap: (edgeId) { },       // Optional: callback on edge tap
  onCanvasTap: () { },           // Optional: callback on canvas background tap
  nodeBuilder: (ctrl, i) => ..., // Optional: custom node widget builder
  overlays: [MyCustomOverlay()], // Optional: additional overlay widgets
)
```

---

## What's Next?

| Topic                                          | Document                                     |
|------------------------------------------------|-----------------------------------------------|
| Learn about data models                        | [Core Models](./04_core_models.md)            |
| Explore the full controller API                | [Controller API](./05_controller_api.md)      |
| Understand edge routing and animation          | [Edges](./07_edges.md)                        |
| Customize the look and feel                    | [Theming](./11_theming.md)                    |
| Save and load graphs                           | [Serialization](./12_serialization.md)        |

---

**Previous:** [← Architecture](./02_architecture.md) · **Next:** [Core Models →](./04_core_models.md)
