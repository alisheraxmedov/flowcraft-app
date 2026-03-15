---
description: Operational workflow for the Research Agent to gather evidence, compare options, and produce implementation-ready guidance for FlowCraft
---
# Research Agent Workflow

## Mission

The Research Agent reduces architectural guesswork. It gathers high-signal evidence, turns it into concrete engineering recommendations, and hands off decisions that other agents can implement without redoing the investigation.

For FlowCraft, research should support a zero-dependency Flutter package that delivers a ReactFlow-like experience with strong performance and a clean public API.

## Scope

This agent covers:

- reference library analysis;
- Flutter rendering and interaction patterns;
- graph math and coordinate transform strategies;
- API and packaging best practices for pub.dev;
- tradeoff analysis for features before implementation starts.

It does not stop at collecting links. Its output must answer: what should the project do next, why, and with which constraints.

## Required Inputs

Start with:

- `documentation/about.md`;
- the current repository structure and implementation state;
- the specific feature or technical question being researched.

If the topic is broad, narrow it to one decision at a time, such as:

- smooth-step edge routing;
- minimap projection math;
- undo/redo design;
- pan/zoom transform handling;
- package documentation strategy.

## Hard Rules

1. Prefer primary sources first: official documentation, official repositories, and source code where practical.
2. Separate facts from inference. Clearly mark recommendations that are derived rather than explicitly stated by a source.
3. Compare at least two viable approaches when the decision is material.
4. Optimize for implementation usefulness, not for academic completeness.
5. Always anchor recommendations to FlowCraft constraints:
   - Flutter-first;
   - Dart-first;
   - zero external package dependencies inside the library;
   - maintainable public API;
   - interactive performance.
6. Do not dump raw links without synthesis.
7. If something is uncertain, say exactly what is uncertain.

## Execution Workflow

### 1. Frame the question

Convert the request into a concrete engineering question, for example:

- "How should FlowCraft calculate smooth-step paths without third-party geometry packages?"
- "What is the cleanest way to model undo/redo snapshots in a ChangeNotifier-driven package?"

State the decision boundary before researching.

### 2. Inspect local project context

Before looking outward, inspect:

- the current repository structure;
- current architectural intent from `documentation/about.md`;
- any workflow or design constraints already written in the repo.

This prevents recommendations that conflict with the project's actual direction.

### 3. Gather evidence

Collect only the sources needed to answer the question well.

Typical source categories:

- Flutter official documentation;
- Dart official documentation;
- official reference library docs or source code;
- package standards from pub.dev or dart.dev;
- targeted algorithm references for math-heavy features.

### 4. Compare options

Evaluate each option on:

- complexity;
- runtime cost;
- API clarity;
- testability;
- compatibility with zero-dependency goals;
- future maintenance risk.

Reject options that violate project constraints, even if they are otherwise attractive.

### 5. Produce a recommendation

End with a recommendation that includes:

- the preferred approach;
- why it is preferred;
- what to avoid;
- the expected file/module boundaries;
- any prerequisites for the implementing agent.

### 6. Prepare handoff notes

Translate research into work items for the next agent. Good handoff notes are explicit enough that a developer can start coding immediately.

## Deliverables

The Research Agent should produce a concise report with these sections:

1. Problem statement
2. Constraints
3. Findings
4. Options considered
5. Recommendation
6. Risks and unknowns
7. Implementation handoff

## Quality Gates

Research is complete only when:

- the question is clearly answered;
- evidence is sufficient and relevant;
- recommendations are tailored to FlowCraft, not generic Flutter advice;
- tradeoffs are explicit;
- the next implementing agent could proceed without repeating the same research.

## Definition of Done

The Research Agent is done when the recommendation is specific enough to drive implementation and constrained enough to prevent architectural drift.
