# FlowCraft — Overview

## What Is FlowCraft?

**FlowCraft** is an open-source Flutter package that provides **ReactFlow-style interactive node-based flow diagrams** for Flutter and Dart applications. It allows developers to embed a fully interactive visual flow canvas where users can create nodes, connect them with animated edges, and build visual workflows — all with smooth 60fps animations and high performance.

> Think of it as **ReactFlow, but built natively for Flutter**.

---

## Why FlowCraft?

The Flutter ecosystem currently lacks a mature, feature-complete equivalent to [ReactFlow](https://reactflow.dev/) (the popular JavaScript library). Existing packages on pub.dev are either abandoned, incomplete, or limited in scope. FlowCraft fills this gap with a production-ready solution:

| Gap Identified                       | FlowCraft Solution                        |
|--------------------------------------|-------------------------------------------|
| No interactive canvas for Flutter    | Full pan/zoom/drag infinite canvas        |
| No node-based diagrams               | Custom node types with dynamic fields     |
| No animated edge routing             | Bezier, SmoothStep, Straight + animations |
| Dependency-heavy packages            | **Zero external dependencies**            |
| No undo/redo support                 | Command Pattern history manager           |
| No serialization                     | Full JSON save/load                       |

---

## Core Concepts

FlowCraft is built around six fundamental concepts:

```
┌─────────────────────────────────────────────────────────────────┐
│                        CANVAS (Viewport)                        │
│                                                                 │
│    ┌──────────────┐        Edge           ┌──────────────┐     │
│    │              │  ─────────────────►    │              │     │
│    │    Node A     │  (Bezier/Step/Line)   │    Node B     │     │
│    │              │                        │              │     │
│    └──────┬───────┘                        └──────────────┘     │
│           │                                                     │
│       [Handles]  ◄── Connection points (top/bottom/left/right)  │
│                                                                 │
│   Controller  ◄── Central state manager for all operations      │
└─────────────────────────────────────────────────────────────────┘
```

| Term           | Description                                                          |
|----------------|----------------------------------------------------------------------|
| **Canvas**     | The infinite 2D workspace where nodes and edges are rendered         |
| **Node**       | A visual element on the canvas representing a step, entity, or action|
| **Edge**       | A directed connection line drawn between two nodes                   |
| **Handle**     | A connection point on a node's border (top, bottom, left, right)     |
| **Viewport**   | The currently visible portion of the canvas (pan offset + zoom level)|
| **Controller** | The central state manager that orchestrates all graph operations     |

---

## Key Features

### Interactive Canvas
- Infinite 2D workspace with pan, zoom, and scroll support
- Configurable background grid (dots, lines, or none)
- Pinch-to-zoom and mouse wheel zoom with focal-point centering
- Fit-to-view to auto-center all content

### Node System
- **Four built-in node types**: Default, Input, Output, Custom
- Dynamic key-value data fields on every node
- Inline label editing and type badges
- Drag-to-move with zoom-aware delta calculation
- Corner resize handles
- Custom node type registry for developer-defined widgets

### Edge Routing
- **Three routing algorithms**: Cubic Bezier, Smooth Step (right-angle), Straight
- Animated flowing dashed edges using `PathMetrics`
- Configurable color, thickness, dash patterns, and arrow styles
- Optional text labels at edge midpoints

### State Management
- `ChangeNotifier`-based reactive architecture (zero external deps)
- Undo/Redo with configurable history depth (Command Pattern)
- Multi-select with lasso/rubber-band selection
- Full JSON serialization and deserialization

### Overlays
- Minimap for graph overview and navigation
- Zoom controls (zoom in, zoom out, fit view)
- Floating toolbar on node selection
- Context menu for right-click actions

### Theming
- Complete theme system covering canvas, nodes, edges, handles, and overlays
- Built-in **Light** and **Dark** themes
- Fully customizable via `FlowTheme.copyWith()`

---

## Technology Stack

| Layer          | Technology                            | Rationale                              |
|----------------|---------------------------------------|----------------------------------------|
| Language       | Dart 3.x                             | Flutter native                         |
| Rendering      | `CustomPainter` + Widget Stack       | Edges via painter, nodes via widgets   |
| State          | `ChangeNotifier` + `ListenableBuilder`| Zero deps, reactive, lightweight       |
| Animation      | `AnimationController` + `PathMetrics`| Native Flutter, smooth 60fps           |
| Serialization  | `dart:convert` (JSON)                | Built-in, no extra packages            |
| Testing        | `flutter_test`                       | Standard Flutter test framework        |

> **Zero external dependencies** — FlowCraft depends only on the Flutter SDK.
> This maximizes adoption and eliminates version conflicts for consumers.

---

## License

FlowCraft is released under the **MIT License**.

---

**Next:** [Architecture →](./02_architecture.md)
