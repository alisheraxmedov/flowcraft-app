# FlowCraft — Architecture

This document describes the system architecture, module structure, and data flow of the FlowCraft package.

---

## Module Overview

FlowCraft is organized into **9 clearly separated modules**, each with a single responsibility:

```
flowcraft/lib/
├── flowcraft.dart              ◄── Barrel file (public API exports)
│
├── core/                       ◄── Data layer (models, enums, utilities)
│   ├── enums/
│   ├── models/
│   └── utils/
│
├── controller/                 ◄── Business logic layer
│   ├── flow_controller.dart
│   ├── history_manager.dart
│   └── selection_manager.dart
│
├── canvas/                     ◄── Canvas rendering engine
│   ├── flow_canvas_widget.dart
│   ├── canvas_gesture_handler.dart
│   ├── viewport_transform.dart
│   ├── grid_painter.dart
│   └── canvas_layer_stack.dart
│
├── edges/                      ◄── Edge routing and painting
│   ├── edge_painter.dart
│   ├── animated_edge_painter.dart
│   ├── bezier_edge.dart
│   ├── smooth_step_edge.dart
│   ├── straight_edge.dart
│   └── edge_label_widget.dart
│
├── nodes/                      ◄── Node widgets and registry
│   ├── base_node_widget.dart
│   ├── default_node_widget.dart
│   ├── input_node_widget.dart
│   ├── output_node_widget.dart
│   ├── node_header.dart
│   ├── node_fields_panel.dart
│   ├── node_resize_handle.dart
│   └── node_type_registry.dart
│
├── handles/                    ◄── Connection point widgets
│   ├── handle_widget.dart
│   └── connection_line_painter.dart
│
├── interactions/               ◄── User interaction handlers
│   ├── node_drag_handler.dart
│   ├── connection_handler.dart
│   ├── selection_box_painter.dart
│   └── context_menu_widget.dart
│
├── overlays/                   ◄── Floating UI overlays
│   ├── minimap_widget.dart
│   ├── controls_widget.dart
│   └── node_toolbar_widget.dart
│
└── theme/                      ◄── Visual theme system
    ├── flow_theme.dart
    └── default_theme.dart
```

**Total: 38 Dart files** across 9 modules + 1 barrel file.

---

## Dependency Graph

Modules follow a strict **unidirectional dependency flow**. Lower layers never depend on higher layers:

```
                    ┌─────────────────┐
                    │   flow_canvas    │  ◄── Entry point widget
                    │    (canvas/)     │
                    └────────┬────────┘
                             │ uses
              ┌──────────────┼──────────────┐
              ▼              ▼              ▼
       ┌────────────┐ ┌───────────┐ ┌──────────────┐
       │  overlays/  │ │  edges/   │ │   nodes/     │
       └──────┬─────┘ └─────┬─────┘ └──────┬───────┘
              │             │              │
              │      ┌──────┴──────┐       │
              │      │  handles/   │       │
              │      └──────┬──────┘       │
              │             │              │
              ▼             ▼              ▼
         ┌──────────────────────────────────────┐
         │         interactions/                 │
         └────────────────┬─────────────────────┘
                          │
                          ▼
                ┌──────────────────┐
                │   controller/    │  ◄── Central brain
                └────────┬────────┘
                         │
                         ▼
                ┌──────────────────┐
                │     core/        │  ◄── Pure data (no Flutter imports in models)
                │  models/enums/   │
                │    utils/        │
                └──────────────────┘
```

---

## Data Flow

The following diagram shows how a user action propagates through the system:

```
  User Action (drag / click / connect / zoom)
          │
          ▼
  ┌─────────────────────────────────────┐
  │   CanvasGestureHandler              │  Captures raw gestures
  │   (pan, pinch-zoom, tap, scroll)    │
  └──────────────┬──────────────────────┘
                 │
                 ▼
  ┌─────────────────────────────────────┐
  │   FlowController                    │  Central state manager
  │   ├── Updates FlowGraph (nodes/edges)│
  │   ├── Pushes snapshot → HistoryManager│
  │   └── Calls notifyListeners()       │
  └──────────────┬──────────────────────┘
                 │
                 ▼
  ┌─────────────────────────────────────┐
  │   ListenableBuilder triggers rebuild│
  └──────┬──────────────────┬───────────┘
         │                  │
         ▼                  ▼
  ┌──────────────┐   ┌──────────────────┐
  │  EdgePainter │   │   Node Widgets   │
  │ (CustomPaint)│   │  (Positioned in  │
  │ redraws edges│   │   Stack)         │
  └──────────────┘   └──────────────────┘
```

---

## Canvas Layer Stack

The canvas renders content in **5 ordered layers** (bottom to top):

```
  Layer 5 (Top)   ─►  Overlays (minimap, zoom controls, toolbar)
  Layer 4         ─►  Edge Labels (widget-based text labels)
  Layer 3         ─►  Node Widgets (positioned, scaled, with RepaintBoundary)
  Layer 2         ─►  Edge Painter (CustomPainter with animation)
  Layer 1 (Bottom)─►  Grid Painter (dots / lines / none)
```

Each layer is rendered within a `Stack` widget. Edge painting and grid painting use `CustomPainter` for performance. Node widgets are standard Flutter widgets positioned via `Positioned` and scaled via `Transform.scale`.

---

## Coordinate System

FlowCraft uses two coordinate spaces:

| Space         | Description                                            |
|---------------|--------------------------------------------------------|
| **Canvas**    | The logical infinite coordinate system where nodes live |
| **Screen**    | The pixel coordinates visible on the user's device      |

Conversion between the two spaces is handled by `ViewportTransform`:

```dart
// Screen → Canvas
canvasPoint = (screenPoint - viewport.offset) / viewport.zoom

// Canvas → Screen
screenPoint = canvasPoint * viewport.zoom + viewport.offset
```

The `Matrix4` transformation used for rendering:
```
Matrix4.identity()
  ..translate(viewport.offset.dx, viewport.offset.dy)
  ..scale(viewport.zoom, viewport.zoom)
```

---

## Design Principles

1. **Zero Dependencies** — Only Flutter SDK. No external packages.
2. **Separation of Concerns** — Clear module boundaries. Models know nothing about widgets.
3. **Reactive State** — `ChangeNotifier` drives all UI updates through `notifyListeners()`.
4. **Immutability Where Possible** — All models support `copyWith()` for safe state snapshots.
5. **Performance First** — `RepaintBoundary`, `shouldRepaint()` guards, and viewport culling.

---

**Previous:** [← Overview](./01_overview.md) · **Next:** [Getting Started →](./03_getting_started.md)
