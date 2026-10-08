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
├── models/              Immutable data (SketchElement, SketchStyle, SketchTool, FlowViewport, FlowProject, icon catalog)
├── viewmodels/           App state + Riverpod providers
│   ├── sketch_controller.dart   Canvas state (ChangeNotifier) + sketchControllerProvider
│   ├── sketch_history.dart
│   ├── theme_view_model.dart    Dark/light toggle
│   ├── projects_view_model.dart Saved-project library + which one the canvas is editing
│   ├── project_autosave.dart    Debounced write-behind for the active project
│   ├── scene_importer.dart      JSON / Excalidraw / Mermaid / DBML text → canvas
│   ├── canvas_preferences.dart  View-only switches (animate agent drawing)
│   └── mcp_view_model.dart      MCP control-server on/off, owns AppControlServer lifecycle
├── views/                Screens + presentation widgets (splash_view.dart,
│                          whiteboard_view.dart + widgets/)
├── services/              External I/O boundary — the MCP server, storage, JSON→element parsing
│   ├── flowcraft_control_server.dart  Loopback HTTP router (dart:io), owns auth + token
│   ├── mcp_http_handler.dart          MCP over Streamable HTTP: JSON-RPC on POST /mcp
│   ├── mcp_tools.dart                 The thirteen tools, as plain data + handlers
│   ├── mcp_guide.dart                 Text behind flowcraft_guide
│   ├── mcp_checkpoints.dart           In-memory canvas snapshots, per project
│   ├── mcp_host.dart                  Project operations the tools may call
│   ├── project_repository.dart        Saved projects in ~/.flowcraft/projects (io/stub split)
│   ├── canvas_exporter.dart           Scene → PNG bytes / export file (io/stub split)
│   ├── svg_exporter.dart              Scene → SVG
│   ├── export_file_sink.dart          Checked write-to-path for exports (io/stub split)
│   ├── image_source.dart              Image path / data URL → bytes (io/stub split)
│   ├── diagram_spec.dart              JSON → SketchElement
│   ├── diagram_layout.dart            Nodes + edges → laid-out elements
│   └── text_import/                   Mermaid, DBML, Excalidraw parsers
└── core/                  Framework-agnostic infra: canvas, domain, rendering, interactions,
                            serialization, utils
```

`test/` mirrors `lib/` 1:1.

**The MCP server lives inside the app.** `FlowcraftControlServer` binds one loopback
`HttpServer` and serves `/mcp` — a spec-compliant MCP endpoint over the **Streamable HTTP**
transport — straight into the live `SketchController`. Users register the running app with
`claude mcp add --transport http flowcraft http://127.0.0.1:5199/mcp --header "X-Flowcraft-Token: <token>"`;
the MCP card in `views/widgets/mcp_card.dart` copies that line (and shows per-CLI config)
with the real port/token filled in. No second process, no extra download.

The protocol is hand-rolled on `dart:io` + `dart:convert` — deliberately, and it must stay
that way: `package:dart_mcp` is stdio-only, so it could not serve this endpoint even if the
app took the dependency. Keep the app at **zero new pubspec dependencies**.

**Any test that pumps the app must override `mcpServerPortProvider` with 0.** Reading
`mcpViewModelProvider` — which `SplashView`/`WhiteboardView` do — starts a *real* `HttpServer`.
`flutter test` runs test files in parallel, so a fixed port makes two files race each other
and lose to the developer's own running FlowCraft window; that shows up as a red CI build
that goes green on re-run. `ProviderScope(overrides: [mcpServerPortProvider.overrideWithValue(0)])`
(or `ProviderContainer(overrides: ...)`) lets the OS pick a free port per test. Tests that
need a *taken* port must bind one themselves on port 0 and inject the port they got back —
never squat on 5199.

**Port 5199 is fixed on purpose — don't add an ephemeral-port fallback.** Users paste the
endpoint into a CLI config once; a port that changes per launch would silently break that
saved config with no error anywhere. When the bind fails (almost always a stale FlowCraft
instance), `McpViewModel` lands in `McpServerState.failed` with a reason and the card shows
it plus a Retry — the endpoint and connect command are withheld, because a connect command
pointing at a dead port fails later, elsewhere, and silently.

`mcp_server/` is a **separate, isolated Dart package** (own `pubspec.yaml`), excluded from
`flutter analyze` via `analysis_options.yaml`. It is now an **optional legacy stdio bridge**,
kept only for MCP clients that can't speak HTTP; it drives the app's original REST endpoints
(`/health`, `/draw`, `/clear`), which `FlowcraftControlServer` still serves alongside `/mcp`.
Don't delete those endpoints or their tests. See `mcp_server/README.md`.

**Projects persist to `~/.flowcraft/projects/`** — one JSON file per whiteboard, written
atomically (temp file + rename), with `index.json` beside them as a *cache only*:
`ProjectRepository.list()` cross-checks it against the scene files actually on disk and
rebuilds it from their headers whenever they disagree, so a lost or corrupt index can never
cost a user their work. Don't turn that index into the source of truth. Scene payloads go
through `SketchSerializer`, inheriting its versioning and stroke simplification.

**Opening a project must use `SketchController.loadScene`, not `replaceAll`.** `replaceAll`
snapshots the outgoing scene into undo history, so a Ctrl+Z straight after a project switch
would pull the *previous* project's elements onto this canvas — and autosave would then
persist them into the wrong file. `loadScene` discards history and any in-flight drag or
text edit along with it.

## Gotchas — read before touching these areas

- **Zero Flutter plugins, and that is load-bearing.** It is what the macOS CocoaPods gotcha
  below is about. It is also why export writes to `~/Documents/FlowCraft/` instead of showing
  a native save dialog, and why `services/` uses `_io`/`_stub` conditional-import pairs
  (`app_control`, `project_repository`, `export_file_sink`) rather than `path_provider`.
  Adding `file_picker` / `file_selector` / `path_provider` changes the macOS build's
  behaviour — don't, without deciding that tradeoff deliberately.
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

`.github/workflows/build-desktop.yml`, triggered on push to `main`:
- `test` job (`flutter analyze` + `flutter test`) gates all three build jobs via `needs:`.
- `build-macos` / `build-windows` / `build-linux` publish **only** the app installer. They
  used to also cross-compile the `mcp_server` binary; that was dropped when the MCP server
  moved in-process — the installer is now the single artifact an end user needs.

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