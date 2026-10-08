import 'package:flowcraft/services/mcp_guide.dart';
import 'package:flowcraft/services/mcp_tools.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('guide mentions every name in flowcraftMcpTools', () {
    for (final tool in flowcraftMcpTools) {
      expect(mcpGuideText, contains(tool.name), reason: tool.name);
    }
  });

  test('guide covers the vocabulary the tools accept', () {
    for (final word in [
      'fromId',
      'toId',
      'flowcraft_diagram',
      'sticky',
      'frame',
      'entity',
      'dataUrl',
      'elbow',
      'fontFamily',
      'erDiagram',
      'Table users',
    ]) {
      expect(mcpGuideText, contains(word), reason: word);
    }
  });
}
