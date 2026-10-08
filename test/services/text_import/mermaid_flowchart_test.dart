import 'package:flowcraft/services/diagram_spec.dart';
import 'package:flowcraft/services/text_import/mermaid_flowchart.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> node(Map<String, dynamic> d, String id) =>
    (d['nodes'] as List).cast<Map<String, dynamic>>().firstWhere(
      (n) => n['id'] == id,
    );

List<List<String>> pairs(Map<String, dynamic> d) => [
  for (final e in d['edges'] as List) [e['from'] as String, e['to'] as String],
];

void main() {
  test('happy path: direction, nodes, edge; TD means TB', () {
    final d = parseMermaidFlowchart('graph TD\n  A[Start] --> B(End)\n');
    expect(d['direction'], 'TB');
    expect(node(d, 'A')['label'], 'Start');
    expect(pairs(d), [
      ['A', 'B'],
    ]);
    expect(parseMermaidFlowchart('flowchart LR\na-->b')['direction'], 'LR');
    expect(parseMermaidFlowchart('graph\na-->b')['direction'], 'TB');
  });

  test('every bracket shape maps to a layout shape', () {
    final d = parseMermaidFlowchart('''
flowchart TB
a[r]
b(e1)
c([e2])
d((e3))
f{dia}
g>flag]
h["quoted label"]
bare
''');
    String shape(String id) => node(d, id)['shape'] as String;
    expect(['a', 'b', 'c', 'd', 'f', 'g', 'h', 'bare'].map(shape), [
      'rectangle',
      'ellipse',
      'ellipse',
      'ellipse',
      'diamond',
      'rectangle',
      'rectangle',
      'rectangle',
    ]);
    expect(node(d, 'c')['label'], 'e2');
    expect(node(d, 'd')['label'], 'e3');
    expect(node(d, 'g')['label'], 'flag');
    expect(node(d, 'h')['label'], 'quoted label');
    expect(node(d, 'bare')['label'], 'bare');
  });

  test('bare node later given a shape takes shape and label', () {
    final d = parseMermaidFlowchart('graph TB\na --> b\nb{Decide}');
    expect(node(d, 'b')['shape'], 'diamond');
    expect(node(d, 'b')['label'], 'Decide');
  });

  test('link operators, labels dropped', () {
    final d = parseMermaidFlowchart('''
graph LR
a --> b
b --- c
c -.-> d
d ==> e
e --x f
f -->|yes| g
g -- some text --> h
h == bold ==> i
''');
    expect(pairs(d).length, 8);
    expect(pairs(d).last, ['h', 'i']);
    expect(pairs(d)[5], ['f', 'g']);
    expect(pairs(d)[6], ['g', 'h']);
  });

  test('chains and & fan-out', () {
    final chain = parseMermaidFlowchart('graph TB\na --> b --> c');
    expect(pairs(chain), [
      ['a', 'b'],
      ['b', 'c'],
    ]);
    final fan = parseMermaidFlowchart('graph TB\na & b --> c & d');
    expect(pairs(fan), [
      ['a', 'c'],
      ['a', 'd'],
      ['b', 'c'],
      ['b', 'd'],
    ]);
  });

  test('subgraph becomes a frame, members flattened to the innermost', () {
    final d = parseMermaidFlowchart('''
graph TB
subgraph outer[Outer Box]
  a --> b
  subgraph inner
    c
  end
  d
end
e
''');
    final frames = (d['frames'] as List).cast<Map<String, dynamic>>();
    expect(frames.map((f) => f['name']), ['Outer Box', 'inner']);
    expect(frames[0]['members'], ['a', 'b', 'd']);
    expect(frames[1]['members'], ['c']);
  });

  test('comments, blank lines and styling statements are skipped', () {
    final d = parseMermaidFlowchart('''
%% a comment
graph TB

classDef red fill:#f00
a:::red --> b
class a,b red
style a fill:#fff
click a href "http://x"
linkStyle 0 stroke:#f00
%% trailing
''');
    expect(pairs(d), [
      ['a', 'b'],
    ]);
    expect((d['nodes'] as List).length, 2);
  });

  test('bad line reports its 1-based number', () {
    expect(
      () => parseMermaidFlowchart('graph TB\na --> b\n\nfoo bar baz'),
      throwsA(
        isA<DiagramSpecException>().having(
          (e) => e.message,
          'message',
          startsWith('line 4: unrecognised statement "foo bar baz"'),
        ),
      ),
    );
    expect(
      () => parseMermaidFlowchart('sequenceDiagram\na->>b: hi'),
      throwsA(isA<DiagramSpecException>()),
    );
  });

  test('element cap enforced', () {
    final sb = StringBuffer('graph LR\n');
    for (var i = 0; i < 5001; i++) {
      sb.writeln('n$i --> n${i + 1}');
    }
    expect(
      () => parseMermaidFlowchart(sb.toString()),
      throwsA(isA<DiagramSpecException>()),
    );
  });

  test('label cap enforced', () {
    expect(
      () => parseMermaidFlowchart(
        'graph TB\na[${'x' * (maxDiagramTextLength + 1)}]',
      ),
      throwsA(isA<DiagramSpecException>()),
    );
  });
}
