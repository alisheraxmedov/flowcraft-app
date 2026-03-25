# 14 — Execution Engine

FlowCraft includes a built-in workflow execution engine that runs node-based logic as directed acyclic graphs (DAGs). This module powers automation workflows independent of the visual canvas.

## Architecture

```
┌─────────────────────────────────────────┐
│            ExecutionEngine              │
│  ┌─────────────────────────────────┐    │
│  │  Topological Sort (DAG order)   │    │
│  └──────────┬──────────────────────┘    │
│             ▼                           │
│  ┌─────────────────────────────────┐    │
│  │  Sequential Node Execution      │    │
│  │  ┌───────────────────────────┐  │    │
│  │  │ ExecutionContext           │  │    │
│  │  │  • inputData (upstream)   │  │    │
│  │  │  • params (user config)   │  │    │
│  │  │  • credentials (secrets)  │  │    │
│  │  └───────────────────────────┘  │    │
│  └──────────┬──────────────────────┘    │
│             ▼                           │
│  ┌─────────────────────────────────┐    │
│  │  ExecutionResult per node       │    │
│  │  → success / error / skipped    │    │
│  └─────────────────────────────────┘    │
│             ▼                           │
│  ┌─────────────────────────────────┐    │
│  │  WorkflowResult (aggregate)     │    │
│  └─────────────────────────────────┘    │
└─────────────────────────────────────────┘
```

## Core Classes

### ExecutionEngine

Orchestrates workflow execution. Performs topological sort on the graph nodes and executes them sequentially, passing outputs from upstream nodes as inputs to downstream nodes.

### NodeDefinition (abstract)

Base class for all executable nodes. Implementations must define:

- `typeId` — unique string identifier
- `displayName`, `category`, `description` — metadata for UI
- `inputs` / `outputs` — typed port definitions
- `params` — configurable parameters
- `execute(ExecutionContext)` — async execution logic

### NodeDefinitionRegistry

A lookup map from `typeId → NodeDefinition`. Register nodes before execution:

```dart
final registry = NodeDefinitionRegistry();
registry.register(TriggerNodeDef());
registry.register(ConditionNodeDef());
```

### ExecutionContext

Provides runtime data to each node during execution:

| Property | Type | Description |
|----------|------|-------------|
| `nodeId` | `String` | Current node's unique ID |
| `inputData` | `Map<String, dynamic>` | Data from upstream nodes |
| `params` | `Map<String, dynamic>` | User-configured parameters |
| `credentials` | `Map<String, dynamic>` | Secrets (API keys, tokens) |

Type-safe accessors: `getInput<T>()`, `getParam<T>()`, `getCredential()`.

### ExecutionResult

Per-node result with three factory constructors:

- `ExecutionResult.success(nodeId, outputData)` — node completed successfully
- `ExecutionResult.error(nodeId, message)` — node failed
- `ExecutionResult.skipped(nodeId)` — node was skipped

### WorkflowResult

Aggregates all `ExecutionResult`s:

- `isSuccess` / `isError` — overall status
- `outputOf(nodeId)` — get specific node output
- `errors` — list of all error messages

## Built-in Node Definitions

### Core Nodes

| Node | TypeId | Description |
|------|--------|-------------|
| **Trigger** | `trigger` | Starts workflow, passes payload to first node |
| **Condition** | `condition` | Routes by field comparison (exists, equals, notEquals, contains, greaterThan, lessThan) |
| **Transform** | `transform` | Modifies data: set, rename, remove, keep fields |
| **Merge** | `merge` | Combines data from multiple inputs |
| **Output** | `output` | Terminal node, collects final result |

### Flow Nodes

| Node | TypeId | Description |
|------|--------|-------------|
| **Variable** | `variable` | set/get/setAndGet named values |
| **Loop** | `loop` | Iterates over list fields with maxIterations safety |
| **Delay** | `delay` | Pauses execution for N milliseconds |
| **Error Handler** | `error_handler` | Catches errors, supports fallback data and continueOnError |

### Integration Nodes

| Node | TypeId | Description |
|------|--------|-------------|
| **Gemini** | `gemini` | Google Gemini AI text generation |
| **OpenAI** | `openai` | OpenAI GPT chat completion |
| **HTTP Request** | `http_request` | REST client (GET/POST/PUT/DELETE) |
| **Webhook** | `webhook` | Webhook receiver/sender |
| **Telegram** | `telegram` | 18 Telegram Bot API actions |
| **Telegram Trigger** | `telegram_trigger` | Polling trigger for incoming events |

## ParamDefinition Types

| Type | Usage |
|------|-------|
| `string` | Text input |
| `number` | Numeric input |
| `boolean` | Toggle |
| `select` | Dropdown from options list |
| `json` | JSON editor |
| `code` | Code editor |
| `credential` | Secret/token input |

## PortDefinition Types

| Type | Usage |
|------|-------|
| `string` | Text data |
| `number` | Numeric data |
| `boolean` | Boolean data |
| `json` | Structured data (most common) |
| `list` | Array data |
| `any` | Any type |
