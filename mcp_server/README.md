# flowcraft_mcp_server

Isolated MCP bridge for FlowCraft. Lets Claude Code, Codex CLI, Gemini CLI
(or any MCP-capable client) draw diagrams live on a running **FlowCraft**
desktop app, by analyzing your codebase and calling a tool instead of
returning text.

## Why a separate process

`package:dart_mcp` only supports the **stdio** transport today — no
HTTP/SSE. Stdio servers are spawned as a child process by the AI CLI, which
owns their stdin/stdout. That can't be the same process as the FlowCraft
GUI app (a long-lived, user-launched window). So this package is a small,
independent bridge:

```
AI CLI (Claude Code / Codex / Gemini CLI)
   │  spawns via stdio, owns stdin/stdout
   ▼
flowcraft_mcp_server  (this package)
   │  plain HTTP, loopback only, token-authenticated
   ▼
FlowCraft desktop app's embedded control server
   (example/lib/control/flowcraft_control_server.dart)
   │  direct method calls, no IPC
   ▼
SketchController  →  repaints the canvas
```

The `flowcraft` package itself (`lib/`) is untouched and stays a
dependency-free widget library — it doesn't know MCP exists.

## Build

```bash
cd mcp_server
dart pub get
dart compile exe bin/flowcraft_mcp_server.dart -o build/flowcraft_mcp_server
```

Compiling to a native executable avoids Dart-SDK startup overhead on every
tool call from the AI CLI. Re-run this after pulling changes.

## Register with an AI CLI

The FlowCraft app must be running (it starts its control server
automatically on desktop platforms) before `flowcraft_draw` works —
`flowcraft_launch` can start it for you if it knows where to find it.

If FlowCraft isn't installed at one of the well-known locations, set
`FLOWCRAFT_APP_PATH` to its executable (or `.app` bundle on macOS) when
registering the server below.

### Claude Code

```bash
claude mcp add flowcraft -- /absolute/path/to/build/flowcraft_mcp_server
# with an explicit app path:
claude mcp add flowcraft -e FLOWCRAFT_APP_PATH=/Applications/FlowCraft.app \
  -- /absolute/path/to/build/flowcraft_mcp_server
```

### Codex CLI

In `~/.codex/config.toml` (or a project-scoped `.codex/config.toml`):

```toml
[mcp_servers.flowcraft]
command = "/absolute/path/to/build/flowcraft_mcp_server"

[mcp_servers.flowcraft.env]
FLOWCRAFT_APP_PATH = "/Applications/FlowCraft.app"
```

### Gemini CLI

In `~/.gemini/settings.json` (or a project-scoped `.gemini/settings.json`):

```json
{
  "mcpServers": {
    "flowcraft": {
      "command": "/absolute/path/to/build/flowcraft_mcp_server",
      "args": [],
      "env": {
        "FLOWCRAFT_APP_PATH": "/Applications/FlowCraft.app"
      }
    }
  }
}
```

Flag/field names occasionally change between CLI versions — check
`claude mcp add --help` (or the equivalent) if a command above is rejected.

## Tools

| Tool | Purpose |
| --- | --- |
| `flowcraft_status` | Checks whether the FlowCraft app is reachable. |
| `flowcraft_launch` | Starts the app (best-effort) and waits until ready. |
| `flowcraft_draw` | Draws shapes: `{mode?: "add"\|"replace", elements: [...]}`. |
| `flowcraft_clear` | Clears the canvas. |

`elements[]` entries: `{type, x, y, width, height, text, fontSize,
strokeColor, fillColor}` for `rectangle` / `ellipse` / `diamond` /
`triangle` / `sticky`; `{type: "text", x, y, text, fontSize}`;
`{type: "arrow" | "line", fromX, fromY, toX, toY}`. Everything besides
`type` is optional.

Example prompt once registered:

> Study `../my-project/` and draw its class model on FlowCraft.

## Test

```bash
dart analyze
```

(No unit tests here yet — the HTTP/parsing logic it drives is covered by
`example/test/control/flowcraft_control_server_test.dart`, which exercises
the same wire format this bridge sends.)
