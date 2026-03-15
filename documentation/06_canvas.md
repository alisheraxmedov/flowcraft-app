# FlowCraft — Canvas Engine

This document covers the canvas rendering engine, gesture handling, viewport transformations, and background grid system.

---

## FlowCanvas Widget

`FlowCanvas` is the **single root widget** developers embed in their app. It assembles all internal subsystems:

```dart
FlowCanvas(
  controller: controller,
  theme: FlowTheme.dark(),
  showMiniMap: true,
  showControls: true,
  gridType: GridType.dots,
)
```

### Internal Structure

```
FlowCanvas (StatefulWidget)
  └── Container (canvas background color from theme)
        └── CanvasGestureHandler (pan, zoom, tap)
              └── CanvasLayerStack (renders all 5 layers)
```

The widget listens to the `FlowController` and calls `setState()` on every `notifyListeners()` event, triggering a full rebuild of the layer stack.

---

## Canvas Gesture Handler

`CanvasGestureHandler` wraps the canvas content in a `Listener` + `GestureDetector` and processes three types of input:

### Pan (Single Finger / Mouse Drag)

```
onScaleUpdate (pointerCount == 1)
  → delta = currentFocalPoint - lastFocalPoint
  → controller.panBy(delta)
```

### Pinch-to-Zoom (Two Fingers)

```
onScaleUpdate (pointerCount >= 2)
  → newZoom = initialZoom × scale
  → ViewportTransform.zoomAtFocalPoint(viewport, newZoom, focalPoint)
  → controller.setViewport(offset, zoom)
```

The zoom is centered on the **focal point** between the two fingers, so the content under the pinch center stays stationary.

### Mouse Wheel Zoom

```
onPointerSignal (PointerScrollEvent)
  → zoomFactor = scrollDelta > 0 ? -0.05 : +0.05
  → newZoom = currentZoom + zoomFactor
  → ViewportTransform.zoomAtFocalPoint(viewport, newZoom, cursorPosition)
```

### Tap on Canvas Background

```
onTap → clearSelection() + onCanvasTap callback
```

---

## Viewport Transform

`ViewportTransform` handles all coordinate-space conversions:

### Screen ↔ Canvas Conversion

```
┌────────────────────────────┐     ┌────────────────────────────┐
│     Screen Space            │     │     Canvas Space            │
│  (pixels on device)         │ ←→  │  (logical coordinates)      │
│                             │     │                             │
│  screenPoint                │     │  canvasPoint                │
│  = canvas × zoom + offset   │     │  = (screen - offset) / zoom │
└────────────────────────────┘     └────────────────────────────┘
```

### Focal-Point Zoom

The `zoomAtFocalPoint()` method ensures the content under the cursor/finger stays stationary during zoom:

```dart
static FlowViewport zoomAtFocalPoint(
  FlowViewport viewport,
  double newZoom,
  Offset focalPoint,
) {
  // 1. Find canvas point under focal point (before zoom)
  // 2. After zoom, adjust offset so same canvas point is still under focal point
  // 3. Return new viewport with clamped zoom and adjusted offset
}
```

### Matrix4 for Rendering

```dart
Matrix4.identity()
  ..translate(viewport.offset.dx, viewport.offset.dy)
  ..scale(viewport.zoom, viewport.zoom)
```

---

## Canvas Layer Stack

The `CanvasLayerStack` is a `StatefulWidget` with `SingleTickerProviderStateMixin` that manages the animation controller and renders all 5 layers:

```
┌─────────────────────────────────────────────┐
│              ClipRect                        │
│  ┌─────────────────────────────────────────┐│
│  │                Stack                     ││
│  │                                          ││
│  │  Layer 1: Grid (CustomPaint)             ││  GridPainter
│  │  Layer 2: Edges (AnimatedBuilder +       ││  EdgePainter
│  │           CustomPaint)                   ││
│  │  Layer 3: Nodes (Positioned + Scaled)    ││  Node widgets
│  │  Layer 4: Edge Labels (Positioned)       ││  EdgeLabelWidget
│  │  Layer 5: Overlays (Controls, Minimap...)││  Overlay widgets
│  │                                          ││
│  └─────────────────────────────────────────┘│
└─────────────────────────────────────────────┘
```

### Animation Controller

A repeating `AnimationController` (1500ms cycle) drives animated edge dashes:

```dart
_animationController = AnimationController(
  vsync: this,
  duration: const Duration(milliseconds: 1500),
)..repeat();
```

The `AnimatedBuilder` wraps the `EdgePainter` and passes `_animationController.value` to create the flowing effect.

### Node Positioning

Nodes are positioned using screen-space coordinates:

```dart
final screenPos = ViewportTransform.canvasToScreen(node.position, viewport);

Positioned(
  left: screenPos.dx,
  top: screenPos.dy,
  child: Transform.scale(
    scale: viewport.zoom,
    alignment: Alignment.topLeft,
    child: RepaintBoundary(child: nodeWidget),
  ),
)
```

Each node is wrapped in a `RepaintBoundary` to isolate repaints from the 60fps edge animation.

---

## Grid Painter

`GridPainter` is a `CustomPainter` that draws the background pattern.

### Grid Types

| Type            | Description                           |
|-----------------|---------------------------------------|
| `GridType.dots` | Small circular dots at grid points    |
| `GridType.lines`| Thin horizontal and vertical lines   |
| `GridType.none` | No grid background                   |

### Adaptive Behavior

- Grid spacing scales with zoom: `spacing = gridSpacing × zoom`
- Grid opacity adjusts with zoom level for visual comfort
- Grid is skipped entirely when spacing drops below 5px
- Dot radius scales: `dotRadius × zoom.clamp(0.5, 1.5)`

### Repaint Optimization

```dart
@override
bool shouldRepaint(GridPainter oldDelegate) {
  return viewport.offset != oldDelegate.viewport.offset ||
      viewport.zoom != oldDelegate.viewport.zoom ||
      gridType != oldDelegate.gridType ||
      gridColor != oldDelegate.gridColor;
}
```

---

**Previous:** [← Controller API](./05_controller_api.md) · **Next:** [Edges →](./07_edges.md)
