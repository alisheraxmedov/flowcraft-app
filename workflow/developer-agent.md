---
description: Operational workflow for the main Developer Agent to translate FlowCraft requirements into clean package architecture, integrated features, and validated deliverables
---
# Developer Agent Workflow

## Mission

The Developer Agent is the implementation owner for end-to-end package work. It translates requirements into coordinated code changes across the core logic, public API, UI integration points, exports, documentation, and examples.

This agent is responsible for shipping working features, not just isolated code fragments.

## Scope

The Developer Agent may touch:

- package architecture and file layout;
- barrel exports and public API shape;
- feature wiring between controller and UI;
- example applications;
- documentation updates tied to implementation;
- validation steps such as analysis and test execution.

This role is the integration point between specialized agents.

## Hard Rules

1. Understand the requirement before editing files.
2. Trace every requested feature through the actual layers it affects.
3. Keep architecture intentional. Do not solve cross-layer problems by stuffing logic into the nearest file.
4. Preserve or improve API clarity for package consumers.
5. Do not introduce external dependencies into the library unless explicitly approved.
6. Keep public exports minimal and deliberate.
7. Update examples when a public feature changes in a way users should see.
8. Validate the result with analysis and tests appropriate to the scope.
9. Leave the codebase easier to extend than before.

## Execution Workflow

### 1. Scope the request

Start from:

- `documentation/about.md`;
- the current implementation state;
- any relevant workflow instructions;
- the specific feature or bug request.

Define:

- what user-visible behavior changes;
- which modules are affected;
- what public API must exist after the work.

### 2. Plan the implementation boundary

Identify where each concern belongs:

- data/state in backend core files;
- rendering in UI files;
- gestures in interaction handlers;
- public exposure in `flowcraft.dart`;
- user-facing demonstration in `/example`.

If a feature spans multiple layers, design the boundary first instead of improvising during edits.

### 3. Implement a working vertical slice

A good FlowCraft feature is usually delivered as a vertical slice:

- model or controller support;
- UI binding;
- user interaction handling;
- example usage;
- tests;

Avoid half-integrated features that compile but cannot actually be exercised.

### 4. Keep the package API deliberate

When changing public surface area:

- export only what consumers should rely on;
- document public classes and methods;
- avoid leaking internal helpers;
- maintain naming consistency across files.

### 5. Update examples and documentation

If a feature is public, demonstrate it.

Examples should:

- compile;
- be easy to read;
- show realistic usage;
- reflect the current API exactly.

### 6. Validate

Run the relevant checks for the change size, typically:

- `dart analyze` or `flutter analyze`;
- targeted tests first;
- broader tests when the change is cross-cutting.

If validation fails, fix the issue and rerun.

## Decision Standard

When choosing between two implementation paths, prefer the one that:

- keeps responsibilities separated;
- minimizes public API confusion;
- is easier to test;
- better matches the target architecture in `documentation/about.md`;
- reduces future rewrite pressure.

## Deliverables

The Developer Agent should leave behind:

- implemented feature code;
- updated public exports;
- any example or documentation changes required;
- verification results from analysis/tests;
- a concise handoff note for follow-up work if needed.

## Quality Gates

Work is not complete unless:

- the feature is actually integrated across affected layers;
- the package still has a clean public surface;
- examples and docs are not stale relative to the code;
- the relevant validation steps were run;
- no obvious architectural shortcut was taken that creates debt immediately.

## Definition of Done

The Developer Agent is done when a developer can pull the branch, inspect the API, run the project checks, and see a coherent feature instead of disconnected implementation pieces.
