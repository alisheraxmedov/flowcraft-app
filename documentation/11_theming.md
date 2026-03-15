# FlowCraft — Theming

This document covers the FlowCraft theme system, including built-in themes and custom theme creation.

---

## Overview

`FlowTheme` is a comprehensive theme data class that controls the visual appearance of **every** element in FlowCraft:

```
FlowTheme
  ├── Canvas (background, grid)
  ├── Nodes (background, border, text, header, radius)
  ├── Edges (color, selected color, thickness)
  ├── Handles (color, border, size)
  ├── Selection Box (fill, border)
  └── Minimap (background, node color, viewport color)
```

---

## Built-in Themes

### Light Theme

```dart
FlowTheme.light()
```

| Element                    | Color      | Value           |
|----------------------------|------------|-----------------|
| Canvas background          | Near white | `#FAFAFA`       |
| Grid                       | Gray       | `#22888888`     |
| Node background            | White      | `#FFFFFF`       |
| Node border                | Light gray | `#E0E0E0`       |
| Node selected border       | Blue       | `#2196F3`       |
| Node text                  | Dark gray  | `#333333`       |
| Header background          | Light gray | `#F5F5F5`       |
| Edge color                 | Gray       | `#555555`       |
| Edge selected              | Blue       | `#2196F3`       |
| Handle color               | White      | `#FFFFFF`       |
| Handle border              | Blue       | `#2196F3`       |
| Selection box fill         | Blue 13%   | `#222196F3`     |
| Selection box border       | Blue       | `#2196F3`       |
| Minimap background         | Light gray | `#F5F5F5`       |
| Minimap nodes              | Light blue | `#90CAF9`       |
| Minimap viewport           | Blue 27%   | `#442196F3`     |

---

### Dark Theme

```dart
FlowTheme.dark()
```

| Element                    | Color         | Value           |
|----------------------------|---------------|-----------------|
| Canvas background          | Dark gray     | `#1E1E1E`       |
| Grid                       | White faded   | `#22FFFFFF`     |
| Node background            | Medium gray   | `#2D2D2D`       |
| Node border                | Gray          | `#444444`       |
| Node selected border       | Light blue    | `#64B5F6`       |
| Node text                  | Light gray    | `#E0E0E0`       |
| Header background          | Dark gray     | `#363636`       |
| Edge color                 | Light gray    | `#AAAAAA`       |
| Edge selected              | Light blue    | `#64B5F6`       |
| Handle color               | Medium gray   | `#2D2D2D`       |
| Handle border              | Light blue    | `#64B5F6`       |
| Selection box fill         | Blue 13%      | `#2264B5F6`     |
| Selection box border       | Light blue    | `#64B5F6`       |
| Minimap background         | Very dark gray | `#252525`      |
| Minimap nodes              | Blue          | `#42A5F5`       |
| Minimap viewport           | Blue 27%      | `#4464B5F6`     |

---

## Custom Theme

Create a fully custom theme by providing all required parameters:

```dart
final myTheme = FlowTheme(
  canvasColor:             const Color(0xFF0D1117),
  gridColor:               const Color(0x1158A6FF),
  nodeBackgroundColor:     const Color(0xFF161B22),
  nodeBorderColor:         const Color(0xFF30363D),
  nodeSelectedBorderColor: const Color(0xFF58A6FF),
  nodeTextColor:           const Color(0xFFE6EDF3),
  headerBackgroundColor:   const Color(0xFF21262D),
  edgeColor:               const Color(0xFF8B949E),
  edgeSelectedColor:       const Color(0xFF58A6FF),
  handleColor:             const Color(0xFF161B22),
  handleBorderColor:       const Color(0xFF58A6FF),
  selectionBoxColor:       const Color(0x2258A6FF),
  selectionBoxBorderColor: const Color(0xFF58A6FF),
  minimapBackgroundColor:  const Color(0xFF0D1117),
  minimapNodeColor:        const Color(0xFF58A6FF),
  minimapViewportColor:    const Color(0x4458A6FF),
  nodeFontSize: 13.0,
  nodeHeaderFontSize: 13.0,
  edgeThickness: 2.0,
  handleSize: 10.0,
  nodeBorderRadius: 6.0,
);
```

---

## Modifying an Existing Theme

Use `copyWith()` to override specific properties from a built-in theme:

```dart
final customDark = FlowTheme.dark().copyWith(
  canvasColor: const Color(0xFF000000),
  nodeSelectedBorderColor: const Color(0xFFFF6B6B),
  edgeColor: const Color(0xFF7C3AED),
  nodeBorderRadius: 12.0,
);
```

---

## Theme Properties Reference

### Size and Dimension Properties

| Property              | Type     | Default | Description                    |
|-----------------------|----------|---------|--------------------------------|
| `nodeFontSize`        | `double` | `12.0`  | Font size for node body text   |
| `nodeHeaderFontSize`  | `double` | `12.0`  | Font size for node header text |
| `edgeThickness`       | `double` | `2.0`   | Default edge stroke width      |
| `handleSize`          | `double` | `10.0`  | Handle dot diameter            |
| `nodeBorderRadius`    | `double` | `8.0`   | Node corner radius             |

---

## Applying a Theme

Pass the theme to the `FlowCanvas` widget:

```dart
FlowCanvas(
  controller: controller,
  theme: FlowTheme.dark(),        // ← Apply theme here
  showMiniMap: true,
  showControls: true,
)
```

The theme is applied to:
- Canvas background color
- Grid color and opacity
- Node rendering (via `DefaultBaseNodeWidget`)
- Minimap colors
- Edge label background (auto-detects light/dark)

---

## DefaultTheme Convenience Class

`DefaultTheme` provides static factory shortcuts:

```dart
DefaultTheme.light()  // Equivalent to FlowTheme.light()
DefaultTheme.dark()   // Equivalent to FlowTheme.dark()
```

---

**Previous:** [← Overlays](./10_overlays.md) · **Next:** [Serialization →](./12_serialization.md)
