# Research Report: FlowCraft Capabilities & Animated Flexible Edges

## 1. Problem Statement
The objective of this research is twofold:
1. Define the complete set of functionalities and tasks that the FlowCraft project can accomplish based on the existing `about.md` architecture.
2. Determine the optimal technical strategy for implementing "**animated flexible colored edges**" (smooth curving paths with dashed animation flow) strictly within the confines of a zero-dependency Flutter environment.

## 2. Constraints
- **Zero External Dependencies:** Only Dart SDK and Flutter framework APIs can be used. No external path or graph drawing packages.
- **High Performance:** Smooth 60fps interaction during pan/zoom and animations without lagging the UI dragging.
- **Maintainable Public API:** Complex drawing and state logic must be encapsulated away from the developer utilizing the package.

## 3. Findings: FlowCraft Capabilities & Tasks
Based on the architectural intent in `about.md`, FlowCraft is designed to function as a complete "ReactFlow for Flutter" equivalent. 

**Core System Capabilities:**
- **Interactive Canvas Engine:** An infinite 2D workspace with matrix-based pan and zoom transforms (`viewport_transform.dart`), a background grid (dots/lines), and viewport culling to skip rendering nodes outside the visible screen.
- **Dynamic Node Management:** Support for standard (default, input, output) and custom user-defined nodes. Nodes can be independently dragged, resized via corner handles, and grouped. Nodes contain a dynamic `data` map to support live inline fields, renaming, and dynamic property assignment.
- **Advanced Edge Routing:** Users can interactively draw connections between node handles (top, bottom, left, right). Edges can dynamically route as Bezier curves, smooth steps (right angles), or straight lines.
- **Centralized State & History:** A single robust `FlowController` API for performing all actions (adding, deleting, moving nodes/edges, zooming, selection). Features a dedicated `HistoryManager` that uses the Command Pattern to store snapshots for robust Undo/Redo mechanics.
- **Seamless Serialization:** Full native capability (`serializer.dart`) to dump the exact graph state into a JSON object and load it back later or across sessions.
- **Rich UI Overlays:** Built-in floating `Minimap` widget for graph preview and navigation, Zoom controls, Context Menus, and a Lasso tool for multi-selection.

## 4. Options Considered: Animated Flexible Colored Edges
To achieve the "animated flexible colored edges" (curved lines that flow with a dashed pattern over time), we must evaluate zero-dependency Flutter approaches.

**Option A: Pure PathMetrics Dash Extraction (Recommended)**
- **How it works:** Compute the base curve `Path` (using `Path.cubicTo`). Use `PathMetrics` to iterate over the length of the curve. Extract sub-paths of length `dashLength` alternating with `gapLength`. To animate, continuously shift the starting offset by an `AnimationController` value from 0 to `(dashLength + gapLength)`.
- **Pros:** 100% native SDK. Highly customizable for any line type (bezier, step). Guarantees exact dashed flow appearance over curves.
- **Cons:** Recalculating sub-paths on every frame can be a performance bottleneck if dealing with thousands of animated edges simultaneously.

**Option B: Canvas.drawPath with Custom Shader (LinearGradient)**
- **How it works:** Draw the path solidly, but apply a `LinearGradient` `Shader` to the `Paint`. The gradient alternates uniformly between the line color and `Colors.transparent`. Animate the `transform` matrix of the gradient to create flow.
- **Pros:** Extremely computationally cheap and GPU-accelerated. No need to extract paths.
- **Cons:** Very difficult to map a 1D linear gradient perfectly along a 2D curving bezier path (dashes will heavily distort, stretch, or smear on sharp curves).

**Option C: Particle / Chevron Overlay**
- **How it works:** Draw the base edge as a faint solid line. Use `PathMetrics.getTangentForOffset` to find exact positions to draw small colored circles or chevrons that travel along the path over time.
- **Pros:** Simple math, visually creates a cool "data packet flowing" effect.
- **Cons:** Might not match the standard "dashed line flow" visual exactly as expected from web equivalents.

## 5. Recommendation
**Implement Option A (`PathMetrics` Dash Extraction) with targeted architectural optimizations.**

*Why?* Option A perfectly replicates the "animated dashed flow" effect seen in popular libraries like ReactFlow, strictly adhering to the zero-dependency rule, while guaranteeing visual precision along Bezier curves.

*Technical Strategy:*
1. **Model Layer (`edge_style.dart`):** Add `bool animated`, `List<double> dashPattern`, and properties for spacing and flow speed.
2. **Math Layer (`bezier_edge.dart`):** Generate the source-to-target smooth curve using `Path.cubicTo` using relative offsets based on handle positions.
3. **Animation Hook:** Inject an `AnimationController.repeat()` at the canvas or edge layer provider.
4. **Drawing Logic (`animated_edge_painter.dart`):** 
   ```dart
   final metrics = path.computeMetrics().first;
   double distance = animationOffset; // e.g. from 0 to (dash + gap)
   while (distance < metrics.length) {
     final segment = metrics.extractPath(distance, distance + dashLength);
     canvas.drawPath(segment, paint); // Paint includes custom color/thickness
     distance += (dashLength + gapLength);
   }
   ```
5. **Optimization Rule:** Wrap the entire edge-drawing layer in a `RepaintBoundary` inside `canvas_layer_stack.dart`. Ensure `shouldRepaint` triggers *only* on the animation tick, keeping the 60fps refresh strictly limited to the edges, ignoring the complex Node widgets stacked on top.

## 6. Risks and Unknowns
- **Performance Degradation at Scale:** Computing `PathMetrics` 60 times a second for 500+ edges could drop frames on lower-end mobile devices. 
  - *Mitigation:* Cache the `PathMetrics` object if the source and target nodes haven't moved. Only recompute the subpath extraction.
- **Sharp Corner Artifacts:** For `SmoothStep` (right-angle) edges, extracting a dashed sub-path over a 90-degree corner can sometimes render jaggedly.

## 7. Implementation Handoff

*To the Backend/Core Logic Developer Agent (`/backend-developer`):*
- Ensure `EdgeStyle` fully supports definition of `dashPattern` array and an `animated` toggle. 
- Ensure `graph_utils.dart` correctly handles Edge validation.

*To the UI Developer Agent (`/ui-developer-agent`):*
- Create `animated_edge_painter.dart` utilizing `PathMetrics`.
- The painter is strictly responsible for rendering. It needs the base `Path`, `Paint` objects, and the `Animation` value.
- Add `RepaintBoundary` around `EdgePainter` in the Stack to isolate the 60fps animations from node reconstructions.
