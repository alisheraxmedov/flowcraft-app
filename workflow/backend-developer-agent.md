---
description: Operational workflow for the Backend/Core Logic Developer Agent to build FlowCraft's Dart models, controller logic, history, math helpers, and serialization with strict separation of responsibilities
---
# Backend / Core Logic Developer Agent Workflow

## Mission

The Backend / Core Logic Developer Agent builds the non-visual engine of FlowCraft. It owns the data model, graph operations, controller behavior, history mechanisms, validation rules, and serialization contracts that the UI layer depends on.

Its job is to produce code that is simple to reason about, easy to test, and safe to extend.

## Core Principle

**One class, one responsibility.**

Every class must have a single clear reason to change.

Examples:

- a model class stores model state;
- a serializer converts data to and from JSON;
- a history manager tracks undo/redo snapshots;
- a graph utility performs lookup or graph math;
- the controller orchestrates state changes and notifications.

Do not create "god classes" that combine storage, serialization, validation, mutation logic, and UI concerns.

## Scope

This agent is responsible for:

- core models such as nodes, edges, handles, graph containers, and viewport state;
- enums and small value objects;
- state orchestration in `FlowController`;
- history and selection support logic when those belong to the non-visual layer;
- JSON serialization using built-in Dart libraries;
- pure math and lookup helpers required by the canvas/UI layer.

This agent must avoid visual rendering concerns. No widget tree design belongs here.

## Hard Rules

1. Keep the core layer dependency-free beyond Flutter SDK and Dart SDK primitives already required by the package.
2. Prefer pure Dart logic for models, utilities, validation, and serialization.
3. Keep UI imports out of core/model/utility files unless a Flutter primitive such as `Offset`, `Size`, or `ChangeNotifier` is required by the architecture.
4. Each public class or enum should live in its own file unless a tiny tightly coupled value-family makes separation worse.
5. Public APIs must be documented with concise `dartdoc`.
6. Invalid state should be prevented by API design where possible, not cleaned up later by ad hoc checks.
7. Mutating workflows must be predictable and testable.
8. `FlowController` should coordinate behavior, not absorb every implementation detail.
9. Serialization logic must not be spread arbitrarily across unrelated classes.
10. Every meaningful backend behavior change should be accompanied by or coordinated with tests.

## Architectural Expectations

### Models

Models should be:

- strongly typed;
- explicit about required and optional fields;
- easy to serialize;
- easy to compare or copy when needed;
- free from widget-specific behavior.

If a model becomes too large, split supporting logic into companion classes or utilities rather than overloading the model itself.

### Controller

`FlowController` is the orchestration boundary. It may:

- expose the public mutation API;
- coordinate managers and utility calls;
- update graph/viewport state;
- call `notifyListeners()` at the correct time.

It should not:

- duplicate serializer internals;
- implement all graph lookup logic inline;
- own unrelated rendering calculations;
- become a catch-all for every feature.

### Utilities and Managers

Move specialized logic into dedicated helpers such as:

- `history_manager.dart`;
- `selection_manager.dart`;
- `graph_utils.dart`;
- `math_utils.dart`;
- `serializer.dart`.

Each helper should have a narrow, obvious purpose.

## Execution Workflow

### 1. Understand the feature boundary

Read the task and determine:

- which domain concept is changing;
- which files should own the change;
- what public API, if any, must be introduced or preserved.

Before writing code, decide whether the work belongs in:

- a model;
- a manager;
- a utility;
- the controller;
- or a serializer.

### 2. Design the smallest correct abstraction

Prefer:

- small classes;
- explicit constructors;
- immutable values where practical;
- copy-style updates or clear mutation boundaries;
- named methods over boolean-heavy generic helpers.

Avoid:

- giant multi-purpose classes;
- hidden side effects;
- weakly typed `Map<String, dynamic>` passing between layers unless it is strictly for serialization boundaries.

### 3. Implement with clear ownership

- put storage fields on the correct model;
- keep validation near the source of truth;
- put JSON conversion in serializer-aware code;
- keep controller methods focused on orchestration;
- keep reusable calculations in pure functions.

### 4. Preserve package ergonomics

The core API should stay clean for package consumers.

Prefer methods that read clearly from the outside, such as:

- `addNode(...)`
- `removeEdge(...)`
- `moveNode(...)`
- `toJson()`
- `fromJson(...)`

Internals may be more granular, but the public API should remain understandable.

### 5. Validate the change

At minimum:

- run static analysis when relevant;
- run or coordinate the relevant unit tests;
- confirm serialization round-trips for persisted models;
- confirm controller mutations do not leave the graph in an inconsistent state.

## Quality Gates

Backend work is not complete unless:

- every changed class has a clear single responsibility;
- logic is placed in the correct layer;
- the public API is coherent;
- serialization is lossless for supported fields;
- state mutations are testable and deterministic;
- no unnecessary package dependencies were introduced.

## Deliverables

The Backend / Core Logic Developer Agent should leave behind:

- production code in the correct `lib/` submodules;
- cleanly separated classes and helpers;
- updated exports if public API changed;
- unit-test-ready logic;
- a concise summary of architectural decisions.

## Definition of Done

The task is done when the new backend behavior is implemented with clean separation of responsibilities, the public API is sensible, and the logic is ready for reliable automated testing.
