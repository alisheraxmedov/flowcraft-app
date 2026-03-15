# FlowCraft — Controller API Reference

The `FlowController` is the **central brain** of FlowCraft. It extends `ChangeNotifier` and manages all graph state, viewport state, selection, history, and serialization.

---

## Creating a Controller

```dart
final controller = FlowController(
  graph: FlowGraph(),              // Optional: initial graph
  viewport: const FlowViewport(),  // Optional: initial viewport
  maxHistory: 50,                  // Optional: max undo steps (default: 50)
);
```

**Always dispose the controller** when it's no longer needed:
```dart
controller.dispose();
```

---

## Read-Only Getters

| Getter            | Type                  | Description                              |
|-------------------|-----------------------|------------------------------------------|
| `graph`           | `FlowGraph`           | The current graph state                  |
| `nodes`           | `List<FlowNode>`      | Unmodifiable list of all nodes           |
| `edges`           | `List<FlowEdge>`      | Unmodifiable list of all edges           |
| `viewport`        | `FlowViewport`        | Current pan/zoom state                   |
| `canUndo`         | `bool`                | Whether undo is available                |
| `canRedo`         | `bool`                | Whether redo is available                |
| `selection`       | `SelectionManager`    | Access to selection state                |

---

## Node Operations

### Add a Node

```dart
FlowNode addNode({
  NodeType type = NodeType.defaultNode,
  String label = 'Node',
  Offset position = Offset.zero,
  Size size = const Size(180, 60),
  Map<String, dynamic>? data,
  List<FlowHandle>? handles,
})
```

Returns the created `FlowNode`. Automatically pushes to undo history.

### Remove a Node

```dart
void removeNode(String nodeId)
```

Removes the node **and all connected edges**. Deselects the node if selected.

### Move a Node

```dart
void moveNode(String nodeId, Offset newPosition)    // Absolute position
void moveNodeBy(String nodeId, Offset delta)          // Relative delta
void startNodeDrag(String nodeId)                     // Saves undo snapshot
```

> **Important:** Call `startNodeDrag()` before a drag sequence to save the undo snapshot once, then call `moveNodeBy()` for each drag update.

### Rename a Node

```dart
void renameNode(String nodeId, String newLabel)
```

### Set Node Type

```dart
void setNodeType(String nodeId, NodeType newType)
```

### Resize a Node

```dart
void resizeNode(String nodeId, Size newSize)
```

### Node Data Fields

```dart
void addNodeField(String nodeId, {required String key, dynamic value})
void removeNodeField(String nodeId, String key)
```

---

## Edge Operations

### Add an Edge

```dart
FlowEdge? addEdge({
  required String sourceNodeId,
  required String targetNodeId,
  required String sourceHandleId,
  required String targetHandleId,
  EdgeStyle? style,
})
```

Returns the created `FlowEdge`, or `null` if validation fails. Validation checks:
- No self-connections (source == target)
- No duplicate edges (same handle pair)
- Both source and target nodes exist

### Remove an Edge

```dart
void removeEdge(String edgeId)
```

### Update Edge Style

```dart
void updateEdgeStyle(String edgeId, EdgeStyle newStyle)
```

---

## Viewport Operations

```dart
void pan(Offset newOffset)                             // Set absolute pan offset
void panBy(Offset delta)                               // Add delta to current pan
void setZoom(double zoom)                              // Set zoom level (clamped)
void setViewport({Offset? offset, double? zoom})       // Set both in one call
void zoomIn({double factor = 0.1})                     // Zoom in by factor
void zoomOut({double factor = 0.1})                    // Zoom out by factor
void fitView(Size canvasSize)                          // Fit all nodes in view
```

> **Best Practice:** Use `setViewport()` instead of separate `pan()` + `setZoom()` calls to avoid triggering two rebuilds.

---

## Selection Operations

The controller exposes a `SelectionManager` via the `selection` property:

```dart
// Single selection
controller.selection.selectNode(nodeId);
controller.selection.selectEdge(edgeId);

// Toggle (for multi-select with Ctrl/Cmd)
controller.selection.toggleNodeSelection(nodeId);
controller.selection.toggleEdgeSelection(edgeId);

// Multi-select
controller.selection.selectNodes(nodeIds, addToSelection: true);
controller.selection.selectAll(nodeIds, edgeIds);

// Clear
controller.selection.clearSelection();

// Query
controller.selection.isNodeSelected(nodeId);    // bool
controller.selection.isEdgeSelected(edgeId);    // bool
controller.selection.hasSelection;              // bool
controller.selection.selectedNodeIds;           // Set<String>
controller.selection.selectedEdgeIds;           // Set<String>
```

### Controller-Level Selection Helpers

```dart
controller.selectAll();           // Select all nodes and edges
controller.deleteSelection();     // Remove all selected nodes and edges
```

---

## History (Undo/Redo)

```dart
controller.undo();      // Revert to previous state
controller.redo();      // Reapply last undone state
controller.canUndo;     // Check availability
controller.canRedo;     // Check availability
```

History is automatically managed — every mutation method calls `_pushHistory()` before changing state. The undo stack stores deep copies of `FlowGraph` and is limited by `maxHistory` (default: 50).

```
  ┌────────────────────────────────────────────────────┐
  │  Undo Stack                     Redo Stack         │
  │  ┌─────┐ ┌─────┐ ┌─────┐      ┌─────┐            │
  │  │ S₁  │ │ S₂  │ │ S₃  │      │ S₄  │            │
  │  └─────┘ └─────┘ └─────┘      └─────┘            │
  │  oldest ──────► newest         most recent         │
  │                                                    │
  │  undo() : Pop S₃ → Redo, push current → Undo      │
  │  redo() : Pop S₄ → Undo, push current → Redo      │
  └────────────────────────────────────────────────────┘
```

---

## Serialization

```dart
// To/from JSON string
String json = controller.toJson();
controller.fromJson(json);

// To/from Map
Map<String, dynamic> map = controller.toMap();
controller.fromMap(map);
```

Loading state pushes the current state to undo history first, so the load itself is undoable.

---

## Clear All

```dart
controller.clear();  // Resets graph, viewport, selection, and history
```

---

## Lifecycle

```
  FlowController()
       │
       ├── Use: addNode(), addEdge(), moveNode(), etc.
       │
       ├── Listen: controller.addListener(callback)
       │
       └── Dispose: controller.dispose()
```

The controller also disposes its internal `SelectionManager` when `dispose()` is called.

---

**Previous:** [← Core Models](./04_core_models.md) · **Next:** [Canvas →](./06_canvas.md)
