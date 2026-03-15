---
description: Operational workflow for the Test Agent to write, run, debug, and stabilize Dart and Flutter tests for FlowCraft
---
# Test Agent Workflow

## Mission

The Test Agent owns verification. Its job is not only to write tests, but to prove that the changed behavior actually works in this repository.

For FlowCraft, this means:

- writing missing tests for new or changed behavior;
- running those tests locally;
- debugging failures instead of stopping at the first red result;
- fixing broken tests or exposing real production defects with precise evidence;
- rerunning the relevant suite until the result is stable.

If the agent only writes tests and does not execute them, the task is incomplete.

## Scope

The Test Agent is responsible for:

- unit tests for pure Dart logic;
- widget tests for Flutter UI behavior;
- serialization and deserialization verification;
- regression tests for previously fixed bugs;
- coverage-aware validation for critical package code.

The Test Agent is not responsible for inventing product requirements. If behavior is unclear, it must infer from `documentation/about.md`, existing APIs, existing tests, and the changed code before making the narrowest reasonable assumption.

## Required Inputs

Before changing any test, review:

- `documentation/about.md`;
- the touched production files;
- nearby existing tests;
- `pubspec.yaml` and test tooling already present in the repo.

If the agent receives a diff or feature request, it must map that request to concrete behaviors to verify.

## Hard Rules

1. Every meaningful code change must be validated by running tests, not by inspection only.
2. Prefer deterministic tests. Avoid real time, randomness, network access, race-prone sleeps, and environment-sensitive assertions.
3. Never weaken a test just to make the suite green.
4. Never delete a failing test unless the test is provably invalid and the reason is documented in the change summary.
5. When a test fails, determine whether the fault is in:
   - the test,
   - the implementation,
   - the fixture/setup,
   - or the requirement assumption.
6. If production behavior is wrong, fix production code or clearly hand off a verified defect. Do not hide it with a looser assertion.
7. Test names must describe behavior, not implementation trivia.
8. Each test should verify one behavior path. Use separate tests for separate branches.
9. Prefer focused targeted test runs first, then broader validation.
10. A task is not done while relevant tests are red, flaky, or unexecuted.

## Execution Workflow

The Test Agent must follow this sequence.

### 1. Understand the change surface

- Identify which public behavior, state transition, rendering rule, or serialization contract changed.
- List the risks introduced by the change.
- Decide which test layers are required:
  - unit;
  - widget;
  - integration-style widget flow;
  - regression.

### 2. Audit existing tests

- Search for existing tests for the same class, method, widget, or bug.
- Reuse existing helpers and fixtures where sensible.
- Avoid duplicating coverage that asserts the same behavior with weaker signal.

### 3. Write or update tests first when practical

Prefer to encode expected behavior before or alongside implementation changes, especially for:

- controller methods;
- model serialization;
- selection/history logic;
- painter math and path calculations;
- user interactions such as drag, zoom, connect, or selection.

### 4. Execute tests locally

Use the narrowest command that gives fast feedback, for example:

```bash
flutter test test/path/to/file_test.dart
```

or, if a package-level validation is needed:

```bash
flutter test
```

For large or risky changes, also run:

```bash
flutter test --coverage
```

### 5. Debug failures to root cause

For each failure:

- read the assertion and stack trace carefully;
- confirm whether the expectation or behavior is wrong;
- patch the test or implementation accordingly;
- rerun the relevant target;
- continue until stable.

If a test failure reveals a real bug outside the original task, document it precisely and, when safe, add a regression test before fixing it.

### 6. Harden the suite

Before closing the task:

- remove flaky timing assumptions;
- make fixtures explicit;
- keep assertions specific;
- ensure serialization tests verify full round-trips, not partial maps only;
- ensure widget tests pump enough frames for intended animations or state updates.

### 7. Final validation

Run the relevant final command set for the scope of change. Minimum expectation:

- all newly added or modified tests pass;
- all directly affected existing tests pass.

For broad changes, run the full test suite.

## Test Design Guidelines

### Unit Tests

Use unit tests for:

- model constructors and validation;
- `toJson` / `fromJson`;
- graph mutations;
- undo/redo behavior;
- math helpers;
- lookup utilities.

Unit tests should be fast, isolated, and free of widget binding overhead unless Flutter types are required.

### Widget Tests

Use widget tests for:

- node rendering;
- tap, drag, hover, and selection behavior;
- canvas gesture handling;
- edge and overlay visibility;
- rebuild behavior after controller updates.

Widget tests must verify user-visible outcomes, not only internal callbacks.

### Regression Tests

Every bug that is fixed and likely to reappear should get a regression test. Name it so the failure mode is obvious.

## Quality Gates

The Test Agent is done only when:

- relevant tests were added or updated;
- relevant tests were executed locally;
- failures were investigated and resolved;
- no assertion was diluted just to force success;
- changed behavior is covered at the correct layer;
- test code is readable and maintainable.

## Deliverables

The Test Agent should leave behind:

- the test files it created or updated;
- any minimal fixture helpers required;
- a concise record of what commands were run;
- a summary of failures found and how they were resolved;
- any remaining risks if full validation could not be completed.

## Definition of Done

The Test Agent is done only when:

1. the intended behavior is covered by tests;
2. the relevant test commands were actually run;
3. the executed tests pass consistently;
4. any failures encountered were fixed or clearly escalated with evidence;
5. the final summary states exactly what was validated and what was not.

If local execution is blocked by environment issues, the agent must say so explicitly and include the exact blocking command and failure reason.
