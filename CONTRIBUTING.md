# Contributing to FlowCraft

Thanks for being here. FlowCraft is maintained by one person, so the rules below
exist to make your effort count — not to add ceremony.

The short version:

> **Open an issue first. Wait for a reply. Then write the code.**

A pull request that arrives without a discussed issue behind it is the most
common way good work gets wasted here. Read on for why.

---

## Contents

- [Start with an issue](#start-with-an-issue)
- [The workflow](#the-workflow)
- [Setting up](#setting-up)
- [Before you open a pull request](#before-you-open-a-pull-request)
- [Constraints you must not break](#constraints-you-must-not-break)
- [Code style](#code-style)
- [Tests](#tests)
- [Commit messages](#commit-messages)
- [Review and merging](#review-and-merging)
- [Reporting a security problem](#reporting-a-security-problem)

---

## Start with an issue

**Every change starts as an issue.** Bug fix, feature, refactor, typo in the
docs — open an issue, describe it, and wait for a response before writing code.

This is not bureaucracy. It is because:

- **Some things are deliberate.** This repository contains several decisions
  that look like bugs and are not: the macOS App Sandbox is switched off on
  purpose, the MCP port is hard-coded rather than falling back to a free one,
  `mcp_server/` is excluded from `flutter analyze`, and the app's lockfiles
  (`pubspec.lock`, `macos/Podfile.lock`, `ios/Podfile.lock` — not
  `mcp_server/pubspec.lock`) are gitignored. Each has a written reason in
  [`CLAUDE.md`](CLAUDE.md). A PR that "fixes" one of these will be closed, and
  you will have spent your evening for nothing.
- **The roadmap has an order.** Some of what looks missing is missing on
  purpose, waiting behind something else. The [roadmap](README.md#roadmap) says
  what is next and why.
- **Scope gets agreed up front.** It is much easier to say "make it half this
  size" in an issue than in a review of finished code.

Use the issue templates — they ask for the things that are actually needed to
reproduce or evaluate something.

**Exception:** an obvious typo or a broken link in the docs can go straight to a
PR. Nothing else.

### A good bug report

- What you did, what you expected, what happened instead.
- Your OS and version, and where you got FlowCraft (CI artifact or built from
  source, plus the commit).
- If it involves an AI agent: which CLI, and the prompt or tool call you sent.
- If it involves a saved project: whether the project file still opens.
  **Do not attach your auth token** — it is in `~/.flowcraft/control.token` and
  it is a secret. Redact it from any config you paste.

### A good feature request

Describe the problem, not the solution. "I can't tell which of three arrows is
selected" tells the maintainer more than "add an arrow highlight setting" —
sometimes the best fix for the problem you have is not the one you had in mind.

---

## The workflow

1. Open an issue. Wait for a reply.
2. Fork the repository.
3. Branch from `main`. Name it after the work: `fix/arrow-endpoint-drag`,
   `feat/svg-export`.
4. Make the change. Keep it to the one thing the issue is about.
5. Make sure `flutter analyze` and `flutter test` are both clean.
6. Open a pull request against `main` and link the issue (`Closes #123`).
7. Respond to review. The maintainer merges.

You cannot push to `main` directly and neither can anyone else — the branch is
protected. That is intentional, not a sign that something is wrong with your
access.

**One PR, one concern.** A PR that fixes a bug *and* reformats three files *and*
renames a class is three PRs. Split it. Reviews of mixed PRs are slow and end in
partial rejections that are miserable for everyone.

---

## Setting up

```bash
git clone https://github.com/<your-username>/flowcraft-app.git
cd flowcraft-app
flutter pub get
flutter run -d macos    # or -d windows / -d linux
```

macOS needs one extra step on a fresh checkout — a "prime, pod install, build
again" dance. It looks broken and it is not; the reason is written down in
[`CLAUDE.md`](CLAUDE.md). Do not try to simplify it away, in the repo or in CI.

Read [`CLAUDE.md`](CLAUDE.md) before your first change. It is short, and it is
the difference between a PR that lands and one that does not.

---

## Before you open a pull request

Both of these must be clean. CI gates all three platform builds on them, so a PR
that fails either will not merge no matter how good the idea is.

```bash
flutter analyze
flutter test
```

If your change touches anything platform-facing, also confirm the web target
still compiles — it is the canary for the conditional-import boundaries:

```bash
flutter build web
```

---

## Constraints you must not break

These are the ones that will get a PR rejected regardless of how well it is
written. All of them are explained in [`CLAUDE.md`](CLAUDE.md).

### Zero Flutter plugins

The app ships with **no** Flutter plugins, and this is load-bearing. It is why
the macOS build behaves the way it does, why export writes to a fixed folder
instead of opening a native save dialog, and why `lib/services/` uses
`_io` / `_stub` conditional-import pairs instead of `path_provider`.

If you think your change needs `file_picker`, `path_provider`, `share_plus` or
anything else with native code — stop and say so in the issue. There is almost
always a `dart:io` route, and if there genuinely is not, that is a decision for
the maintainer, not a detail of your PR.

The same goes for new pub dependencies generally. The MCP protocol is hand-rolled
on `dart:io` and `dart:convert` specifically so the app does not take an SDK
dependency for it.

### The file format is a public API

`SketchSerializer.schemaVersion` is `1`, and users have saved files.

- **Adding a field** with a `fromJson` default is safe in both directions and
  must **not** bump the version. This is the existing pattern — follow it.
- **Adding an element type** is breaking: older builds throw on an unknown
  `type`. It needs a version bump and a migration, and it needs to be agreed in
  the issue before you write it.

The same care applies to `~/.flowcraft/projects/` on disk, and to the MCP tool
names and schemas — people have those pasted into CLI configs and prompts.

### Tests must not bind a fixed port

Any test that pumps the app must override `mcpServerPortProvider` with `0`.
Reading `mcpViewModelProvider` starts a **real** `HttpServer`, and `flutter test`
runs test files in parallel — a fixed port makes two of your own test files race
each other, and lose to a FlowCraft window you have open. It shows up as a red CI
run that goes green on re-run, which is the most expensive kind of failure to
chase.

A test that needs a *taken* port must bind one itself on port `0` and inject the
port it got back. Never squat on `5199`.

### Riverpod 3 has no public `ChangeNotifierProvider`

`SketchController` stays a plain `ChangeNotifier` behind a non-reactive
`Provider` used for dependency injection only. Widgets that rebuild on canvas
edits listen through the controller's own `addListener`, not `ref.watch`.

---

## Code style

`flutter_lints`, plus the conventions the codebase already follows:

- **Comments explain *why*, not *what*.** Read a few files before writing any.
  A comment that restates the code will be asked about in review; one that
  records a decision or a trap is why this codebase is maintainable.
- **One responsibility per file.** Widgets past ~150 lines get split.
- **No hardcoded chrome colours in widgets.** Use
  `Theme.of(context).colorScheme`. Reaching into `AppColors.*` from a widget is
  a bug this repo has already fixed once — it broke the light/dark toggle.
- **No magic numbers in widgets.** Use the tokens in `lib/core/theme/`
  (`AppSpacing`, `AppRadius`, `AppTypography`).
- **No duplicated widgets or helpers.** Extract and import.
- `test/` mirrors `lib/` one-to-one.

---

## Tests

Every behavioural change needs a test, and the bar is specific:

**A regression test must fail before your fix and pass after it.** Actually check
that, by reverting your change and watching the test go red. A test that passes
either way documents nothing and protects nothing — and they are easy to write by
accident.

Say so in the PR description: what you reverted, and which tests failed.

For a bug fix, the test should encode the *user-visible* failure, not just the
internal state. "Clicking on existing text does not create a second text box" is
a better test than "`topMostTextTarget` returns non-null".

---

## Commit messages

Single-line, prefixed, imperative, describing what actually changed:

```
fix: measure SketchText bounds so clicking existing text edits it instead of adding another
feat: import a scene from a file, a path or pasted JSON
docs: add the MIT license text the README already claimed
ci: drop the standalone mcp_server binary from the desktop build
chore: gitignore the local IconKitchen source-asset dump
```

Prefixes in use: `feat`, `fix`, `docs`, `test`, `ci`, `chore`, `refactor`.

Write the message for someone reading `git log` in a year with no memory of the
issue. `fix: bug` and `update code` say nothing. No body is required; if you need
one, keep it to why rather than what.

Do not add `Co-Authored-By` trailers for tools.

---

## Changelog

Substantial changes get an entry in `CHANGESLOGS/`, in a file named for the date
(`CHANGESLOGS/2026-08-22.md`). Match the existing format: `## New Features`,
`## Bug Fixes`, `## Code Quality`, with the *why* included — the changelog is
where the reasoning behind a decision survives after the PR discussion scrolls
away.

Small fixes do not need one. If in doubt, ask in the issue.

---

## Review and merging

**Every pull request is reviewed and merged by the maintainer.** `main` is
protected: it requires a pull request, a passing `Test` job, an approving review
from the code owner, and all review conversations resolved. The `Test` check
(`dart format`, `flutter analyze --fatal-infos`, `flutter test`) runs on every
PR; the three platform builds run only on pushes to `main` and on release tags.
Contributors never merge their own work; the maintainer merges via admin
override after review, which is also how the maintainer's own PRs land in a
one-person project.

What to expect:

- Review is not automatic and not instant. This is a one-person project.
- Expect questions. "Why this way?" is a request for the reasoning, not a
  rejection — and the answer often belongs in a comment in the code.
- A PR may be closed if the direction turns out to be wrong. That is much less
  likely to happen if you [started with an issue](#start-with-an-issue).
- If your PR sits with no reply for two weeks, a polite bump on the issue is
  welcome.

---

## Reporting a security problem

FlowCraft runs a local HTTP server and reads files from your home directory, so
security reports are taken seriously.

**Do not open a public issue for a vulnerability.** See
[`SECURITY.md`](SECURITY.md) for how to report one privately.

---

## License

By contributing, you agree that your contributions are licensed under the
project's [MIT License](LICENSE).
