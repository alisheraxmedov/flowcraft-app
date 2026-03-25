# FlowCraft

**ReactFlow-style interactive node-based flow diagrams + workflow execution engine for Flutter.**

[![pub.dev](https://img.shields.io/pub/v/flowcraft.svg)](https://pub.dev/packages/flowcraft)
[![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)
[![Flutter](https://img.shields.io/badge/Flutter-%E2%89%A51.17.0-02569B.svg)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-%E2%89%A53.10.0-0175C2.svg)](https://dart.dev)

FlowCraft is an open-source Flutter package that combines a fully interactive visual flow canvas with a powerful workflow execution engine — **with zero external dependencies**. Build visual diagrams, automate workflows, and integrate with Telegram, AI models, and HTTP APIs.

```
 ┌──────────────┐          ┌──────────────┐          ┌──────────────┐
 │  ▶ Start      │──bezier─►│  Process     │──step───►│  ■ End        │
 └──────────────┘          └──────────────┘          └──────────────┘
       input                   default                    output
```

---

## ✨ Features

### 🎨 Visual Canvas
- **Interactive Canvas** — Infinite 2D workspace with pan, zoom, and configurable grid
- **Node System** — 4 built-in types (default, input, output, custom) + custom node registry
- **Edge Routing** — Bezier curves, smooth step (right-angle), and straight lines
- **Animated Edges** — Flowing dashed animations using `PathMetrics`
- **Undo/Redo** — Command Pattern history with configurable depth
- **Serialization** — Full JSON save/load of the entire graph state
- **Multi-Select** — Lasso selection and group drag
- **Overlays** — Minimap, zoom controls, and floating toolbar
- **Theming** — Complete light/dark themes + fully customizable `FlowTheme`

### ⚡ Execution Engine
- **Workflow Engine** — Topological-sort-based sequential node execution
- **14 Built-in Nodes** — Trigger, Condition, Transform, Loop, Delay, Variable, Merge, Output, Error Handler, HTTP, Webhook, Gemini, OpenAI, Telegram
- **Telegram Bot** — 18 API actions + polling trigger (N8N-style)
- **AI Integration** — Gemini and OpenAI node definitions
- **HTTP/Webhook** — Full REST client + webhook receiver nodes
- **329 Tests** — Comprehensive unit test coverage

### 🔒 Architecture
- **Zero Dependencies** — Only Flutter SDK. No external packages.
- **Modular** — Engine and canvas are independent layers

---

## 🚀 Quick Start

### Install

```bash
flutter pub add flowcraft
```

### Use

```dart
import 'package:flowcraft/flowcraft.dart';

class MyFlowScreen extends StatefulWidget {
  @override
  State<MyFlowScreen> createState() => _MyFlowScreenState();
}

class _MyFlowScreenState extends State<MyFlowScreen> {
  late final FlowController _controller;

  @override
  void initState() {
    super.initState();
    _controller = FlowController();

    final nodeA = _controller.addNode(
      label: 'Start',
      type: NodeType.input,
      position: const Offset(100, 100),
    );

    final nodeB = _controller.addNode(
      label: 'Process',
      position: const Offset(400, 250),
    );

    _controller.addEdge(
      sourceNodeId: nodeA.id,
      targetNodeId: nodeB.id,
      sourceHandleId: nodeA.handles[1].id,
      targetHandleId: nodeB.handles[0].id,
      style: const EdgeStyle(animated: true, color: Color(0xFF6366F1)),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FlowCanvas(
        controller: _controller,
        theme: FlowTheme.dark(),
        showMiniMap: true,
        showControls: true,
        gridType: GridType.dots,
      ),
    );
  }
}
```

---

## 🏗️ Architecture Overview

```
flowcraft/lib/
├── core/          ← Data models, enums, utilities
├── controller/    ← FlowController, HistoryManager, SelectionManager
├── canvas/        ← Canvas widget, gestures, viewport, grid
├── edges/         ← Edge routing (Bezier, SmoothStep, Straight) + animation
├── nodes/         ← Node widgets, registry, header, fields
├── handles/       ← Connection point widgets
├── interactions/  ← Drag, connect, select, context menu
├── overlays/      ← Minimap, controls, toolbar
├── theme/         ← Light/dark themes + customization
└── engine/        ← Workflow execution engine
    ├── execution_engine.dart      ← Topological sort + sequential execution
    ├── execution_context.dart     ← Runtime context (params, credentials)
    ├── execution_result.dart      ← Node execution results
    ├── workflow_result.dart       ← Aggregate workflow results
    ├── node_definition.dart       ← Abstract base for executable nodes
    ├── node_definition_registry.dart ← Type-based node registry
    └── nodes/                     ← 14 built-in node definitions
        ├── telegram_node_def.dart         ← 18 Telegram API actions
        ├── telegram_trigger_node_def.dart ← Polling trigger
        ├── gemini_node_def.dart           ← Google Gemini AI
        ├── openai_node_def.dart           ← OpenAI API
        ├── http_request_node_def.dart     ← REST client
        ├── webhook_node_def.dart          ← Webhook receiver
        ├── condition_node_def.dart        ← 6 operators
        ├── transform_node_def.dart        ← Data manipulation
        ├── loop_node_def.dart             ← List iteration
        ├── variable_node_def.dart         ← State management
        ├── delay_node_def.dart            ← Timed pause
        ├── merge_node_def.dart            ← Data merging
        ├── trigger_node_def.dart          ← Manual start
        ├── output_node_def.dart           ← Terminal output
        └── error_handler_node_def.dart    ← Error catching
```

---

## 📚 Documentation

Full documentation is available in the [`documentation/`](documentation/) directory:

| #  | Topic                | Description                                              |
|----|----------------------|----------------------------------------------------------|
| 01 | [Overview](documentation/01_overview.md) | Project overview, core concepts, features, tech stack |
| 02 | [Architecture](documentation/02_architecture.md) | Module structure, dependency graph, data flow, layer stack |
| 03 | [Getting Started](documentation/03_getting_started.md) | Installation, quick start guide, FlowCanvas parameters |
| 04 | [Core Models](documentation/04_core_models.md) | FlowNode, FlowEdge, FlowHandle, EdgeStyle, enums, utils |
| 05 | [Controller API](documentation/05_controller_api.md) | Complete FlowController public API reference |
| 06 | [Canvas](documentation/06_canvas.md) | Canvas engine, gestures, viewport transforms, grid |
| 07 | [Edges](documentation/07_edges.md) | Edge routing algorithms, animated dashes, arrows, labels |
| 08 | [Nodes](documentation/08_nodes.md) | Node types, custom registry, headers, fields, resize |
| 09 | [Interactions](documentation/09_interactions.md) | Drag, connection creation, lasso selection, context menu |
| 10 | [Overlays](documentation/10_overlays.md) | Minimap, zoom controls, node toolbar |
| 11 | [Theming](documentation/11_theming.md) | Light/dark themes, custom themes, FlowTheme properties |
| 12 | [Serialization](documentation/12_serialization.md) | JSON save/load, format specification |
| 13 | [Performance](documentation/13_performance.md) | Optimization strategies and best practices |
| 14 | [Engine](documentation/14_engine.md) | Execution engine, node definitions, workflow execution |
| 15 | [Telegram](documentation/15_telegram.md) | Telegram Bot integration (18 actions + trigger) |

---

## 🎨 Theming

FlowCraft includes built-in Light and Dark themes:

```dart
FlowCanvas(controller: controller, theme: FlowTheme.light());
FlowCanvas(controller: controller, theme: FlowTheme.dark());
```

Create custom themes with `copyWith()`:

```dart
final custom = FlowTheme.dark().copyWith(
  canvasColor: const Color(0xFF000000),
  nodeSelectedBorderColor: const Color(0xFFFF6B6B),
);
```

---

## 💾 Serialization

Save and load the entire graph state as JSON:

```dart
// Save
final json = controller.toJson();

// Load
controller.fromJson(json);
```

---

## ⚡ Execution Engine

FlowCraft includes a full workflow execution engine for automating node-based logic:

```dart
import 'package:flowcraft/flowcraft.dart';

// Register node definitions
final registry = NodeDefinitionRegistry();
registry.register(TriggerNodeDef());
registry.register(ConditionNodeDef());
registry.register(TransformNodeDef());
registry.register(TelegramNodeDef());

// Execute a workflow
final engine = ExecutionEngine(registry: registry);
final result = await engine.execute(graph);

if (result.isSuccess) {
  print('Workflow completed: ${result.nodeResults}');
}
```

### Built-in Node Definitions

| Category | Nodes |
|----------|-------|
| **Core** | Trigger, Condition (6 operators), Transform (set/rename/remove/keep), Merge, Output |
| **Flow** | Variable, Loop, Delay, Error Handler |
| **AI** | Gemini, OpenAI |
| **Network** | HTTP Request (GET/POST/PUT/DELETE), Webhook |
| **Integration** | Telegram Bot (18 actions), Telegram Trigger |

---

## 🤖 Telegram Bot Integration

N8N-style Telegram Bot node with 18 API actions:

```dart
final telegram = TelegramNodeDef();

// Send a message
final ctx = ExecutionContext(
  nodeId: 'telegram_1',
  params: {
    'botToken': 'YOUR_BOT_TOKEN',
    'action': 'sendMessage',
    'chatId': '123456789',
    'text': 'Hello from FlowCraft! 🚀',
  },
);
final result = await telegram.execute(ctx);
```

**Supported actions:** `sendMessage`, `sendPhoto`, `sendDocument`, `sendVideo`, `sendSticker`, `sendLocation`, `sendChatAction`, `editMessageText`, `deleteMessage`, `forwardMessage`, `copyMessage`, `pinChatMessage`, `unpinChatMessage`, `answerCallbackQuery`, `getMe`, `getChat`, `getChatMember`, `getUpdates`

**Trigger node:** Use `TelegramTriggerNodeDef` to start workflows from incoming messages via long polling.

---

## 🔧 Controller API Highlights

```dart
final controller = FlowController();

// Nodes
controller.addNode(label: 'Step 1', position: Offset(100, 200));
controller.removeNode(nodeId);
controller.renameNode(nodeId, 'New Name');
controller.moveNode(nodeId, Offset(300, 400));

// Edges
controller.addEdge(
  sourceNodeId: sourceId,
  targetNodeId: targetId,
  sourceHandleId: srcHandle,
  targetHandleId: tgtHandle,
);
controller.removeEdge(edgeId);

// Viewport
controller.zoomIn();
controller.zoomOut();
controller.fitView(canvasSize);

// History
controller.undo();
controller.redo();
```

---

## 📦 Package Details

| Property       | Value                                                     |
|----------------|-----------------------------------------------------------|
| **Name**       | `flowcraft`                                               |
| **Version**    | `0.1.0`                                                   |
| **SDK**        | Dart ≥ 3.10.0, Flutter ≥ 1.17.0                          |
| **Dependencies** | Flutter SDK only (zero external dependencies)           |
| **License**    | MIT                                                       |
| **Repository** | [github.com/alisheraxmedov/flowcraft](https://github.com/alisheraxmedov/flowcraft) |
| **Issues**     | [github.com/alisheraxmedov/flowcraft/issues](https://github.com/alisheraxmedov/flowcraft/issues) |

---

## 🤝 Contributing

Contributions are welcome! Please see the [repository](https://github.com/alisheraxmedov/flowcraft) for guidelines.

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.
