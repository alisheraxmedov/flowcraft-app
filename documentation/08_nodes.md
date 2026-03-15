# FlowCraft — Node System

This document covers the node widget hierarchy, built-in node types, custom node registration, headers, fields, handles, and resize.

---

## Node Widget Architecture

```
                    ┌────────────────────────┐
                    │  CanvasLayerStack       │
                    │  (positions & scales    │
                    │   each node widget)     │
                    └──────────┬─────────────┘
                               │
                               ▼
                    ┌────────────────────────┐
                    │  DefaultBaseNodeWidget  │  ◄── Default renderer
                    │  OR                     │
                    │  Custom nodeBuilder()   │  ◄── Developer override
                    └──────────┬─────────────┘
                               │
              ┌────────────────┼────────────────┐
              ▼                ▼                ▼
     ┌──────────────┐ ┌──────────────┐ ┌──────────────┐
     │  NodeHeader   │ │ NodeFields   │ │ HandleWidget │
     │  (label+badge)│ │  Panel       │ │ (connection  │
     │              │ │ (key-value)  │ │  points × 4) │
     └──────────────┘ └──────────────┘ └──────────────┘
```

---

## Built-in Node Types

### DefaultNode

Standard rectangular node with white background, gray border, and header.

```
┌────────────────────────────┐
│  ▫  Node Label             │  ← NodeHeader (gray bg)
├────────────────────────────┤
│  status: active            │  ← NodeFieldsPanel (if data exists)
│  assignee: Alisher         │
└────────────────────────────┘
 ○ (T)   ○ (B)   ○ (L)  ○ (R)  ← Handles
```

### InputNode

Entry-point node with green accent color and rounded top corners.

```
╭────────────────────────────╮
│        ▶ Start              │  Green background (#E8F5E9)
╰────────────────────────────╯  Green border (#A5D6A7)
```

### OutputNode

Exit-point node with red accent color and rounded bottom corners.

```
┌────────────────────────────┐
│        ■ End                │  Red background (#FFEBEE)
╰────────────────────────────╯  Red border (#EF9A9A)
```

---

## DefaultBaseNodeWidget

The primary node renderer used when no custom `nodeBuilder` is provided. Features:

| Feature              | Description                                                |
|----------------------|------------------------------------------------------------|
| **Selection**        | Blue border highlight when selected (`#2196F3`)            |
| **Drag**             | Captures `onPanStart` / `onPanUpdate` for drag-to-move    |
| **Handles**          | Renders 4 `HandleWidget` circles (top/bottom/left/right)  |
| **Delete Button**    | Red circle `×` button appearing on selection               |
| **Shadow**           | Elevated shadow (increases when selected)                  |
| **Theme Support**    | Reads colors from `FlowTheme` if provided                  |

### Drag Behavior

```dart
onPanStart: (_) {
  controller.startNodeDrag(node.id);   // Save undo snapshot
  controller.selection.selectNode(node.id);
},
onPanUpdate: (details) {
  final delta = details.delta / controller.viewport.zoom;  // Zoom-aware
  controller.moveNodeBy(node.id, delta);
},
```

---

## Node Header

`NodeHeader` displays the node label and an optional type badge:

```
┌────────────────────────────────────┐
│  Send Email           [custom]     │
└────────────────────────────────────┘
    ↑ label              ↑ type badge (if not defaultNode)
```

Header background colors by type:

| NodeType     | Color                   |
|-------------|-------------------------|
| `defaultNode`| `#F5F5F5` (light gray) |
| `input`      | `#C8E6C9` (light green)|
| `output`     | `#FFCDD2` (light red)  |
| `custom`     | `#E1BEE7` (light purple)|

---

## Node Fields Panel

`NodeFieldsPanel` renders key-value data from the node's `data` map:

```dart
final node = FlowNode(
  data: {
    'status': 'active',
    'assignee': 'Alisher',
    'priority': 'high',
  },
);
```

Renders as:

```
  status: active
  assignee: Alisher
  priority: high
```

Fields can be added/removed at runtime via:
```dart
controller.addNodeField(nodeId, key: 'email', value: 'test@mail.com');
controller.removeNodeField(nodeId, 'email');
```

---

## Node Resize Handle

`NodeResizeHandle` renders a corner drag handle for resizing nodes:

```
                         ┌──┐
                         │╲ │  ← bottom-right corner
                         └──┘
```

It captures `onPanUpdate` and passes the delta to the resize callback:
```dart
NodeResizeHandle(
  onResize: (delta) {
    controller.resizeNode(nodeId, Size(
      currentWidth + delta.dx,
      currentHeight + delta.dy,
    ));
  },
)
```

---

## Custom Node Types (NodeTypeRegistry)

Developers can register custom node widget builders for application-specific node types:

```dart
final registry = NodeTypeRegistry();

// Register a custom node type
registry.register('apiNode', (controller, node) {
  return MyApiNodeWidget(controller: controller, node: node);
});

// Check if registered
registry.hasBuilder('apiNode');        // true
registry.registeredTypes;              // {'apiNode'}

// Get builder
final builder = registry.builderFor('apiNode');

// Unregister
registry.unregister('apiNode');
```

To use custom nodes with `FlowCanvas`, provide a `nodeBuilder`:

```dart
FlowCanvas(
  controller: controller,
  nodeBuilder: (controller, index) {
    final node = controller.nodes[index];
    final builder = registry.builderFor(node.type.name);
    if (builder != null) {
      return builder(controller, node);
    }
    return DefaultBaseNodeWidget(controller: controller, node: node);
  },
)
```

---

## Handle Widget

`HandleWidget` renders a small circular connection point on the node border:

```
     ○ ← HandleWidget (10px circle, white fill, blue border)
```

Handle positioning:

| HandlePosition | Location on Node                        |
|----------------|-----------------------------------------|
| `top`          | `(width/2, 0)` — top center             |
| `bottom`       | `(width/2, height)` — bottom center     |
| `left`         | `(0, height/2)` — left center           |
| `right`        | `(width, height/2)` — right center      |

---

**Previous:** [← Edges](./07_edges.md) · **Next:** [Interactions →](./09_interactions.md)
