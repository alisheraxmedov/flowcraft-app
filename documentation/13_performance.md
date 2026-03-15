# FlowCraft — Performance

This document describes the performance optimization strategies implemented in FlowCraft.

---

## Design Goal

FlowCraft targets **smooth 60fps interaction** even with 100+ nodes and edges, on both mobile and desktop platforms.

---

## Optimization Strategies

### 1. RepaintBoundary Isolation

Each node widget is wrapped in a `RepaintBoundary`:

```
Canvas Layer Stack
  └── Edge Painter (repaints at 60fps for animation)
  └── Node Widgets
        ├── RepaintBoundary ─── Node A  ← isolated repaint
        ├── RepaintBoundary ─── Node B
        └── RepaintBoundary ─── Node C
```

**Why:** The edge animation refreshes at 60fps. Without `RepaintBoundary`, every node widget would also repaint on each animation frame. The boundary isolates nodes, so only the `EdgePainter` layer repaints during animation ticks.

---

### 2. shouldRepaint() Guards

All `CustomPainter` implementations use selective repaint:

| Painter              | Repaints When                                         |
|----------------------|-------------------------------------------------------|
| `GridPainter`        | Viewport offset or zoom changes, grid type/color changes |
| `EdgePainter`        | Animation value changes OR controller changes         |
| `AnimatedEdgePainter`| Animation value changes only                         |
| `ConnectionLinePainter`| Start or end point changes                          |
| `SelectionBoxPainter`| Start or end point changes                            |

---

### 3. Zoom-Aware Grid Culling

The grid painter skips rendering when the spacing becomes too small to see:

```dart
final spacing = gridSpacing * zoom;
if (spacing < 5) return;  // Skip grid at extreme zoom-out
```

Grid opacity also scales with zoom to fade gracefully:
```dart
paint.color = gridColor.withAlpha(gridColor.a * zoom.clamp(0.3, 1.0));
```

---

### 4. Efficient Node Lookup

`FlowGraph` uses linear scans with early return for common lookups:

```dart
FlowNode? nodeById(String id) {
  for (final node in nodes) {
    if (node.id == id) return node;  // Early return
  }
  return null;
}
```

For graphs under 1000 nodes, this approach is faster than maintaining a `HashMap` due to lower memory overhead and better cache locality.

---

### 5. Batch Viewport Updates

`setViewport()` combines pan and zoom changes in a single `notifyListeners()` call:

```dart
// Bad: triggers two rebuilds
controller.pan(newOffset);
controller.setZoom(newZoom);

// Good: triggers one rebuild
controller.setViewport(offset: newOffset, zoom: newZoom);
```

---

### 6. History Management

The `HistoryManager` limits snapshots to prevent memory exhaustion:

```dart
HistoryManager(maxHistory: 50)  // Default: 50 undo steps
```

When the limit is exceeded, the oldest snapshot is removed:
```dart
if (_undoStack.length > maxHistory) {
  _undoStack.removeAt(0);
}
```

Graph snapshots use `copyWith()` for deep copying, which creates new lists and maps but shares immutable data (like strings and numbers).

---

### 7. Unmodifiable List Views

The controller exposes node and edge lists as unmodifiable views:

```dart
List<FlowNode> get nodes => List.unmodifiable(_graph.nodes);
List<FlowEdge> get edges => List.unmodifiable(_graph.edges);
```

This prevents accidental external mutations and enables the framework to optimize change detection.

---

### 8. Targeted Animation Scope

The `AnimatedBuilder` wraps only the edge painting layer, not the entire canvas:

```dart
// Only the edge layer rebuilds at 60fps
AnimatedBuilder(
  animation: _animationController,
  builder: (context, child) {
    return CustomPaint(
      painter: EdgePainter(
        controller: widget.controller,
        animationValue: _animationController.value,
      ),
    );
  },
)
```

---

## Performance Summary

```
┌──────────────────────────┬─────────────────────────────────────┐
│ Challenge                │ Solution                            │
├──────────────────────────┼─────────────────────────────────────┤
│ Nodes repaint on anim    │ RepaintBoundary per node            │
│ Edge repaint every frame │ shouldRepaint() guards              │
│ Grid at extreme zoom     │ Skip rendering if spacing < 5px    │
│ Double rebuild on zoom   │ setViewport() single notification   │
│ Memory from undo history │ maxHistory limit (default: 50)      │
│ External list mutation   │ Unmodifiable list views             │
│ Animation scope too wide │ AnimatedBuilder wraps edges only    │
│ Drag delta at high zoom  │ delta / viewport.zoom correction    │
└──────────────────────────┴─────────────────────────────────────┘
```

---

**Previous:** [← Serialization](./12_serialization.md)
