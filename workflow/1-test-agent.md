---
description: Workflow for the Testing Agent to create, run, and maintain Dart/Flutter test files for the FlowCraft package
---
# Test Agent Workflow

The Test Agent is responsible for ensuring the reliability, correctness, and stability of the FlowCraft package. Given that this is a pub.dev package, high test coverage is mandatory to achieve maximum pub points (140/140). The agent meticulously writes tests for Dart logic, Flutter widgets, and JSON serialization.

## Steps

1. **Analyze Codebase and Requirements**
   - Review the FlowCraft architecture (models, controller, canvas, interactions).
   - Identify untested code paths in both Dart logic (`dart:test`) and Flutter widgets (`flutter_test`).
   - Understand the required inputs and expected edge cases (e.g., rapid zooming, invalid JSON loading).

2. **Drafting the Test Plan**
   - Outline the unit tests needed for `FlowController`, `HistoryManager`, and data models (`FlowNode`, `FlowEdge`).
   - Outline widget tests for the `FlowCanvasWidget` to ensure nodes render and gestures (pan/zoom) register correctly.
   - Plan integration tests if applicable within the `/example` application.

3. **Writing Test Files**
   - **Unit Tests:** Write tests for zero-dependency Dart logic. Specifically test `dart:convert` serialization (toJson/fromJson) and Undo/Redo stacks.
   - **Widget Tests:** Use `WidgetTester` to simulate taps, drags, and panning. Verify that CustomPainters (like `EdgePainter`) rebuild correctly when state changes.
   - **Performance Tests:** Ensure that gesture handlers are debounced and `shouldRepaint` optimizations prevent unnecessary main-thread blocking.

4. **Execution and Coverage Analysis**
   - Run the full Flutter test suite locally (`flutter test`).
   - Analyze coverage reports to ensure >80% of the codebase is covered (crucial for pub.dev metrics).
   - Identify broken tests caused by architecture updates.

5. **Refactoring and Documentation**
   - Maintain descriptive testing summaries and ensure `dartdoc` comments are not disrupted.
   - Update tests when the core API of `FlowController` evolves.

## Checklist

- [ ] Analyze the specific `core`, `controller`, or `canvas` module to test.
- [ ] Prepare mock JSON graphs or mock default themes for testing.
- [ ] Write Dart unit tests for core algorithms, transformations, and JSON serialization.
- [ ] Write Flutter widget tests for nodes, gesture detectors, and panning capabilities.
- [ ] Verify `shouldRepaint` optimizations in CustomPainters under heavy simulated loads.
- [ ] Run `flutter test --coverage` and generate an HTML report.
- [ ] Ensure the overall test coverage strictly exceeds the 80% pub.dev requirement.
- [ ] Ensure test names explicitly describe the behavior they validate (e.g., `given nodes... when dragged... then updates offset`).
