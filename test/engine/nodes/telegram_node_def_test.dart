import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/engine/execution_context.dart';
import 'package:flowcraft/engine/nodes/telegram_node_def.dart';
import 'package:flowcraft/engine/param_definition.dart';
import 'package:flowcraft/engine/port_definition.dart';

void main() {
  late TelegramNodeDef node;

  setUp(() {
    node = TelegramNodeDef();
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Metadata
  // ─────────────────────────────────────────────────────────────────────────

  group('Metadata', () {
    test('typeId is "telegram"', () {
      expect(node.typeId, 'telegram');
    });

    test('displayName is "Telegram Bot"', () {
      expect(node.displayName, 'Telegram Bot');
    });

    test('category is "Integration"', () {
      expect(node.category, 'Integration');
    });

    test('description is non-empty', () {
      expect(node.description, isNotEmpty);
    });

    test('is NOT a trigger', () {
      expect(node.isTrigger, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Ports
  // ─────────────────────────────────────────────────────────────────────────

  group('Ports', () {
    test('has one optional input port "data"', () {
      expect(node.inputs.length, 1);
      expect(node.inputs.first.name, 'data');
      expect(node.inputs.first.dataType, PortDataType.json);
      expect(node.inputs.first.required, isFalse);
    });

    test('has one output port "response"', () {
      expect(node.outputs.length, 1);
      expect(node.outputs.first.name, 'response');
      expect(node.outputs.first.dataType, PortDataType.json);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Params
  // ─────────────────────────────────────────────────────────────────────────

  group('Params', () {
    test('botToken param exists as credential type', () {
      final param = node.params.firstWhere((p) => p.name == 'botToken');
      expect(param.type, ParamType.credential);
    });

    test('chatId param exists as string type', () {
      final param = node.params.firstWhere((p) => p.name == 'chatId');
      expect(param.type, ParamType.string);
    });

    test('action param has 18 options', () {
      final param = node.params.firstWhere((p) => p.name == 'action');
      expect(param.type, ParamType.select);
      expect(param.options, isNotNull);
      expect(param.options!.length, 18);
    });

    test('action options include all expected actions', () {
      final param = node.params.firstWhere((p) => p.name == 'action');
      final options = param.options!;

      // Messaging
      expect(options, contains('sendMessage'));
      expect(options, contains('sendPhoto'));
      expect(options, contains('sendDocument'));
      expect(options, contains('sendVideo'));
      expect(options, contains('sendLocation'));
      expect(options, contains('sendSticker'));
      expect(options, contains('sendChatAction'));

      // Edit/Delete
      expect(options, contains('editMessageText'));
      expect(options, contains('deleteMessage'));

      // Forward/Copy
      expect(options, contains('forwardMessage'));
      expect(options, contains('copyMessage'));

      // Pin
      expect(options, contains('pinChatMessage'));
      expect(options, contains('unpinChatMessage'));

      // Callback
      expect(options, contains('answerCallbackQuery'));

      // Info
      expect(options, contains('getMe'));
      expect(options, contains('getChat'));
      expect(options, contains('getChatMember'));
      expect(options, contains('getUpdates'));
    });

    test('replyMarkup param exists as JSON type', () {
      final param = node.params.firstWhere((p) => p.name == 'replyMarkup');
      expect(param.type, ParamType.json);
    });

    test('chatAction param has 9 options', () {
      final param = node.params.firstWhere((p) => p.name == 'chatAction');
      expect(param.type, ParamType.select);
      expect(param.options!.length, 9);
      expect(param.options, contains('typing'));
      expect(param.options, contains('upload_photo'));
      expect(param.options, contains('upload_document'));
    });

    test('all params have unique names', () {
      final names = node.params.map((p) => p.name).toList();
      expect(names.toSet().length, names.length);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Validation — token required
  // ─────────────────────────────────────────────────────────────────────────

  group('Token validation', () {
    test('returns error when botToken is empty', () async {
      final context = ExecutionContext(
        nodeId: 'test_node',
        params: const {'action': 'sendMessage'},
      );

      final result = await node.execute(context);
      expect(result.isError, isTrue);
      expect(result.errorMessage, contains('Bot token'));
    });

    test('resolves token from credentials if param is empty', () async {
      final context = ExecutionContext(
        nodeId: 'test_node',
        params: const {
          'action': 'sendMessage',
          'botToken': '',
          'chatId': '123',
          'text': 'Hello',
        },
        credentials: const {'telegram_bot_token': ''},
      );

      final result = await node.execute(context);
      expect(result.isError, isTrue);
      expect(result.errorMessage, contains('Bot token'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Validation — chatId required for most actions
  // ─────────────────────────────────────────────────────────────────────────

  group('ChatId validation', () {
    test('returns error when chatId is empty for sendMessage', () async {
      final context = ExecutionContext(
        nodeId: 'test_node',
        params: const {
          'botToken': 'some_fake_token',
          'action': 'sendMessage',
          'chatId': '',
          'text': 'Hello',
        },
      );

      final result = await node.execute(context);
      expect(result.isError, isTrue);
      expect(result.errorMessage, contains('Chat ID'));
    });

    test('does NOT require chatId for getMe', () async {
      // This will fail on the API call (timeout/dns), but should NOT fail
      // on chatId validation
      final context = ExecutionContext(
        nodeId: 'test_node',
        params: const {
          'botToken': 'some_fake_token',
          'action': 'getMe',
          'chatId': '',
        },
      );

      final result = await node.execute(context);
      // Should fail on network, NOT on chatId validation
      if (result.isError) {
        expect(result.errorMessage, isNot(contains('Chat ID')));
      }
    });

    test('does NOT require chatId for getUpdates', () async {
      final context = ExecutionContext(
        nodeId: 'test_node',
        params: const {
          'botToken': 'some_fake_token',
          'action': 'getUpdates',
          'chatId': '',
        },
      );

      final result = await node.execute(context);
      if (result.isError) {
        expect(result.errorMessage, isNot(contains('Chat ID')));
      }
    });

    test('does NOT require chatId for answerCallbackQuery', () async {
      final context = ExecutionContext(
        nodeId: 'test_node',
        params: const {
          'botToken': 'some_fake_token',
          'action': 'answerCallbackQuery',
          'chatId': '',
          'callbackQueryId': 'query_123',
        },
      );

      final result = await node.execute(context);
      if (result.isError) {
        expect(result.errorMessage, isNot(contains('Chat ID')));
      }
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Validation — action-specific required fields
  // ─────────────────────────────────────────────────────────────────────────

  group('Action-specific validation', () {
    test('sendMessage requires text', () async {
      final context = ExecutionContext(
        nodeId: 'test_node',
        params: const {
          'botToken': 'some_fake_token',
          'action': 'sendMessage',
          'chatId': '123',
          'text': '',
        },
      );

      final result = await node.execute(context);
      expect(result.isError, isTrue);
      expect(result.errorMessage, contains('text'));
    });

    test('sendPhoto requires photoUrl', () async {
      final context = ExecutionContext(
        nodeId: 'test_node',
        params: const {
          'botToken': 'some_fake_token',
          'action': 'sendPhoto',
          'chatId': '123',
          'photoUrl': '',
        },
      );

      final result = await node.execute(context);
      expect(result.isError, isTrue);
      expect(result.errorMessage, contains('Photo URL'));
    });

    test('sendDocument requires documentUrl', () async {
      final context = ExecutionContext(
        nodeId: 'test_node',
        params: const {
          'botToken': 'some_fake_token',
          'action': 'sendDocument',
          'chatId': '123',
          'documentUrl': '',
        },
      );

      final result = await node.execute(context);
      expect(result.isError, isTrue);
      expect(result.errorMessage, contains('Document URL'));
    });

    test('sendVideo requires videoUrl', () async {
      final context = ExecutionContext(
        nodeId: 'test_node',
        params: const {
          'botToken': 'some_fake_token',
          'action': 'sendVideo',
          'chatId': '123',
          'videoUrl': '',
        },
      );

      final result = await node.execute(context);
      expect(result.isError, isTrue);
      expect(result.errorMessage, contains('Video URL'));
    });

    test('sendSticker requires stickerFileId', () async {
      final context = ExecutionContext(
        nodeId: 'test_node',
        params: const {
          'botToken': 'some_fake_token',
          'action': 'sendSticker',
          'chatId': '123',
          'stickerFileId': '',
        },
      );

      final result = await node.execute(context);
      expect(result.isError, isTrue);
      expect(result.errorMessage, contains('Sticker file ID'));
    });

    test('sendLocation requires latitude and longitude', () async {
      final context = ExecutionContext(
        nodeId: 'test_node',
        params: const {
          'botToken': 'some_fake_token',
          'action': 'sendLocation',
          'chatId': '123',
          'latitude': 0,
          'longitude': 0,
        },
      );

      final result = await node.execute(context);
      expect(result.isError, isTrue);
      expect(result.errorMessage, contains('Latitude'));
    });

    test('editMessageText requires text and messageId', () async {
      final context = ExecutionContext(
        nodeId: 'test_node',
        params: const {
          'botToken': 'some_fake_token',
          'action': 'editMessageText',
          'chatId': '123',
          'text': '',
          'messageId': 0,
        },
      );

      final result = await node.execute(context);
      expect(result.isError, isTrue);
      expect(result.errorMessage, contains('text'));
    });

    test('editMessageText requires messageId', () async {
      final context = ExecutionContext(
        nodeId: 'test_node',
        params: const {
          'botToken': 'some_fake_token',
          'action': 'editMessageText',
          'chatId': '123',
          'text': 'Updated text',
          'messageId': 0,
        },
      );

      final result = await node.execute(context);
      expect(result.isError, isTrue);
      expect(result.errorMessage, contains('Message ID'));
    });

    test('deleteMessage requires messageId', () async {
      final context = ExecutionContext(
        nodeId: 'test_node',
        params: const {
          'botToken': 'some_fake_token',
          'action': 'deleteMessage',
          'chatId': '123',
          'messageId': 0,
        },
      );

      final result = await node.execute(context);
      expect(result.isError, isTrue);
      expect(result.errorMessage, contains('Message ID'));
    });

    test('forwardMessage requires fromChatId and messageId', () async {
      final context = ExecutionContext(
        nodeId: 'test_node',
        params: const {
          'botToken': 'some_fake_token',
          'action': 'forwardMessage',
          'chatId': '123',
          'fromChatId': '',
          'messageId': 0,
        },
      );

      final result = await node.execute(context);
      expect(result.isError, isTrue);
      expect(result.errorMessage, contains('From Chat ID'));
    });

    test('copyMessage requires fromChatId and messageId', () async {
      final context = ExecutionContext(
        nodeId: 'test_node',
        params: const {
          'botToken': 'some_fake_token',
          'action': 'copyMessage',
          'chatId': '123',
          'fromChatId': '',
          'messageId': 0,
        },
      );

      final result = await node.execute(context);
      expect(result.isError, isTrue);
      expect(result.errorMessage, contains('From Chat ID'));
    });

    test('pinChatMessage requires messageId', () async {
      final context = ExecutionContext(
        nodeId: 'test_node',
        params: const {
          'botToken': 'some_fake_token',
          'action': 'pinChatMessage',
          'chatId': '123',
          'messageId': 0,
        },
      );

      final result = await node.execute(context);
      expect(result.isError, isTrue);
      expect(result.errorMessage, contains('Message ID'));
    });

    test('answerCallbackQuery requires callbackQueryId', () async {
      final context = ExecutionContext(
        nodeId: 'test_node',
        params: const {
          'botToken': 'some_fake_token',
          'action': 'answerCallbackQuery',
          'callbackQueryId': '',
        },
      );

      final result = await node.execute(context);
      expect(result.isError, isTrue);
      expect(result.errorMessage, contains('Callback query ID'));
    });

    test('getChatMember requires userId', () async {
      final context = ExecutionContext(
        nodeId: 'test_node',
        params: const {
          'botToken': 'some_fake_token',
          'action': 'getChatMember',
          'chatId': '123',
          'userId': 0,
        },
      );

      final result = await node.execute(context);
      expect(result.isError, isTrue);
      expect(result.errorMessage, contains('User ID'));
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Action options constant
  // ─────────────────────────────────────────────────────────────────────────

  group('Static members', () {
    test('actionOptions has 18 entries', () {
      expect(TelegramNodeDef.actionOptions.length, 18);
    });

    test('all enum values represented', () {
      expect(TelegramNodeDef.actionOptions.length, TelegramAction.values.length);
    });
  });
}
