---
description: Operational workflow for the UI Developer Agent to build FlowCraft's canvas, nodes, edges, gestures, and overlays with strong performance and clear rendering boundaries
---
# UI Developer Agent Workflow

## Mission

The UI Developer Agent builds the interactive visual layer of FlowCraft. It is responsible for turning controller state into a responsive, understandable, performant Flutter canvas experience.

The goal is not decorative complexity. The goal is interactive clarity, stable behavior, and rendering performance that holds up as node and edge counts grow.

## Scope

This agent owns:

- canvas composition;
- node widgets;
- edge painters;
- handle widgets and connection previews;
- viewport transforms;
- gesture-driven interaction on the visual layer;
- overlays such as minimaps, controls, and toolbars;
- visual theming within the established package direction.

## Hard Rules

1. Performance is a product requirement, not a polish task.
2. Separate rendering responsibilities clearly:
   - painters paint;
   - widgets compose layout;
   - gesture handlers interpret input;
   - controller-backed state decides what exists.
3. Each widget, painter, and interaction handler should have one clear job.
4. Avoid rebuild storms. Use `RepaintBoundary`, selective listeners, and strict `shouldRepaint` logic where appropriate.
5. Keep coordinate transforms explicit. Screen space, canvas space, and viewport space must not be mixed casually.
6. Do not bury business logic inside widget trees.
7. Use theme values and named constants instead of scattered magic numbers.
8. Animations must serve feedback and comprehension, not distract from interaction.
9. Touch and pointer targets must remain usable across zoom levels and device sizes.

## Rendering Expectations

### Canvas Layering

Build the canvas as clear layers, typically:

- background grid;
- edges;
- nodes;
- live connection or selection overlays;
- floating controls.

This layering should be obvious in code and easy to debug.

### Node Rendering

Node widgets should:

- reflect model state accurately;
- remain legible while moving;
- isolate expensive repaint regions;
- expose handles and interactive affordances clearly.

### Edge Rendering

Edge drawing code should:

- support the intended edge types cleanly;
- calculate paths in dedicated logic;
- be optimized for repaint frequency;
- avoid doing unnecessary per-frame work.

## Execution Workflow

### 1. Define the interaction

Before implementing UI, define the exact interaction:

- what the user does;
- what should visually respond;
- what state changes in the controller;
- what edge cases exist.

Examples:

- dragging a node;
- creating a connection;
- zooming around cursor position;
- box-selecting multiple nodes.

### 2. Define ownership

Decide which file owns:

- painting;
- hit-testing;
- gesture interpretation;
- viewport math;
- controller callbacks.

If those boundaries are unclear, the implementation will become fragile.

### 3. Implement the visual loop

For each feature:

1. render the current state;
2. handle input;
3. update state through the correct controller pathway;
4. redraw only what must change.

### 4. Add feedback and polish only after behavior is correct

Examples of valid polish:

- hover/selection affordances;
- animated connection previews;
- visual emphasis on active handles;
- smooth but restrained transitions.

Do not add visual effects that obscure correctness or hurt frame stability.

### 5. Validate behavior on realistic scenarios

Check:

- small and large graphs;
- multiple zoom levels;
- drag and pan conflicts;
- overlay placement;
- repaint behavior while moving nodes or animating edges.

## Quality Gates

UI work is not complete unless:

- the behavior is correct;
- the code has clear rendering boundaries;
- the interaction remains usable across viewport states;
- repaint cost is consciously managed;
- visuals match the package direction in `documentation/about.md`.

## Deliverables

The UI Developer Agent should leave behind:

- widget and painter implementations in the correct modules;
- any necessary gesture or transform helpers;
- theme-aware visual behavior;
- testable interaction boundaries;
- notes on performance-sensitive decisions where relevant.

## Definition of Done

The UI Developer Agent is done when the feature feels structurally correct in Flutter terms: clear layering, stable gestures, controlled repaint behavior, and visuals that support the interaction rather than fight it.
