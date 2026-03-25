## 0.1.0

### 🎉 Initial Release

#### Visual Flow Canvas
* Interactive infinite 2D canvas with pan, zoom, and configurable grid (dots/lines)
* 4 built-in node types: `default`, `input`, `output`, `custom`
* Edge routing: bezier curves, smooth step (right-angle), and straight lines
* Animated edges with flowing dashed PathMetrics animations
* Undo/Redo via Command Pattern history with configurable depth
* Full JSON serialization — save/load entire graph state
* Multi-select with lasso selection and group drag
* Overlays: minimap, zoom controls, floating node toolbar
* Complete light/dark theming system via `FlowTheme`
* Zero external dependencies — only Flutter SDK

#### Execution Engine
* `ExecutionEngine` — topological-sort-based sequential workflow execution
* `FlowController` — central state manager for nodes, edges, and viewport
* `NodeDefinitionRegistry` — register and look up node definitions by type ID
* `ExecutionContext` — typed input/param/credential access during node execution
* `ExecutionResult` / `WorkflowResult` — structured success/error/skipped results

#### Built-in Node Definitions
* **Core:** `TriggerNodeDef`, `ConditionNodeDef` (6 operators), `TransformNodeDef` (set/rename/remove/keep), `MergeNodeDef`, `OutputNodeDef`
* **Flow:** `VariableNodeDef` (set/get/setAndGet), `LoopNodeDef` (list iteration + maxIterations), `DelayNodeDef`, `ErrorHandlerNodeDef` (fallback + continueOnError)
* **AI:** `GeminiNodeDef`, `OpenAINodeDef` — LLM integration via API
* **Network:** `HttpRequestNodeDef` (GET/POST/PUT/DELETE), `WebhookNodeDef`
* **Integration:** `TelegramNodeDef` (18 API actions), `TelegramTriggerNodeDef` (polling trigger)

#### Telegram Bot Integration (N8N-style)
* **TelegramNodeDef** — 18 Telegram Bot API actions:
  * Messaging: `sendMessage`, `sendPhoto`, `sendDocument`, `sendVideo`, `sendSticker`, `sendLocation`, `sendChatAction` (9 typing indicators)
  * Edit/Moderate: `editMessageText`, `deleteMessage`, `forwardMessage`, `copyMessage`, `pinChatMessage`, `unpinChatMessage`
  * Callback: `answerCallbackQuery`
  * Info: `getMe`, `getChat`, `getChatMember`, `getUpdates`
  * Features: inline keyboard support (`replyMarkup` JSON), `protectContent`, `disableWebPagePreview`, template interpolation (`{{fieldName}}`)
* **TelegramTriggerNodeDef** — polling-based trigger for incoming events:
  * Filters: `message`, `callback_query`, `edited_message`, `channel_post`, `all`
  * Structured data extraction: chat info, user info, photos, documents, callback data
  * Offset tracking for avoiding duplicate updates

#### Testing
* 329 unit tests across 29 test files
* Coverage: engine core, core models, all pure-logic node definitions, and Telegram integration
