import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/engine/execution_context.dart';
import 'package:flowcraft/engine/nodes/telegram_trigger_node_def.dart';
import 'package:flowcraft/engine/param_definition.dart';
import 'package:flowcraft/engine/port_definition.dart';

void main() {
  late TelegramTriggerNodeDef node;

  setUp(() {
    node = TelegramTriggerNodeDef();
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Metadata
  // ─────────────────────────────────────────────────────────────────────────

  group('Metadata', () {
    test('typeId is "telegram_trigger"', () {
      expect(node.typeId, 'telegram_trigger');
    });

    test('displayName is "Telegram Trigger"', () {
      expect(node.displayName, 'Telegram Trigger');
    });

    test('category is "Trigger"', () {
      expect(node.category, 'Trigger');
    });

    test('description is non-empty', () {
      expect(node.description, isNotEmpty);
    });

    test('isTrigger is TRUE', () {
      expect(node.isTrigger, isTrue);
    });
  });

  // ─────────────────────────────────────────────────────────────────────────
  // Ports
  // ─────────────────────────────────────────────────────────────────────────

  group('Ports', () {
    test('has NO input ports (trigger starts workflow)', () {
      expect(node.inputs, isEmpty);
    });

    test('has one output port "update"', () {
      expect(node.outputs.length, 1);
      expect(node.outputs.first.name, 'update');
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

    test('updateType param has 5 options', () {
      final param = node.params.firstWhere((p) => p.name == 'updateType');
      expect(param.type, ParamType.select);
      expect(param.options!.length, 5);
      expect(param.options, contains('all'));
      expect(param.options, contains('message'));
      expect(param.options, contains('callback_query'));
      expect(param.options, contains('edited_message'));
      expect(param.options, contains('channel_post'));
    });

    test('updateType default is "message"', () {
      final param = node.params.firstWhere((p) => p.name == 'updateType');
      expect(param.defaultValue, 'message');
    });

    test('pollingTimeout param exists as number type', () {
      final param =
          node.params.firstWhere((p) => p.name == 'pollingTimeout');
      expect(param.type, ParamType.number);
      expect(param.defaultValue, 10);
    });

    test('limit param exists as number type', () {
      final param = node.params.firstWhere((p) => p.name == 'limit');
      expect(param.type, ParamType.number);
      expect(param.defaultValue, 10);
    });

    test('offset param exists as number type', () {
      final param = node.params.firstWhere((p) => p.name == 'offset');
      expect(param.type, ParamType.number);
      expect(param.defaultValue, 0);
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
        nodeId: 'trigger_test',
        params: const {
          'botToken': '',
          'updateType': 'message',
        },
      );

      final result = await node.execute(context);
      expect(result.isError, isTrue);
      expect(result.errorMessage, contains('Bot token'));
    });

    test('returns error when no token in params or credentials', () async {
      final context = ExecutionContext(
        nodeId: 'trigger_test',
        params: const {},
        credentials: const {},
      );

      final result = await node.execute(context);
      expect(result.isError, isTrue);
      expect(result.errorMessage, contains('Bot token'));
    });
  });
}
