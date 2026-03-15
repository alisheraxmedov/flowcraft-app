---
description: Workflow for the Developer Agent to orchestrate project architecture, organize the package API, and build example apps
---
# Developer Agent Workflow

The Developer Agent is the core Flutter software engineer. It orchestrates the entirety of the FlowCraft package, binding the core Data Logic (`FlowController`) with the UI (`FlowCanvasWidget`). It ensures the package remains zero-dependency and easy for other developers to integrate into their apps.

## Steps

1. **Feature Comprehension and Scoping**
   - Deeply understand the required FlowCraft capability (e.g., node dragging, edge connecting, undo/redo).
   - Trace the required modifications through `lib/core/`, `lib/controller/`, and `lib/canvas/`.

2. **Architectural Connection and State Management**
   - Bind the backend logic (the `ChangeNotifier` in `FlowController`) to the UI layer utilizing `ListenableBuilder` or `AnimatedBuilder`.
   - Maintain a highly cohesive, loosely coupled directory structure reflecting standard Dart guidelines.
   - Establish the main package Barrel File (`lib/flowcraft.dart`) cleanly exporting only public APIs.

3. **Developing Advanced Logic Hooks**
   - Implement handlers that orchestrate user actions (e.g., from `GestureDetector` on the canvas to `FlowController.moveNode`).
   - Implement the `HistoryManager` Command Pattern to track Undo and Redo operations flawlessly.

4. **Example App Creation**
   - Regularly update the `/example` directory with robust, easy-to-read demo applications showing off new package features.
   - Design code examples in `main.dart` displaying both `basic_flow_screen` and advanced usage with custom node types.

5. **Self-Review and pub.dev Compliance**
   - Ensure absolutely **ZERO external dependencies** (no `provider`, no `bloc`, just native Flutter SDK).
   - Write comprehensive `dartdoc` comments (`///`) on all publicly exported classes, parameters, and methods.
   - Review code quality utilizing `dart analyze` to ensure no warnings exist.

## Checklist

- [ ] Plan feature integration utilizing Flutter state management (e.g., `ChangeNotifier`).
- [ ] Write the orchestration logic hooking gestures up to central `FlowController` methods.
- [ ] Establish standard Dart architecture boundaries (`core`, `controller`, `canvas`, `nodes`, `edges`).
- [ ] Validate the package remains completely free of 3rd party pubspec dependencies.
- [ ] Maintain a clean public exit API in the barrel file `flowcraft.dart`.
- [ ] Build intuitive example screens in `/example/lib` demonstrating usage scenarios to end developers.
- [ ] Write rich `dartdoc` documentation on all new methods and models.
- [ ] Execute `dart analyze` to fix lints and maintain high pub.dev formatting scores.
