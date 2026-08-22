# Security Policy

FlowCraft binds a local HTTP server, holds an auth token on disk, reads and
writes files under your home directory, and turns JSON sent by an AI agent into
canvas elements. Security reports are welcome and taken seriously.

## Reporting a vulnerability

**Please do not open a public issue.**

Use GitHub's private vulnerability reporting instead:
[**Report a vulnerability**](https://github.com/alisheraxmedov/flowcraft-app/security/advisories/new).
It is private between you and the maintainer until a fix is published.

Helpful things to include:

- What an attacker can do, and what they need in order to do it (already on the
  machine? able to write to `~/.flowcraft/projects/`? a web page the user
  visits?).
- Steps to reproduce, or a proof of concept.
- The affected version or commit, and your platform.

**Never include your own auth token** (`~/.flowcraft/control.token`) in a report.
It is a live secret. Redact it from any config or request you paste.

Expect a first response within about a week. This is a one-person project, so
please be patient with the timeline — but do follow up if it goes quiet.

## Scope

In scope:

- The local control server and the MCP endpoint (`lib/services/`) — auth,
  `Origin` validation, resource limits, anything reachable over
  `127.0.0.1:5199`.
- Project storage in `~/.flowcraft/projects/` — path handling, and what a
  crafted project file can do to someone who opens it.
- Export and import — filename handling, and what a crafted scene file can do.
- The auth token: how it is generated, stored, and its file permissions.

Out of scope, because they are deliberate and documented in
[`CLAUDE.md`](CLAUDE.md):

- **The macOS App Sandbox is disabled on purpose.** A sandboxed app's `$HOME`
  resolves to its container, so the app would write its token where the MCP
  client never looks and every draw call would fail auth.
- **The MCP port is fixed at 5199 on purpose**, rather than falling back to a
  free one. A port that changed per launch would silently invalidate the config
  users saved in their CLI.
- **Anything holding the token can draw on the canvas.** That is what the token
  is for. Drawing on a whiteboard is the entire privilege it grants.
- Attacks that require an attacker to already have arbitrary code execution as
  your user.

## What FlowCraft does to protect you

Stated so you can check the claims against the source rather than take them on
trust:

- The control server binds `127.0.0.1` only — nothing on your network can reach
  it.
- Every request must carry a 256-bit token generated with `Random.secure()`,
  stored owner-readable-only at `~/.flowcraft/control.token`.
- Requests carrying a non-local `Origin` header are refused before auth is even
  considered — the DNS-rebinding defence the MCP transport spec requires of
  local servers. There are no CORS headers anywhere.
- Request bodies and per-call element counts are capped.
- Project ids are validated before they are ever composed into a filesystem
  path, so a crafted project file cannot reach outside the projects directory.
- No telemetry, no analytics, no crash reporting, no update pings, and no
  outbound network requests of any kind.
- Zero Flutter plugins, so there is no third-party native code in the bundle.

## Supported versions

FlowCraft has not cut a tagged release yet. Fixes land on `main`; until releases
exist, the latest `main` is the supported version.
