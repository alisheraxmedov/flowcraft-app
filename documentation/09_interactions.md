# FlowCraft — Interactions

This document covers user interaction systems: node dragging, edge connection creation, lasso selection, and context menus.

---

## Node Drag Handler

`NodeDragHandler` provides reusable drag logic for moving nodes on the canvas.

### Single Node Drag

```
  onDragStart()
    │
    ├── controller.startNodeDrag(nodeId)   ← Save undo snapshot
    └── controller.selection.selectNode(nodeId)
    
  onDragUpdate(delta)
    │
    └── scaledDelta = delta / controller.viewport.zoom
        controller.moveNodeBy(nodeId, scaledDelta)
```

The delta is divided by the current zoom level so that the node moves at the same visual speed regardless of zoom.

### Group Drag (Multi-Select)

When multiple nodes are selected, `onGroupDragUpdate` moves **all selected nodes** by the same delta:

```dart
void onGroupDragUpdate(Offset delta) {
  final scaledDelta = delta / controller.viewport.zoom;
  for (final selectedId in controller.selection.selectedNodeIds) {
    controller.moveNodeBy(selectedId, scaledDelta);
  }
}
```

---

## Connection Handler

`ConnectionHandler` manages the state of an **in-progress edge connection** drag from one handle to another.

### Connection Flow

```
  Step 1: User drags from a handle
  ┌────────────────────────────────────┐
  │  startConnection(                  │
  │    nodeId: sourceNode.id,          │
  │    handleId: sourceHandle.id,      │
  │  )                                 │
  └────────────────┬───────────────────┘
                   │
  Step 2: Follow cursor               
  ┌────────────────┴───────────────────┐
  │  updateEndPoint(screenPosition)    │  ← Called on every drag update
  └────────────────┬───────────────────┘
                   │
  Step 3a: Drop on target handle       
  ┌────────────────┴───────────────────┐
  │  completeConnection(               │
  │    targetNodeId: ...,              │
  │    targetHandleId: ...,            │
  │    style: EdgeStyle(...),          │  ← Optional custom style
  │  )                                 │
  │  Returns: true (success) / false   │
  └────────────────────────────────────┘
  
  Step 3b: Drop on empty space         
  ┌────────────────────────────────────┐
  │  cancelConnection()                │  ← Clears state, no edge created
  └────────────────────────────────────┘
```

### Connection Line Preview

During a connection drag, `ConnectionLinePainter` draws a **dashed bezier preview line** from the source handle to the cursor position:

```
  Source ○╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌╌ 🖱️ cursor
```

The preview line auto-computes bezier control points based on the horizontal distance.

---

## Selection Box (Lasso)

`SelectionBoxPainter` draws a rubber-band rectangle for multi-selecting nodes:

```
  ┌ ─ ─ ─ ─ ─ ─ ─ ─ ┐
  │                   │  Blue fill (#222196F3, semi-transparent)
  │  ┌──────┐         │  Blue border (#2196F3, 1px)
  │  │Node A│  ┌────┐ │
  │  └──────┘  │ B  │ │
  │            └────┘ │
  └ ─ ─ ─ ─ ─ ─ ─ ─ ┘
    ↑ startPoint        ↑ endPoint (follows cursor)
```

All nodes within the rectangle are added to the selection.

---

## Context Menu

`ContextMenuWidget` displays a floating action menu at a given screen position:

```
  ┌──────────────┐
  │  Rename      │
  │  Duplicate   │
  │  Delete  ← red│
  └──────────────┘
```

### API

```dart
ContextMenuWidget(
  position: tapPosition,
  items: [
    ContextMenuItem(label: 'Rename', onTap: () => ...),
    ContextMenuItem(label: 'Delete', onTap: () => ..., isDestructive: true),
  ],
  onDismiss: () => setState(() => _showMenu = false),
)
```

Destructive items are displayed in red (`#F44336`). The menu auto-dismisses when an item is tapped.

---

**Previous:** [← Nodes](./08_nodes.md) · **Next:** [Overlays →](./10_overlays.md)
