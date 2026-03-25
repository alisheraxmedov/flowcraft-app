# 15 — Telegram Bot Integration

FlowCraft provides N8N-style Telegram Bot integration through two node definitions:

- **TelegramNodeDef** — executes 18 Telegram Bot API actions
- **TelegramTriggerNodeDef** — starts workflows from incoming Telegram events

## Requirements

| Item | Description |
|------|-------------|
| **Bot Token** | Obtain from [@BotFather](https://t.me/BotFather) on Telegram |
| **Chat ID** | Target chat/group/channel ID (required for most actions) |

## TelegramNodeDef

**TypeId:** `telegram` · **Category:** Integration

### Supported Actions (18)

#### Messaging

| Action | Parameters | Description |
|--------|-----------|-------------|
| `sendMessage` | `chatId`, `text`, `parseMode?`, `replyMarkup?` | Send text message |
| `sendPhoto` | `chatId`, `photoUrl`, `caption?` | Send photo by URL/file_id |
| `sendDocument` | `chatId`, `documentUrl`, `caption?` | Send document |
| `sendVideo` | `chatId`, `videoUrl`, `caption?` | Send video |
| `sendSticker` | `chatId`, `stickerFileId` | Send sticker |
| `sendLocation` | `chatId`, `latitude`, `longitude` | Send GPS location |
| `sendChatAction` | `chatId`, `chatAction` | Typing indicator (9 types) |

#### Edit & Moderate

| Action | Parameters | Description |
|--------|-----------|-------------|
| `editMessageText` | `chatId`, `messageId`, `text` | Edit existing message |
| `deleteMessage` | `chatId`, `messageId` | Delete a message |
| `forwardMessage` | `chatId`, `fromChatId`, `messageId` | Forward message |
| `copyMessage` | `chatId`, `fromChatId`, `messageId` | Copy message |
| `pinChatMessage` | `chatId`, `messageId` | Pin message |
| `unpinChatMessage` | `chatId`, `messageId?` | Unpin message |

#### Callback & Info

| Action | Parameters | Description |
|--------|-----------|-------------|
| `answerCallbackQuery` | `callbackQueryId`, `text?` | Respond to inline button |
| `getMe` | _(none)_ | Get bot info |
| `getChat` | `chatId` | Get chat details |
| `getChatMember` | `chatId`, `userId` | Get member info |
| `getUpdates` | `offset?`, `limit?` | Fetch updates (polling) |

### Inline Keyboard Support

Pass a JSON `replyMarkup` parameter to add inline buttons:

```json
{
  "inline_keyboard": [
    [
      {"text": "✅ Approve", "callback_data": "approve"},
      {"text": "❌ Reject", "callback_data": "reject"}
    ]
  ]
}
```

### Template Interpolation

Use `{{fieldName}}` in text strings to insert values from input data:

```
Hello {{firstName}}! Your order #{{orderId}} is ready.
```

### Additional Options

| Parameter | Type | Description |
|-----------|------|-------------|
| `parseMode` | select | `None`, `Markdown`, `MarkdownV2`, `HTML` |
| `protectContent` | boolean | Prevent forwarding/saving |
| `disableWebPagePreview` | boolean | No link previews |

## TelegramTriggerNodeDef

**TypeId:** `telegram_trigger` · **Category:** Trigger · **isTrigger:** `true`

Starts workflows from incoming Telegram events using long polling (`getUpdates`).

### Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `botToken` | credential | — | Bot token from @BotFather |
| `updateType` | select | `message` | Filter: `all`, `message`, `callback_query`, `edited_message`, `channel_post` |
| `pollingTimeout` | number | `10` | Long polling timeout (0–60 seconds) |
| `limit` | number | `10` | Max updates per poll (1–100) |
| `offset` | number | `0` | Update offset for deduplication |

### Output Data

When updates are received, the trigger outputs structured data:

| Field | Description |
|-------|-------------|
| `hasUpdates` | Boolean flag |
| `updateCount` | Number of updates |
| `updates` | Raw update array |
| `latestUpdateId` | ID of the most recent update |
| `nextOffset` | Use as `offset` in next poll |
| `messageText` | Text content of the latest message |
| `chatId` | Chat/group ID |
| `fromUserId` | Sender user ID |
| `fromUsername` | Sender username |
| `callbackData` | Inline button callback data |
| `photoFileId` | Photo file_id (if photo) |
| `documentFileId` | Document file_id (if document) |

## Usage Examples

### Send a message with inline keyboard

```dart
final ctx = ExecutionContext(
  nodeId: 'tg1',
  params: {
    'botToken': 'YOUR_TOKEN',
    'action': 'sendMessage',
    'chatId': '123456789',
    'text': 'Choose an option:',
    'replyMarkup': '{"inline_keyboard":[[{"text":"Option A","callback_data":"a"}]]}',
  },
);
final result = await TelegramNodeDef().execute(ctx);
```

### Poll for incoming messages

```dart
final ctx = ExecutionContext(
  nodeId: 'trigger1',
  params: {
    'botToken': 'YOUR_TOKEN',
    'updateType': 'message',
    'pollingTimeout': 10,
  },
);
final result = await TelegramTriggerNodeDef().execute(ctx);
if (result.outputData['hasUpdates'] == true) {
  print('New message: ${result.outputData['messageText']}');
}
```

## Security Notes

- **Never hard-code bot tokens.** Use `credentials` map in `ExecutionContext`.
- Bot tokens should be stored in secure credential management.
- All API calls use HTTPS (`api.telegram.org/bot{token}/...`).
- `dart:io HttpClient` is used — not available on Flutter Web.
