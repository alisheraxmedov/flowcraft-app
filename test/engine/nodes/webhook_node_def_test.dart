import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/engine/execution_context.dart';
import 'package:flowcraft/engine/nodes/webhook_node_def.dart';

void main() {
  group('WebhookNodeDef', () {
    late WebhookNodeDef node;
    setUp(() => node = WebhookNodeDef());

    test('metadata', () {
      expect(node.typeId, 'webhook');
      expect(node.category, 'Triggers');
      expect(node.isTrigger, isTrue);
      expect(node.inputs, isEmpty);
      expect(node.outputs, hasLength(1));
    });

    test('required params are marked', () {
      final methodParam = node.params.firstWhere((p) => p.name == 'method');
      final pathParam = node.params.firstWhere((p) => p.name == 'path');
      final payloadParam =
          node.params.firstWhere((p) => p.name == 'testPayload');

      expect(methodParam.isRequired, isTrue);
      expect(pathParam.isRequired, isTrue);
      expect(payloadParam.isRequired, isFalse);
    });

    test('spreads body payload fields at the top level of output', () async {
      final ctx = ExecutionContext(
        nodeId: 'wh1',
        params: const {
          'method': 'POST',
          'path': '/api/incoming',
          'testPayload': {
            'event': 'Hello Gemini',
            'user': 'test_user',
          },
          'headers': <String, dynamic>{},
        },
      );

      final result = await node.execute(ctx);
      expect(result.isSuccess, isTrue);

      // Body fields must be spreaded at top level
      expect(result.outputData['event'], 'Hello Gemini');
      expect(result.outputData['user'], 'test_user');

      // Original nested body is also preserved
      expect(result.outputData['body'], isA<Map>());
      expect(result.outputData['body']['event'], 'Hello Gemini');

      // Webhook metadata is present
      expect(result.outputData['method'], 'POST');
      expect(result.outputData['path'], '/api/incoming');
      expect(result.outputData['_webhook'], isTrue);
    });

    test('handles empty payload gracefully', () async {
      final ctx = ExecutionContext(
        nodeId: 'wh2',
        params: const {
          'method': 'GET',
          'path': '/webhook',
          'testPayload': <String, dynamic>{},
          'headers': <String, dynamic>{},
        },
      );

      final result = await node.execute(ctx);
      expect(result.isSuccess, isTrue);
      expect(result.outputData['body'], isEmpty);
      expect(result.outputData['method'], 'GET');
    });

    test('handles non-map testPayload as empty', () async {
      final ctx = ExecutionContext(
        nodeId: 'wh3',
        params: const {
          'method': 'POST',
          'path': '/webhook',
          'testPayload': 'not_a_map',
          'headers': <String, dynamic>{},
        },
      );

      final result = await node.execute(ctx);
      expect(result.isSuccess, isTrue);
      expect(result.outputData['body'], isEmpty);
    });

    test('default values are applied when params missing', () async {
      final ctx = ExecutionContext(
        nodeId: 'wh4',
        params: const <String, dynamic>{},
      );

      final result = await node.execute(ctx);
      expect(result.isSuccess, isTrue);
      expect(result.outputData['method'], 'POST');
      expect(result.outputData['path'], '/webhook');
    });
  });
}
