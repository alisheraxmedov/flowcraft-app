import 'package:flowcraft/services/text_import/detect.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('detectTextFormat', () {
    expect(
      detectTextFormat('{"type":"excalidraw","version":2,"elements":[]}'),
      TextFormat.excalidraw,
    );
    expect(detectTextFormat('{"version":1,"elements":[]}'), TextFormat.json);
    expect(detectTextFormat('{"foo":1}'), TextFormat.unknown);
    expect(detectTextFormat('{broken'), TextFormat.unknown);
    expect(detectTextFormat('graph TD\na-->b'), TextFormat.mermaid);
    expect(detectTextFormat('%% c\n\nflowchart LR\na-->b'), TextFormat.mermaid);
    expect(detectTextFormat('erDiagram\nA ||--o{ B'), TextFormat.mermaid);
    expect(detectTextFormat('Table a {\n id int\n}'), TextFormat.dbml);
    expect(detectTextFormat('// hi\nRef: a.b > c.d'), TextFormat.dbml);
    expect(detectTextFormat('hello world'), TextFormat.unknown);
    expect(detectTextFormat(''), TextFormat.unknown);
  });

  test('parseMermaid dispatches on header', () {
    expect(parseMermaid('erDiagram\nA ||--o{ B')['direction'], 'LR');
    expect(parseMermaid('graph TB\na-->b')['direction'], 'TB');
  });
}
