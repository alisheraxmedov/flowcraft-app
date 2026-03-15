# FlowCraft — Core Models

This document provides a complete reference for all data models, enums, and utility classes in the `core/` module.

---

## Enums

### `EdgeType`

Defines the routing algorithm for an edge.

| Value        | Description                                            |
|--------------|--------------------------------------------------------|
| `bezier`     | Smooth cubic Bezier curve (default)                    |
| `smoothStep` | Right-angle segments with rounded corners              |
| `straight`   | Direct straight line from source to target             |

```dart
EdgeType.fromString('bezier'); // Converts a string to EdgeType
```

---

### `HandlePosition`

Defines which side of a node a handle is placed on.

| Value    | Offset Calculation                               |
|----------|--------------------------------------------------|
| `top`    | Center-top of node: `(left + width/2, top)`      |
| `bottom` | Center-bottom: `(left + width/2, bottom)`        |
| `left`   | Center-left: `(left, top + height/2)`            |
| `right`  | Center-right: `(right, top + height/2)`          |

```dart
HandlePosition.top.toOffset(nodeRect); // Returns the absolute Offset
```

---

### `NodeType`

Defines the visual type of a node.

| Value         | Description                                        |
|---------------|----------------------------------------------------|
| `defaultNode` | Standard rectangular node                          |
| `input`       | Entry-point node with rounded top and green accent |
| `output`      | Exit-point node with rounded bottom and red accent |
| `custom`      | Custom node rendered via `NodeTypeRegistry`        |

---

## Models

### `FlowNode`

Represents a single node on the canvas.

```
┌──────────────────────────────────────┐
│  FlowNode                            │
│  ├── id: String (auto-generated)     │
│  ├── type: NodeType                  │
│  ├── label: String                   │
│  ├── position: Offset (top-left)     │
│  ├── size: Size (width × height)     │
│  ├── data: Map<String, dynamic>      │  ◄── Dynamic key-value fields
│  └── handles: List<FlowHandle>       │  ◄── 4 default handles (T/B/L/R)
└──────────────────────────────────────┘
```

**Key Behaviors:**
- Auto-generates a unique `id` if none is provided (format: `node_<timestamp>_<hex>`)
- Automatically creates 4 handles (top, bottom, left, right) if none are provided
- `rect` getter returns `Rect.fromLTWH(position.dx, position.dy, width, height)`
- `center` getter returns the center-point `Offset`
- Full `toJson()` / `fromJson()` serialization
- `copyWith()` for immutable state updates
- Equality by `id`

**Example:**
```dart
final node = FlowNode(
  label: 'Send Email',
  type: NodeType.defaultNode,
  position: const Offset(200, 150),
  size: const Size(200, 80),
  data: {
    'status': 'active',
    'assignee': 'Alisher',
    'priority': 'high',
  },
);
```

---

### `FlowEdge`

Represents a directed connection between two nodes.

```
┌──────────────────────────────────────┐
│  FlowEdge                            │
│  ├── id: String (auto-generated)     │
│  ├── sourceNodeId: String            │
│  ├── targetNodeId: String            │
│  ├── sourceHandleId: String          │
│  ├── targetHandleId: String          │
│  └── style: EdgeStyle                │
└──────────────────────────────────────┘
```

An edge connects a specific handle on the source node to a specific handle on the target node. The `style` property controls the visual appearance.

---

### `FlowHandle`

A connection point on a node where edges attach.

```
┌──────────────────────────────────────┐
│  FlowHandle                          │
│  ├── id: String (auto-generated)     │
│  ├── nodeId: String                  │
│  ├── position: HandlePosition        │
│  └── maxConnections: int?            │  ◄── null = unlimited
└──────────────────────────────────────┘
```

Handles are automatically created for every new node (top, bottom, left, right). Each handle's absolute pixel position is computed via `HandlePosition.toOffset(nodeRect)`.

---

### `EdgeStyle`

Defines the complete visual style for an edge.

| Property       | Type              | Default              | Description                        |
|----------------|-------------------|----------------------|------------------------------------|
| `color`        | `Color`           | `#555555`            | Edge line color                    |
| `thickness`    | `double`          | `2.0`                | Stroke width in logical pixels     |
| `edgeType`     | `EdgeType`        | `bezier`             | Routing algorithm                  |
| `animated`     | `bool`            | `false`              | Enable flowing dash animation      |
| `dashPattern`  | `List<double>`    | `[]` (solid)         | Alternating [dash, gap] lengths    |
| `arrowSize`    | `double`          | `8.0`                | Arrow tip size at target end       |
| `showArrow`    | `bool`            | `true`               | Whether to draw the target arrow   |
| `label`        | `String?`         | `null`               | Optional text at edge midpoint     |

**Example:**
```dart
const style = EdgeStyle(
  color: Color(0xFF6366F1),
  thickness: 2.5,
  edgeType: EdgeType.bezier,
  animated: true,
  dashPattern: [8, 4],
  showArrow: true,
  label: 'on success',
);
```

---

### `FlowGraph`

Container holding all nodes and edges. Provides lookup helpers.

| Method                        | Description                                    |
|-------------------------------|------------------------------------------------|
| `nodeById(String id)`         | Find a node by ID, or `null`                   |
| `edgeById(String id)`         | Find an edge by ID, or `null`                  |
| `edgesForNode(String nodeId)` | All edges connected to a node                  |
| `outgoingEdges(String nodeId)`| Edges originating from a node                  |
| `incomingEdges(String nodeId)`| Edges targeting a node                         |
| `copyWith()`                  | Deep copy of the entire graph                  |
| `toJson()` / `fromJson()`    | Full serialization                             |

---

### `FlowViewport`

Represents the current pan/zoom state of the canvas viewport.

| Property   | Type     | Default       | Description                      |
|------------|----------|---------------|----------------------------------|
| `offset`   | `Offset` | `(0, 0)`      | Current pan offset               |
| `zoom`     | `double` | `1.0`         | Current zoom level (1.0 = 100%)  |
| `minZoom`  | `double` | `0.1`         | Minimum allowed zoom             |
| `maxZoom`  | `double` | `4.0`         | Maximum allowed zoom             |

Zoom is automatically clamped to `[minZoom, maxZoom]` in `copyWith()`.

---

## Utilities

### `GraphUtils`

Static utility methods for graph validation and inspection:

| Method                     | Description                                          |
|----------------------------|------------------------------------------------------|
| `wouldCreateCycle()`       | BFS check for cycle detection before adding an edge  |
| `isSelfConnection()`       | Returns `true` if source == target node              |
| `isDuplicateEdge()`        | Checks for existing edge between same handles        |
| `validateEdge()`           | Full validation — returns error string or `null`     |
| `sourceNodes()`            | All root nodes (no incoming edges)                   |
| `sinkNodes()`              | All leaf nodes (no outgoing edges)                   |
| `removeEdgesForNode()`     | Removes all edges connected to a node                |

---

### `IdGenerator`

Generates unique identifiers for nodes, edges, and handles.

**Format:** `<prefix>_<microsecondTimestamp>_<4-digit-hex>`

```dart
IdGenerator.nodeId();   // "node_1710547200000000_3f4a"
IdGenerator.edgeId();   // "edge_1710547200000001_b12c"
IdGenerator.handleId(); // "handle_1710547200000002_8e7f" (internal alias)
IdGenerator.generate('custom'); // "custom_<timestamp>_<hex>"
```

---

### `MathUtils`

Mathematical utilities for edge path calculations:

| Method                    | Description                                    |
|---------------------------|------------------------------------------------|
| `bezierControlPoints()`  | Compute cubic Bezier control points            |
| `handleDirection()`       | Direction vector for a handle position          |
| `lerpOffset()`            | Linear interpolation between two `Offset`s     |
| `bezierMidpoint()`        | Midpoint of a cubic Bezier curve               |
| `clampDouble()`           | Clamp a value between min and max              |
| `distance()`              | Euclidean distance between two points          |
| `boundingRect()`          | Bounding rect around a list of points          |

---

### `Serializer`

Handles full state serialization (graph + viewport):

```dart
// Serialize to JSON string
String json = Serializer.serialize(graph: graph, viewport: viewport);

// Deserialize from JSON string
final (:graph, :viewport) = Serializer.deserialize(json);

// Map-based variants
Map<String, dynamic> map = Serializer.toMap(graph: graph, viewport: viewport);
final result = Serializer.fromMap(map);
```

JSON format version is tracked (`"version": 1`) for future backward compatibility.

---

**Previous:** [← Getting Started](./03_getting_started.md) · **Next:** [Controller API →](./05_controller_api.md)
