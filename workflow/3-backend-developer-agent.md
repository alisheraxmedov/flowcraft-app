---
description: Workflow for the Backend/Core Logic Developer Agent to design the data models, state manager, and json serialization in pure Dart
---
# Backend / Core Logic Developer Agent Workflow

Although FlowCraft is a frontend Flutter package, it requires a robust "backend-of-the-frontend" engine. The Core Logic Developer Agent focuses entirely on pure Dart (Dart 3.x), strictly avoiding external dependencies, to build the data structures, state management (`FlowController`), graph algorithms, and JSON serialization.

## Steps

1. **Data Modeling & Architecture**
   - Design immutable or highly trackable data models (`FlowNode`, `FlowEdge`, `FlowGraph`).
   - Define Enums for core concepts like Node Types, Edge Types (bezier, straight), and Handle Positions (top/bottom/left/right).

2. **State Management (`FlowController`)**
   - Build a central `ChangeNotifier` (`FlowController`) acting as the main brain accessible to public developers.
   - Implement operations like `addNode`, `removeEdge`, `moveNode`, and batch updates.
   - Ensure state changes broadcast efficiently so that the `ListenableBuilder` in the UI reacts optimally.

3. **History Management (Undo/Redo)**
   - Implement the Command Pattern or State Snapshotting via `HistoryManager`.
   - Ensure moving nodes, adding edges, or modifying node fields can be fully reversed.

4. **Matrix & Graph Mathematics**
   - Write pure Dart math utilities (`math_utils.dart`) for calculating center points, edge connection vectors, and checking boundary collisions.
   - Implement fast graph lookup utilities (`graph_utils.dart`) to find connected edges when a node is dragged.

5. **JSON Serialization**
   - Use built-in `dart:convert` to serialize the entire `FlowGraph` into JSON.
   - Write strict `fromJson` and `toJson` methods for every model, handling dynamic node data maps losslessly.
   - Ensure developers can save graphs to their backend and reload them exactly as they were.

## Checklist

- [ ] Adhere strictly to pure Dart (zero external `pubspec/dependencies` allowed).
- [ ] Design robust, strongly typed models for Nodes, Edges, and the Graph.
- [ ] Develop the central `FlowController` extending `ChangeNotifier` with a clean public API.
- [ ] Implement robust Undo/Redo functions tracking graph history.
- [ ] Write high-performance mathematical functions for edge pathing and hit-testing data.
- [ ] Implement fail-proof `toJson` and `fromJson` serialization using only `dart:convert`.
- [ ] Validate that node configurations (like dynamic metadata maps) serialize correctly.
- [ ] Optimize the internal data structures (e.g., using `Map` for O(1) node lookups).
- [ ] Document all logic operations thoroughly for `dartdoc`.
