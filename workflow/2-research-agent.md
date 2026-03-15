---
description: Workflow for the Research Agent to explore Flow diagram concepts, rendering optimizations, and pub.dev best practices
---
# Research Agent Workflow

The Research Agent explores the latest trends in interactive flow diagrams, specifically studying libraries like ReactFlow (JS) and dissecting complex mathematics/rendering techniques. For FlowCraft, its goal is to bring cutting-edge node-based visual workflows to Flutter with zero external dependencies.

## Steps

1. **Conduct Targeted Internet Research on Reference Libraries**
   - Deeply analyze **ReactFlow** (JS/TS), JS.flow, and node-based systems in Unreal Engine or Blender.
   - Figure out how they implement features like lasso selection, smart routing (smoothstep), and minimap projections.
   - Investigate existing abandoned Flutter alternatives (like `flutter_flow_chart` or `flow_canvas`) to learn from their architecture mistakes.

2. **Research Flutter Rendering & Math Optimizations**
   - Research high-performance pure Dart solutions for **cubic Bezier curves** and path intersections.
   - Research optimizations for `CustomPainter` in Flutter (e.g., `RepaintBoundary`, `shouldRepaint` diffing).
   - Research `Matrix4` math for implementing robust, infinite 2D canvas pan and zoom operations via `GestureDetector`.

3. **Research pub.dev Standards and Packaging**
   - Study the exact requirements to achieve a perfect **140/140 score on pub.dev**.
   - Research best practices for writing public `dartdoc` API documentation and organizing a Flutter package `lib/` barrel file.

4. **Draft the Research Proposal & PoC**
   - Compile findings into a structured markdown report.
   - Formulate a clear recommendation on algorithm integration (e.g., "Use this specific math formula for drawing orthogonal smooth-step edges").
   - Develop small isolated Proofs of Concept (PoC) for the isolated math or UI techniques.

5. **Present and Handoff**
   - Present the research to the UI or Core Logic Developer Agents for immediate implementation.
   - Provide direct links to ReactFlow docs, Flutter engine architecture docs, and relevant mathematical algorithms.

## Checklist

- [ ] Define the specific feature to research (e.g., Edge Routing, Multi-select, Minimap math).
- [ ] Analyze reference architectures like ReactFlow and document their approach.
- [ ] Research the optimal 60fps Flutter native implementation (using zero external packages).
- [ ] Investigate `Matrix4`, `CustomPainter`, and `GestureDetector` best practices.
- [ ] Study `pub.dev` documentation guidelines to ensure compliance.
- [ ] Draft a concise, actionable report detailing the math or architecture to use.
- [ ] Include all relevant documentation links, math equations, and source references.
- [ ] Propose a high-level integration strategy for the Developer Agents.
