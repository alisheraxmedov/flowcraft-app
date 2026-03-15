---
description: Workflow for the UI Developer Agent to create responsive, interactive, fantastic widgets, and complex CustomPainters natively in Flutter
---
# UI Developer Agent Workflow

The UI Developer Agent is a master of Flutter rendering. Its sole responsibility is crafting the breathtaking, state-of-the-art visual elements of the FlowCraft canvas using native widgets, Canvas API drawing, math logic, and animations. The goal is to provide a "Fantastic" animated UI that matches and surpasses ReactFlow.

## Steps

1. **CustomPainter Mastery (Edges & Grid)**
   - Implement `CustomPainter` to draw infinite grid backgrounds (`grid_painter.dart`) handling dots/lines dynamically.
   - Calculate and draw complex paths: cubic bezier curves, straight lines, and orthogonal smooth-step edges (`edge_painter.dart`).
   - Architect dashed, animated, glowing edges utilizing `AnimationController` to simulate data flow over connections.

2. **Fantastic Node Aesthetics**
   - Create visually stunning node widgets avoiding raw squares (e.g., glassmorphism, neumorphism, soft blurred shadows, gradients).
   - Develop `InputNode`, `OutputNode`, and `DefaultNode` variants rendering dynamic key-value fields.
   - Ensure nodes are performant utilizing `RepaintBoundary` to prevent cascading render cycles when dragging.

3. **Responsive Viewport and Gestures**
   - Implement infinite pan and zoom natively using `Matrix4` transformations combined with complex `GestureDetector` handlers mapping local-to-global coordinates.
   - Develop smooth zooming logic centered on the user's cursor or pinch location.
   - Ensure nodes and interactive handles are touch-friendly targets, seamlessly scaling with viewport modifications.

4. **Overlays and Micro-Interactions**
   - Develop interactive floating toolbars (`node_toolbar_widget.dart`), minimaps providing global graph perspective, and zoom controls.
   - Embed micro-animations for user interactions (e.g., handles swelling on hover, connection lines snapping to targets).
   - Render a precise lasso selection box tracking user drag bounds.

5. **Flutter Compliance and Optimization**
   - Profile the canvas layer stack ensuring the 60fps / 120fps benchmark is hit despite thousands of edges/nodes.
   - Optimize rendering cycles utilizing strict `shouldRepaint()` algorithms to diff edge arrays.
   - Adapt the UI components to system Light Mode and Dark Mode dynamically using `FlowTheme` configurations natively.

## Checklist

- [ ] Write responsive, robust layout structures using `Stack`, `Positioned`, and native bounding calculations.
- [ ] Optimize rendering utilizing `Matrix4` pan/zoom math and the `Transform` widget wrapper.
- [ ] Implement complex Path drawing algorithms (bezier, straight, smoothstep) purely via `Canvas` drawing operations.
- [ ] Embed animations simulating interactive feedback (e.g., animated flowing dashed lines along a path).
- [ ] Craft premium aesthetic designs incorporating gradients, soft shadows, and glassmorphism.
- [ ] Secure touch interactions properly (e.g., distinguish dragging the canvas vs dragging a node or making a connection).
- [ ] Implement dynamic resizing handles mapping to core Model adjustments seamlessly.
- [ ] Manage optimization constraints explicitly (Wrap changing fragments in `RepaintBoundary`).
- [ ] Verify functionality consistently dynamically rendering across system Light / Dark modes.
- [ ] Verify animations scale gracefully across all viewports without thread stutter.
