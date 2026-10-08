import 'package:flowcraft/services/diagram_spec.dart';
import 'package:flowcraft/services/text_import/mermaid_er.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('happy path: entities with attributes and a relationship', () {
    final d = parseMermaidEr('''
erDiagram
  CUSTOMER ||--o{ ORDER : places
  CUSTOMER {
    string id PK
    string name "full name"
    int org_id FK
    string code PK, FK
  }
''');
    final nodes = (d['nodes'] as List).cast<Map<String, dynamic>>();
    final c = nodes.firstWhere((n) => n['id'] == 'CUSTOMER');
    expect(c['shape'], 'entity');
    expect(c['attributes'], [
      {'name': 'id', 'type': 'string', 'pk': true, 'fk': false},
      {'name': 'name', 'type': 'string', 'pk': false, 'fk': false},
      {'name': 'org_id', 'type': 'int', 'pk': false, 'fk': true},
      {'name': 'code', 'type': 'string', 'pk': true, 'fk': true},
    ]);
    expect(nodes.firstWhere((n) => n['id'] == 'ORDER')['attributes'], isEmpty);
    expect(d['edges'], [
      {
        'from': 'CUSTOMER',
        'to': 'ORDER',
        'fromCardinality': 'one',
        'toCardinality': 'zeroOrMany',
      },
    ]);
  });

  test('cardinality table: every marker pair, both line styles', () {
    const left = {
      '||': 'one',
      '|o': 'zeroOrOne',
      '}o': 'zeroOrMany',
      '}|': 'oneOrMany',
    };
    const right = {
      '||': 'one',
      'o|': 'zeroOrOne',
      'o{': 'zeroOrMany',
      '|{': 'oneOrMany',
    };
    for (final l in left.entries) {
      for (final r in right.entries) {
        for (final line in ['--', '..']) {
          final d = parseMermaidEr('erDiagram\nA ${l.key}$line${r.key} B : x');
          final e = (d['edges'] as List).single as Map;
          expect(
            e['fromCardinality'],
            l.value,
            reason: '${l.key}$line${r.key}',
          );
          expect(e['toCardinality'], r.value, reason: '${l.key}$line${r.key}');
        }
      }
    }
  });

  test('quoted names, comments, bad line number', () {
    final d = parseMermaidEr('%% hi\nerDiagram\n"LINE ITEM" ||--|| B');
    expect((d['edges'] as List).single['from'], 'LINE ITEM');
    expect(
      () => parseMermaidEr('erDiagram\nA ||--o{ B\nA nonsense here'),
      throwsA(
        isA<DiagramSpecException>().having(
          (e) => e.message,
          'message',
          startsWith('line 3:'),
        ),
      ),
    );
  });
}
