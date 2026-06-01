import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/engine/nodes/gemini_node_def.dart';
import 'package:flowcraft/engine/nodes/openai_node_def.dart';

void main() {
  // ─────────────────────────────────────────────────────────────────────
  // GeminiNodeDef
  // ─────────────────────────────────────────────────────────────────────

  group('GeminiNodeDef', () {
    late GeminiNodeDef node;
    setUp(() => node = GeminiNodeDef());

    test('metadata', () {
      expect(node.typeId, 'gemini');
      expect(node.displayName, 'Gemini');
      expect(node.category, 'AI');
      expect(node.inputs, hasLength(1));
      expect(node.outputs, hasLength(1));
    });

    test('required params are correctly marked', () {
      final apiKey = node.params.firstWhere((p) => p.name == 'apiKey');
      final model = node.params.firstWhere((p) => p.name == 'model');
      final userMsg = node.params.firstWhere((p) => p.name == 'userMessage');
      final temp = node.params.firstWhere((p) => p.name == 'temperature');
      final safety = node.params.firstWhere((p) => p.name == 'safetyLevel');

      expect(apiKey.isRequired, isTrue);
      expect(model.isRequired, isTrue);
      expect(userMsg.isRequired, isTrue);
      expect(temp.isRequired, isFalse);
      expect(safety.isRequired, isFalse);
    });

    test('has system instruction param', () {
      final sysParam =
          node.params.firstWhere((p) => p.name == 'systemInstruction');
      expect(sysParam.defaultValue, '');
      expect(sysParam.isRequired, isFalse);
    });
  });

  // ─────────────────────────────────────────────────────────────────────
  // OpenAiNodeDef
  // ─────────────────────────────────────────────────────────────────────

  group('OpenAiNodeDef', () {
    late OpenAiNodeDef node;
    setUp(() => node = OpenAiNodeDef());

    test('metadata', () {
      expect(node.typeId, 'openai');
      expect(node.displayName, 'OpenAI');
      expect(node.category, 'AI');
      expect(node.inputs, hasLength(1));
      expect(node.outputs, hasLength(1));
    });

    test('required params are correctly marked', () {
      final apiKey = node.params.firstWhere((p) => p.name == 'apiKey');
      final model = node.params.firstWhere((p) => p.name == 'model');
      final userMsg = node.params.firstWhere((p) => p.name == 'userMessage');
      final temp = node.params.firstWhere((p) => p.name == 'temperature');
      final baseUrl = node.params.firstWhere((p) => p.name == 'baseUrl');

      expect(apiKey.isRequired, isTrue);
      expect(model.isRequired, isTrue);
      expect(userMsg.isRequired, isTrue);
      expect(temp.isRequired, isFalse);
      expect(baseUrl.isRequired, isFalse);
    });

    test('default base URL is OpenAI', () {
      final baseUrl = node.params.firstWhere((p) => p.name == 'baseUrl');
      expect(baseUrl.defaultValue, 'https://api.openai.com/v1');
    });
  });
}
