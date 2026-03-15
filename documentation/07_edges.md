# FlowCraft — Edge Routing & Animation

This document covers the edge rendering pipeline, routing algorithms, animated dashes, arrows, and labels.

---

## Edge Rendering Pipeline

Every edge goes through a 5-step rendering pipeline inside `EdgePainter`:

```
  ┌─────────────────────────────────────────────────────────┐
  │  For each edge in controller.edges:                      │
  │                                                          │
  │  1. Resolve source/target nodes and handles              │
  │  2. Compute handle offsets (canvas → screen space)       │
  │  3. Build the Path (bezier / smoothStep / straight)      │
  │  4. Draw the path (solid / dashed / animated)            │
  │  5. Draw the arrowhead at the target end                 │
  └─────────────────────────────────────────────────────────┘
```

---

## Routing Algorithms

### Bezier Edge

A smooth cubic Bézier curve computed using `Path.cubicTo()`:

```
  Source ●
         \
          \  cp1 (control point 1)
           \
            ╲
             ╲
              ╲  cp2 (control point 2)
               \
                \
         Target  ●
```

Control points are calculated based on handle directions:

```dart
controlDistance = max(distance × 0.5, 50.0)

cp1 = source + sourceDirection × controlDistance
cp2 = target + targetDirection × controlDistance
```

Handle directions:
| Handle   | Direction Vector |
|----------|-----------------|
| `top`    | `(0, -1)`       |
| `bottom` | `(0, +1)`       |
| `left`   | `(-1, 0)`       |
| `right`  | `(+1, 0)`       |

---

### Smooth Step Edge

Right-angle path segments with **rounded corners** at the bends:

```
  Source ●
         │
         │ (vertical segment)
         │
         ├─────────────────┐  ← rounded corner
                           │
                           │ (vertical segment)
                           │
                    Target ●
```

The algorithm:
1. Computes intermediate **waypoints** based on source/target handle positions
2. Draws line segments between waypoints
3. Adds `quadraticBezierTo` curves at each corner for smooth rounding

Corner radius is clamped to half the minimum segment length to prevent overlap.

---

### Straight Edge

A direct line from source to target:

```
  Source ●─────────────────────► Target ●
```

---

## Animated Dashed Edges

When `EdgeStyle.animated == true`, edges display a **flowing dashed pattern** that moves along the path over time.

### How It Works

1. The `CanvasLayerStack` runs a repeating `AnimationController` (0.0 → 1.0 over 1500ms)
2. The animation value is passed to `EdgePainter`
3. For animated edges, `PathMetrics` extracts dash sub-paths with a shifting offset

```
  Animation cycle (0 → 1):

  Frame 0:   ── ── ── ── ── ── ──►
  Frame 1:    ── ── ── ── ── ── ──►
  Frame 2:     ── ── ── ── ── ── ──►
  Frame 3:      ── ── ── ── ── ── ──►
  ...repeats...
```

### Implementation

```dart
void _drawAnimatedDashes(Canvas canvas, Path path, Paint paint,
    List<double> dashPattern, double zoom) {
  final dashLen = dashPattern[0] * zoom;   // e.g. 8.0 * zoom
  final gapLen  = dashPattern[1] * zoom;   // e.g. 4.0 * zoom
  final totalLen = dashLen + gapLen;
  final offset  = animationValue * totalLen;

  for (final metric in path.computeMetrics()) {
    double distance = -offset;             // Shift start for animation
    while (distance < metric.length) {
      final start = distance.clamp(0.0, metric.length);
      final end   = (distance + dashLen).clamp(0.0, metric.length);
      if (end > start) {
        canvas.drawPath(metric.extractPath(start, end), paint);
      }
      distance += totalLen;
    }
  }
}
```

### Performance Considerations

- `shouldRepaint` returns `true` only when `animationValue` changes
- Non-animated edges skip the `PathMetrics` extraction entirely
- `RepaintBoundary` isolates edge repaints from node widget rebuilds

---

## Static Dashed Edges

When `dashPattern` is non-empty but `animated` is `false`, edges render as static dashed lines:

```dart
final style = EdgeStyle(
  dashPattern: [10, 5],  // 10px dash, 5px gap
  animated: false,
);
```

---

## Arrowheads

By default, every edge draws an **arrowhead** at the target end:

```
                 ╱
  ──────────────╳  ← arrowhead
                 ╲
```

The arrow uses `PathMetrics.getTangentForOffset()` to find the angle at the path endpoint, then draws two lines at ±0.5 radians from the tangent angle.

Configuration:
```dart
EdgeStyle(
  showArrow: true,     // Toggle arrow visibility
  arrowSize: 8.0,      // Arrow size in logical pixels
)
```

---

## Edge Labels

Optional text labels are rendered as Flutter widgets (not painted) at the edge midpoint:

```
  Source ●
         \
          \ ┌───────────┐
           \│ on success │  ← EdgeLabelWidget
            └───────────┘
                \
         Target  ●
```

Labels are positioned using the routing-specific midpoint calculation:
- **Bezier**: Evaluates the cubic Bézier at `t = 0.5`
- **SmoothStep / Straight**: Average of source and target points

The label widget includes:
- Configurable background color (auto-adapts to light/dark themes)
- Font size scales with viewport zoom
- Text color matches edge color

---

## Edge Selection

Selected edges display a **highlight glow** behind the main line:

```dart
if (isSelected) {
  final highlightPaint = Paint()
    ..color = edge.style.color.withAlpha(0.3)
    ..strokeWidth = (thickness + 4) * zoom;
  canvas.drawPath(path, highlightPaint);  // Draw highlight first
}
canvas.drawPath(path, mainPaint);         // Draw main edge on top
```

---

## Animated Edge Painter (Standalone)

`AnimatedEdgePainter` is a secondary painter that renders **only** animated edges. It exists for architectural separation but shares the same rendering logic with `EdgePainter`. The main `EdgePainter` handles all edges (including animated ones) in the current implementation.

---

**Previous:** [← Canvas](./06_canvas.md) · **Next:** [Nodes →](./08_nodes.md)
