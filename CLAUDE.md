# FlowCraft

An interactive whiteboard **desktop app** (macOS, Windows, Linux) built with
Flutter. Not a pub.dev package — the repo root *is* the app. A built-in MCP
control server lets AI coding agents (Claude Code, Codex CLI, Gemini CLI)
draw diagrams live on the running canvas.

## Architecture: MVVM + Riverpod

```
lib/
├── main.dart          Entry point — wraps app in ProviderScope
├── app.dart            MaterialApp host, reads ThemeViewModel
├── flowcraft.dart       Barrel export of the public API
├── models/              Immutable data (SketchElement, SketchStyle, SketchTool, FlowViewport)
├── viewmodels/           App state + Riverpod providers
│   ├── sketch_controller.dart   Canvas state (ChangeNotifier) + sketchControllerProvider
│   ├── sketch_history.dart
│   ├── theme_view_model.dart    Dark/light toggle
│   └── mcp_view_model.dart      MCP control-server on/off, owns AppControlServer lifecycle
├── views/                Screens + presentation widgets (whiteboard_view.dart + widgets/)
├── services/              External I/O boundary — MCP control server, JSON→element parsing
└── core/                  Framework-agnostic infra: canvas, domain, rendering, interactions,
                            serialization, utils
```

`test/` mirrors `lib/` 1:1.

`mcp_server/` is a **separate, isolated Dart package** (own `pubspec.yaml`), not part of
the app. It's the actual MCP stdio server an AI CLI spawns; it talks to the app's
`services/flowcraft_control_server.dart` over loopback HTTP (token-authenticated). It's
isolated because `package:dart_mcp` only supports stdio (no HTTP/SSE), so it can't live in
the same process as the long-lived GUI app. See `mcp_server/README.md`.

## Gotchas — read before touching these areas

- **Riverpod 3 has no public `ChangeNotifierProvider`.** `SketchController` stays a plain
  `ChangeNotifier`, exposed via a non-reactive `Provider<SketchController>` for DI only.
  Widgets that need to rebuild on canvas edits (`WhiteboardCanvas`, `SketchToolbarRich`)
  listen via the controller's own `addListener`, not `ref.watch`. Don't try to wrap it in
  `ChangeNotifierProvider` — it was removed from `flutter_riverpod`'s public exports.
- **macOS build needs a "prime, pod install, build again" dance.** This app has zero
  Flutter plugins, so `flutter build macos` skips its usual CocoaPods bookkeeping
  (`hasPlugins()` check in flutter_tools) — but the Xcode project's "Check Pods
  Manifest.lock" phase still runs and fails on a fresh checkout. Fix: run
  `flutter build macos --release` once (expected to fail, but it applies Podfile/project
  migrations), then `pod install` in `macos/`, then build again for real. Already encoded
  in `.github/workflows/build-desktop.yml` — don't "simplify" it back to one build step.
- **macOS App Sandbox is deliberately disabled** (`com.apple.security.app-sandbox = false`
  in both `macos/Runner/*.entitlements`). Re-enabling it silently breaks the MCP control
  server: a sandboxed app's `$HOME` resolves to its container path
  (`~/Library/Containers/com.flowcraft.app/Data/...`), so the app writes its auth token
  somewhere `mcp_server` never looks, and every MCP draw call 401s.
- **`pubspec.lock`, `macos/Podfile.lock`, `ios/Podfile.lock` are gitignored on purpose** —
  a deliberate churn-reduction choice for this app (not the usual "libraries shouldn't
  commit pubspec.lock" reasoning). Regenerated automatically by `flutter pub get` /
  `pod install`; don't force-add them.
- Bundle/application id is `com.flowcraft.app` everywhere (macOS, Windows product name,
  Linux `APPLICATION_ID`, Android `applicationId`, iOS `PRODUCT_BUNDLE_IDENTIFIER`). Binary
  name is `flowcraft` (not `flowcraft_example`).

## Commands

```bash
flutter pub get
flutter analyze
flutter test
flutter build macos --release    # see the CocoaPods gotcha above first
flutter build windows --release
flutter build linux --release
```

## CI/CD

`.github/workflows/build-desktop.yml`, triggered on push to `feature/flowcraft-app`:
- `test` job (`flutter analyze` + `flutter test`) gates all three build jobs via `needs:`.
- `build-macos` / `build-windows` / `build-linux` each also cross-compile and publish a
  pre-built `mcp_server` binary as a workflow artifact, so end users never need the Dart
  SDK to use the MCP integration.

### Mandatory agent delegation
When the user asks to **IMPLEMENT** or **RESEARCH** something, you MUST delegate the
work to the matching agency agent(s) via the Agent tool — pick by the prompt's topic:

| Agent | Use for |
|---|---|
| `Frontend Developer` | Vue/React/Angular UI, components, page speed |
| `AI Engineer` | ML models, AI integration, data pipelines |
| `Backend Architect` | API design, DB architecture, scaling |
| `Software Architect` | System design, DDD, architecture decisions |
| `Senior Developer` | Complex implementation, advanced patterns |
| `Code Reviewer` | Code review, security, edge-case hunting |
| `Database Optimizer` | Postgres/MySQL tuning, slow queries, indexing |
| `Performance Benchmarker` | Speed tests, load tests, optimization |
| `Git Workflow Master` | Branch strategy, commits, git history cleanup |
| `UI Designer` | Visual design, component libraries, design systems |
| `UX Architect` | Technical architecture, CSS systems, developer foundations |
| `Mobile App Builder` | Native iOS/Android, cross-platform apps |
| `Trend Researcher` | Market/trend research, community signals |
| `Sprint Prioritizer` | Picking the right thing to build at the right time |
| `Reality Checker` | Feasibility / reality check of an idea |
| `Codebase Onboarding Engineer` | Understanding unfamiliar code, tracing paths across API/Celery/LangGraph layers |
| `Codebase Archaeologist` | Drift audit after multiple AI tools touched the repo |
| `Minimal Change Engineer` | Smallest viable diff — fixes only what was asked, refuses scope creep |
| `Data Engineer` | ETL/ELT pipelines, lakehouse, data infrastructure |
| `Autonomous Optimization Architect` | API perf shadow-testing with cost/security guardrails |
| `SRE (Site Reliability Engineer)` | SLO/error budgets, observability, Celery queue toil reduction |
| `UX Researcher` | Usability testing, user behaviour analysis |
| `UI Finish-Gate Reviewer` | Catching generic/unfinished UI before it ships |
| `Accessibility Auditor` | WCAG audit, assistive-technology testing |
| `Evidence Collector` | QA that demands visual proof — screenshots, repro steps |
| `AI-Generated Code Security Auditor` | Secrets, broken access control, prompt injection in AI-written code |
| `Test Automation Engineer` | Playwright E2E, flake elimination, CI parallelization |
| `API Tester` | Endpoint contract validation + load testing |

Trivial one-liner edits may be done directly; anything substantive goes through agents.