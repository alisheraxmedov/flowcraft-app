import 'package:flowcraft/services/diagram_spec.dart';
import 'package:flowcraft/services/text_import/dbml.dart';
import 'package:flutter_test/flutter_test.dart';

Map<String, dynamic> table(Map<String, dynamic> d, String id) =>
    (d['nodes'] as List).cast<Map<String, dynamic>>().firstWhere(
      (n) => n['id'] == id,
    );

Map<String, dynamic> col(Map<String, dynamic> d, String t, String c) =>
    (table(d, t)['attributes'] as List).cast<Map<String, dynamic>>().firstWhere(
      (a) => a['name'] == c,
    );

const _base = '''
// users
Table users as U {
  id integer [pk, increment]
  "full name" varchar(255) [not null, note: 'a, b']
  note text
  indexes {
    id [unique]
  }
}
Table posts {
  id int [pk]
  user_id int
}
Enum status { a\n b }
Project p { database_type: 'PostgreSQL' }
''';

void main() {
  test('happy path: tables, columns, types, pk, skipped blocks', () {
    final d = parseDbml(_base);
    expect((d['nodes'] as List).length, 2);
    expect(table(d, 'users')['shape'], 'entity');
    expect(col(d, 'users', 'id'), {
      'name': 'id',
      'type': 'integer',
      'pk': true,
      'fk': false,
    });
    expect(col(d, 'users', 'full name')['type'], 'varchar(255)');
    expect(col(d, 'users', 'note')['type'], 'text');
  });

  test('Ref forms > < - <> with alias, named and block variants', () {
    Map<String, dynamic> ref(String r) =>
        (parseDbml('$_base\n$r')['edges'] as List).single
            as Map<String, dynamic>;

    var e = ref('Ref: posts.user_id > users.id');
    expect(
      [e['from'], e['to'], e['fromCardinality'], e['toCardinality']],
      ['posts', 'users', 'many', 'one'],
    );
    expect([e['fromAttribute'], e['toAttribute']], ['user_id', 'id']);

    e = ref('Ref: users.id < posts.user_id');
    expect([e['fromCardinality'], e['toCardinality']], ['one', 'many']);
    e = ref('Ref: users.id - posts.user_id');
    expect([e['fromCardinality'], e['toCardinality']], ['one', 'one']);
    e = ref('Ref: users.id <> posts.user_id');
    expect([e['fromCardinality'], e['toCardinality']], ['many', 'many']);

    e = ref('Ref fk_name: posts.user_id > U.id [delete: cascade]');
    expect(e['to'], 'users'); // alias resolved
    e = ref('Ref {\n  posts.user_id > public.users.id\n}');
    expect(e['to'], 'users'); // schema dropped
  });

  test('inline ref and fk flag on the referencing column', () {
    var d = parseDbml('''
Table a {\n id int [pk]\n b_id int [ref: > b.id, not null]\n}
Table b {
 id int [pk]
}
''');
    expect(col(d, 'a', 'b_id')['fk'], true);
    expect(col(d, 'b', 'id')['fk'], false);
    expect((d['edges'] as List).single['fromAttribute'], 'b_id');

    d = parseDbml('''
Table a {
 id int [pk]
}
Table b {
 a_id int
}
Ref: a.id < b.a_id
''');
    expect(col(d, 'b', 'a_id')['fk'], true);
    expect(col(d, 'a', 'id')['fk'], false);
  });

  test('errors carry line numbers', () {
    expect(
      () => parseDbml('Table a {\n id int\n}\n\nwhat is this'),
      throwsA(
        isA<DiagramSpecException>().having(
          (e) => e.message,
          'message',
          startsWith('line 5:'),
        ),
      ),
    );
    expect(
      () => parseDbml('Table a {\n id int\n}\nRef: a.id > ghost.id'),
      throwsA(
        isA<DiagramSpecException>().having(
          (e) => e.message,
          'message',
          startsWith('line 4: unknown table'),
        ),
      ),
    );
  });

  test('element cap enforced', () {
    final sb = StringBuffer();
    for (var i = 0; i < 10001; i++) {
      sb.writeln('Table t$i {\n id int\n}');
    }
    expect(
      () => parseDbml(sb.toString()),
      throwsA(isA<DiagramSpecException>()),
    );
  });
}
