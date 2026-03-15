# FlowCraft — Project Brief for Antigravity

## What Is FlowCraft?

FlowCraft is an **open-source Flutter package** that brings ReactFlow/JS.flow-style interactive node-based flow diagram capabilities to Flutter and Dart. It allows developers to embed a fully interactive visual flow canvas into any Flutter app — where users can create nodes, connect them with animated edges, rename/configure fields, and build visual workflows — all with smooth animations and high performance.

Think of it as **ReactFlow, but for Flutter**.

***

## Why Build This?

Currently, pub.dev has no mature, ReactFlow-equivalent package for Flutter. Existing packages like `flutter_flow_chart` and `flow_canvas` are either abandoned or very limited. FlowCraft fills this gap with: [github](https://github.com/alnitak/flutter_flow_chart)

- Full **interactive canvas** (pan, zoom, drag)
- **Custom node types** with dynamic fields
- **Animated, colorful, curved edges**
- **Zero external dependencies** (pure Flutter SDK only)
- Production-ready **pub.dev package**

***

## Core Concepts

| Term | Meaning |
|---|---|
| **Canvas** | The infinite 2D workspace where everything is rendered |
| **Node** | A box/shape on the canvas representing a step or entity |
| **Edge** | A directed connection line between two nodes |
| **Handle** | A connection point on a node (top, bottom, left, right) |
| **Viewport** | The visible portion of the canvas at any given time |
| **Controller** | The central state manager for nodes, edges, and viewport |

***

## Tech Stack

| Layer | Technology | Why |
|---|---|---|
| Language | Dart 3.x | Flutter native |
| Rendering | `CustomPainter` + Widget Stack | Edges via painter, nodes via widgets |
| State | `ChangeNotifier` + `ListenableBuilder` | Zero deps, reactive, lightweight |
| Animation | `AnimationController` + `Tween` | Native Flutter, smooth 60fps |
| Serialization | `dart:convert` (JSON) | Built-in, no extra packages |
| Testing | `flutter_test` | Standard Flutter testing |
| Docs | `dartdoc` | pub.dev standard |

**No external packages** — FlowCraft itself has zero dependencies beyond the Flutter SDK. This maximizes adoption and avoids version conflicts for end users.

***

## File & Folder Architecture

```
flowcraft/
│
├── lib/
│   ├── flowcraft.dart                  # Main public export barrel file
│   │
│   ├── core/
│   │   ├── models/
│   │   │   ├── flow_node.dart          # Node data model
│   │   │   ├── flow_edge.dart          # Edge data model
│   │   │   ├── flow_handle.dart        # Handle (connection point) model
│   │   │   ├── flow_graph.dart         # Container for all nodes + edges
│   │   │   ├── flow_viewport.dart      # Pan/zoom state model
│   │   │   └── edge_style.dart         # Edge color, thickness, type, animation
│   │   │
│   │   ├── enums/
│   │   │   ├── node_type.dart          # default, input, output, custom
│   │   │   ├── edge_type.dart          # bezier, smoothStep, straight
│   │   │   └── handle_position.dart    # top, bottom, left, right
│   │   │
│   │   └── utils/
│   │       ├── graph_utils.dart        # Node/edge lookup helpers
│   │       ├── math_utils.dart         # Bezier math, offset calculations
│   │       └── serializer.dart         # toJson / fromJson for graph
│   │
│   ├── controller/
│   │   ├── flow_controller.dart        # Central ChangeNotifier — main brain
│   │   ├── history_manager.dart        # Undo/Redo stack (Command Pattern)
│   │   └── selection_manager.dart      # Multi-select, lasso tracking
│   │
│   ├── canvas/
│   │   ├── flow_canvas_widget.dart     # Root public widget — entry point
│   │   ├── canvas_gesture_handler.dart # Pan, zoom, tap, drag gesture logic
│   │   ├── viewport_transform.dart     # Matrix4 transformation for pan/zoom
│   │   ├── grid_painter.dart           # CustomPainter — dot/line background grid
│   │   └── canvas_layer_stack.dart     # Stacks: grid → edges → nodes → overlays
│   │
│   ├── edges/
│   │   ├── edge_painter.dart           # CustomPainter — draws all edges
│   │   ├── bezier_edge.dart            # Cubic bezier path calculation
│   │   ├── smooth_step_edge.dart       # Right-angle smooth path
│   │   ├── straight_edge.dart          # Simple straight line
│   │   ├── animated_edge_painter.dart  # Dashed animated flowing edge
│   │   └── edge_label_widget.dart      # Optional text label on edge midpoint
│   │
│   ├── nodes/
│   │   ├── base_node_widget.dart       # Abstract base — wraps all node types
│   │   ├── default_node_widget.dart    # Rectangle node (most common)
│   │   ├── input_node_widget.dart      # Entry point node (rounded, colored)
│   │   ├── output_node_widget.dart     # Exit point node
│   │   ├── node_header.dart            # Title bar with rename + type badge
│   │   ├── node_fields_panel.dart      # Dynamic key-value fields display
│   │   ├── node_resize_handle.dart     # Corner drag handle for resizing
│   │   └── node_type_registry.dart     # Register custom node builder functions
│   │
│   ├── handles/
│   │   ├── handle_widget.dart          # Circular connection point widget
│   │   └── connection_line_painter.dart # Live line drawn while connecting nodes
│   │
│   ├── interactions/
│   │   ├── node_drag_handler.dart      # Logic for dragging nodes on canvas
│   │   ├── connection_handler.dart     # Logic for drawing new edges between nodes
│   │   ├── selection_box_painter.dart  # Lasso / rubber-band selection box
│   │   └── context_menu_widget.dart    # Right-click popup for node/edge actions
│   │
│   ├── overlays/
│   │   ├── minimap_widget.dart         # Small preview of entire graph
│   │   ├── controls_widget.dart        # Zoom in/out/fit buttons UI
│   │   └── node_toolbar_widget.dart    # Floating toolbar when a node is selected
│   │
│   └── theme/
│       ├── flow_theme.dart             # Full theme data (colors, sizes, fonts)
│       └── default_theme.dart          # Built-in light + dark defaults
│
├── example/
│   ├── lib/
│   │   ├── main.dart                   # Example app entry point
│   │   ├── screens/
│   │   │   ├── basic_flow_screen.dart  # Simple demo with a few nodes
│   │   │   └── advanced_flow_screen.dart # Full demo with all features
│   │   └── custom_nodes/
│   │       └── api_node_widget.dart    # Example of a custom node type
│   └── pubspec.yaml
│
├── test/
│   ├── unit/
│   │   ├── flow_node_test.dart         # Model creation, toJson/fromJson
│   │   ├── flow_edge_test.dart
│   │   ├── flow_controller_test.dart   # addNode, removeNode, undo/redo
│   │   └── serializer_test.dart        # Save/load full graph JSON
│   │
│   └── widget/
│       ├── flow_canvas_widget_test.dart
│       └── node_widget_test.dart
│
├── pubspec.yaml                        # Package metadata — zero dependencies
├── README.md                           # pub.dev landing page
├── CHANGELOG.md
└── LICENSE                             # MIT
```

***

## How the System Works — Data Flow

```
User Action (drag / click / connect)
        │
        ▼
GestureDetector (canvas_gesture_handler.dart)
        │
        ▼
FlowController.method() — e.g. moveNode(), addEdge()
        │
        ├── Updates FlowGraph (nodes/edges list)
        ├── Pushes snapshot to HistoryManager
        └── calls notifyListeners()
                │
                ▼
        ListenableBuilder rebuilds
                │
        ┌───────┴────────┐
        ▼                ▼
EdgePainter         Node Widgets
(CustomPainter)     (Positioned in Stack)
redraws edges       rebuild only changed nodes
```

***

## FlowController — Public API

This is what developers call from outside the package:

```dart
final controller = FlowController();

// Node operations
controller.addNode(type: 'default', position: Offset(100, 200));
controller.removeNode(nodeId);
controller.renameNode(nodeId, 'New Name');
controller.addNodeField(nodeId, key: 'status', value: 'active');
controller.moveNode(nodeId, newPosition);
controller.setNodeType(nodeId, 'decision');

// Edge operations
controller.addEdge(sourceId, targetId, style: EdgeStyle(color: Colors.blue));
controller.removeEdge(edgeId);

// Canvas operations
controller.zoomIn();
controller.zoomOut();
controller.fitView();
controller.selectAll();

// History
controller.undo();
controller.redo();

// Serialization
final json = controller.toJson();
controller.fromJson(json);
```

***

## Public Widget API

The developer only needs **one widget** to embed everything:

```dart
FlowCanvas(
  controller: controller,
  theme: FlowTheme.dark(),
  onNodeTap: (node) { },
  onEdgeTap: (edge) { },
  onNodeAdded: (node) { },
  showMiniMap: true,
  showControls: true,
  gridType: GridType.dots,
  minZoom: 0.1,
  maxZoom: 4.0,
)
```

***

## Node Field System

Each node has a dynamic `data` map — developers can add any fields to any node at runtime. This is how the "add field / rename / type" feature works:

```dart
// Node data structure
FlowNode {
  id: "node_1",
  type: "process",
  label: "Send Email",
  position: Offset(200, 150),
  size: Size(200, 80),
  data: {
    "status": "active",
    "assignee": "Alisher",
    "priority": "high",
    "custom_color": "#FF5733",
  }
}
```

The `node_fields_panel.dart` widget reads this map and renders editable rows for each field inside the node's expanded view.

***

## Edge Style System

```dart
EdgeStyle(
  color: Colors.purple,
  thickness: 2.5,
  edgeType: EdgeType.bezier,
  animated: true,           // flowing dashed animation
  dashPattern: [8, 4],      // dash length, gap length
  arrowStyle: ArrowStyle.filled,
  label: "on success",
)
```

***

## Performance Strategy

| Problem | Solution |
|---|---|
| Too many nodes cause lag | **Viewport culling** — skip rendering nodes outside visible area |
| Edge repaint on every frame | `shouldRepaint()` checks only if edges changed |
| Node rebuilds cascade | Each node wrapped in `RepaintBoundary` |
| Drag event flood | Gesture events **debounced** at 16ms (60fps cap) |
| Large graph JSON | Incremental diff save (only changed nodes/edges) |

***

## Development Phases

### Phase 1 — Foundation (Week 1–2)
- Set up package with `flutter create --template=package flowcraft`
- Implement `FlowNode`, `FlowEdge`, `FlowGraph` models
- Build canvas with pan + zoom + dot grid
- Basic `FlowController` with `ChangeNotifier`

### Phase 2 — Nodes & Edges (Week 3–4)
- Render nodes as positioned widgets on canvas
- Implement handles and live connection drawing
- Draw bezier edges with `CustomPainter`
- Drag nodes on canvas

### Phase 3 — Interactions (Week 5–6)
- Inline node rename (`TextField` overlay)
- Add/remove node fields dynamically
- Animated edges (dashed flow effect)
- Edge color and style customization

### Phase 4 — Advanced Features (Week 7–8)
- Undo/Redo with `HistoryManager`
- Multi-select + group drag
- MiniMap widget
- Save/load graph as JSON

### Phase 5 — Polish & Publish (Week 9–10)
- Full `dartdoc` documentation on every public API
- Write unit + widget tests (aim for >80% coverage)
- Build example app with 2 demo screens
- Publish to pub.dev with README, screenshots, GIF demo

***

## What Antigravity Needs to Deliver

1. **Implement all models** in `core/models/` with full `toJson`/`fromJson` support
2. **Build the canvas engine** — pan, zoom, grid painter
3. **Node widget system** — base node + 3 built-in types + custom type registry
4. **Edge painter** — bezier, smoothStep, straight, animated variants
5. **FlowController** — complete public API with undo/redo
6. **MiniMap + Controls** overlay widgets
7. **Theme system** — light/dark + fully customizable
8. **Example app** — shows off all features visually
9. **Tests** — unit tests for controller and models
10. **pub.dev publish** — with README, CHANGELOG, MIT license, pub points: 140/140

The end result is a **drop-in Flutter package** any developer can add to their app with `flutter pub add flowcraft` and get a full ReactFlow-like canvas in minutes.