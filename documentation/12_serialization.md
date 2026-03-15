# FlowCraft — Serialization

This document explains how to save and load flow graphs as JSON.

---

## Overview

FlowCraft provides built-in serialization for the **entire canvas state** — including all nodes, edges, their styles, and the viewport (pan/zoom) position. No external packages are needed; everything uses `dart:convert`.

```
  FlowController
      │
      ├── toJson()  ──► JSON String ──► File / Server / LocalStorage
      │
      └── fromJson() ◄── JSON String ◄── File / Server / LocalStorage
```

---

## Quick Usage

### Save

```dart
// Serialize to JSON string
final String json = controller.toJson();

// Or serialize to a Map
final Map<String, dynamic> map = controller.toMap();
```

### Load

```dart
// Load from JSON string
controller.fromJson(json);

// Or load from a Map
controller.fromMap(map);
```

> **Note:** Loading state automatically pushes the current state to the undo stack, so the user can undo the load operation.

---

## JSON Format

The serialized JSON follows this structure:

```json
{
  "version": 1,
  "graph": {
    "nodes": [
      {
        "id": "node_1710547200000000_3f4a",
        "type": "defaultNode",
        "label": "Send Email",
        "position": { "dx": 200.0, "dy": 150.0 },
        "size": { "width": 180.0, "height": 60.0 },
        "data": {
          "status": "active",
          "assignee": "Alisher"
        },
        "handles": [
          {
            "id": "fc_1710547200000001_a1b2",
            "nodeId": "node_1710547200000000_3f4a",
            "position": "top"
          },
          {
            "id": "fc_1710547200000002_c3d4",
            "nodeId": "node_1710547200000000_3f4a",
            "position": "bottom"
          }
        ]
      }
    ],
    "edges": [
      {
        "id": "edge_1710547200000010_e5f6",
        "sourceNodeId": "node_1710547200000000_3f4a",
        "targetNodeId": "node_1710547200000005_7890",
        "sourceHandleId": "fc_1710547200000002_c3d4",
        "targetHandleId": "fc_1710547200000006_abcd",
        "style": {
          "color": 4283782485,
          "thickness": 2.0,
          "edgeType": "bezier",
          "animated": true,
          "dashPattern": [8.0, 4.0],
          "arrowSize": 8.0,
          "showArrow": true,
          "label": "on success"
        }
      }
    ]
  },
  "viewport": {
    "offset": { "dx": 0.0, "dy": 0.0 },
    "zoom": 1.0,
    "minZoom": 0.1,
    "maxZoom": 4.0
  }
}
```

### Version Field

The `"version": 1` field enables future backward-compatible format changes.

### Color Encoding

Colors are serialized as 32-bit ARGB integers:

```dart
// Serialization:   color.toARGB32()     → 4283782485
// Deserialization:  Color(4283782485)    → Color(0xFF555555)
```

---

## Serializer Class

For low-level access, use the `Serializer` utility directly:

```dart
// Serialize
String json = Serializer.serialize(graph: graph, viewport: viewport);
Map<String, dynamic> map = Serializer.toMap(graph: graph, viewport: viewport);

// Deserialize
final (:graph, :viewport) = Serializer.deserialize(json);
final result = Serializer.fromMap(map);
// result.graph, result.viewport
```

---

## Individual Model Serialization

Every model class has its own `toJson()` and `fromJson()` methods:

```dart
// FlowNode
Map<String, dynamic> json = node.toJson();
FlowNode restored = FlowNode.fromJson(json);

// FlowEdge
Map<String, dynamic> json = edge.toJson();
FlowEdge restored = FlowEdge.fromJson(json);

// EdgeStyle
Map<String, dynamic> json = style.toJson();
EdgeStyle restored = EdgeStyle.fromJson(json);

// FlowHandle
Map<String, dynamic> json = handle.toJson();
FlowHandle restored = FlowHandle.fromJson(json);

// FlowViewport
Map<String, dynamic> json = viewport.toJson();
FlowViewport restored = FlowViewport.fromJson(json);

// FlowGraph
Map<String, dynamic> json = graph.toJson();
FlowGraph restored = FlowGraph.fromJson(json);
```

---

## Example: Save to File

```dart
import 'dart:io';

Future<void> saveGraph(FlowController controller, String path) async {
  final json = controller.toJson();
  await File(path).writeAsString(json);
}

Future<void> loadGraph(FlowController controller, String path) async {
  final json = await File(path).readAsString();
  controller.fromJson(json);
}
```

---

**Previous:** [← Theming](./11_theming.md) · **Next:** [Performance →](./13_performance.md)
