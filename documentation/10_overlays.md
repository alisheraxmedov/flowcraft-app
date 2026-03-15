# FlowCraft — Overlays

This document covers the built-in overlay widgets: minimap, zoom controls, and node toolbar.

---

## Overlay System

Overlays are Flutter widgets rendered in **Layer 5** (topmost) of the canvas stack. They float above all nodes and edges and are not affected by pan/zoom transformations.

```
  ┌─────────────────────────────────────────────────┐
  │                   Canvas                         │
  │                                                  │
  │                  (nodes, edges, grid)             │
  │                                                  │
  │ ┌───┐                                  ┌───────┐│
  │ │ + │  ← ControlsWidget               │minimap ││
  │ │ − │    (bottom-left)                 │       ││
  │ │ ⊡ │                                  └───────┘│
  │ └───┘                                            │
  └─────────────────────────────────────────────────┘
```

---

## Controls Widget

`ControlsWidget` provides zoom in, zoom out, and fit-to-view buttons.

```
  ┌───┐
  │ + │  ← Zoom In  (controller.zoomIn())
  ├───┤
  │ − │  ← Zoom Out (controller.zoomOut())
  ├───┤
  │ ⊡ │  ← Fit View (controller.fitView(canvasSize))
  └───┘
```

**Position:** Bottom-left corner (12px from edges)

**Usage:**
```dart
FlowCanvas(
  controller: controller,
  showControls: true,   // Enabled by default
)
```

The fit-view button automatically determines the canvas size from the render object.

---

## Minimap Widget

`MinimapWidget` provides a small overview preview of the entire graph.

```
  ┌────────────────────┐
  │  ·                  │  ← nodes shown as small rectangles
  │      ·    ·         │
  │  ┌───────┐          │
  │  │viewport│         │  ← current viewport shown as blue rectangle
  │  └───────┘    ·     │
  └────────────────────┘
```

**Position:** Bottom-right corner (12px from edges)

### Parameters

| Parameter           | Type     | Default              | Description                    |
|---------------------|----------|----------------------|--------------------------------|
| `width`             | `double` | `180`                | Minimap width in pixels        |
| `height`            | `double` | `120`                | Minimap height in pixels       |
| `backgroundColor`   | `Color`  | `#F5F5F5`            | Background color               |
| `nodeColor`         | `Color`  | `#90CAF9`            | Color for node representations |
| `viewportColor`     | `Color`  | `#442196F3`          | Viewport rectangle fill color  |

### How It Works

1. Calculates the bounding box of all nodes with padding
2. Computes a scale factor to fit the graph into the minimap dimensions
3. Draws each node as a small rounded rectangle
4. Draws the viewport rectangle showing the currently visible area

**Usage:**
```dart
FlowCanvas(
  controller: controller,
  showMiniMap: true,     // Disabled by default
)
```

---

## Node Toolbar Widget

`NodeToolbarWidget` is a floating toolbar that appears above a selected node.

```
                ┌────────────────────────────────┐
                │  Rename  │  Copy  │  Delete     │  ← dark background
                └────────────────────────────────┘
                            ▲
                     ┌──────┴───────┐
                     │  Selected     │
                     │  Node         │
                     └──────────────┘
```

**Position:** Centered above the node, offset by 40px upward.

### Parameters

| Parameter     | Type          | Description                            |
|---------------|---------------|----------------------------------------|
| `position`    | `Offset`      | Screen-space position (node center)    |
| `onDelete`    | `VoidCallback?`| Callback for delete action            |
| `onDuplicate` | `VoidCallback?`| Callback for duplicate/copy action    |
| `onRename`    | `VoidCallback?`| Callback for rename action            |

### Button Styling

- Normal actions: White text on dark background (`#333333`)
- Destructive actions (Delete): Red text (`#EF5350`)

---

## Custom Overlays

Developers can add their own overlay widgets:

```dart
FlowCanvas(
  controller: controller,
  overlays: [
    Positioned(
      top: 12,
      left: 12,
      child: MyCustomToolbar(),
    ),
  ],
)
```

Custom overlays are rendered after the built-in controls and minimap in the layer stack.

---

**Previous:** [← Interactions](./09_interactions.md) · **Next:** [Theming →](./11_theming.md)
