import 'mermaid_flowchart.dart';

// Marker next to the left entity / next to the right entity.
const _left = {
  '||': 'one',
  '|o': 'zeroOrOne',
  '}o': 'zeroOrMany',
  '}|': 'oneOrMany',
};
const _right = {
  '||': 'one',
  'o|': 'zeroOrOne',
  'o{': 'zeroOrMany',
  '|{': 'oneOrMany',
};

const _name = r'("[^"]+"|[\w.-]+)';
final _rel = RegExp(
  '^$_name\\s+([|}][|o])(?:--|\\.\\.)([|o][|{])\\s+$_name(?:\\s*:.*)?\$',
);
final _entityOpen = RegExp('^$_name\\s*\\{\$');
final _entityBare = RegExp('^$_name\$');
final _comment = RegExp(r'\s*"[^"]*"\s*$');

String _unquote(String s) =>
    s.startsWith('"') ? s.substring(1, s.length - 1) : s;

/// Parses a Mermaid `erDiagram` into the diagram vocabulary: every entity is
/// a `shape: 'entity'` node with its attribute rows. Relationship labels are
/// dropped; self-relationships are dropped because the layout rejects loops.
/// Direction defaults to LR (rows anchor on the left/right edges) and
/// follows a `direction XX` line when present.
Map<String, dynamic> parseMermaidEr(String text) {
  final nodes = <String, Map<String, dynamic>>{};
  final edges = <Map<String, dynamic>>[];
  var direction = 'LR';
  var sawHeader = false;
  List<Map<String, dynamic>>? rows; // attributes of the open entity block

  Map<String, dynamic> entity(String id) => nodes.putIfAbsent(
    id,
    () => {
      'id': id,
      'label': id,
      'shape': 'entity',
      'attributes': <Map<String, dynamic>>[],
    },
  );

  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final no = i + 1;
    var line = lines[i].trim();
    if (line.isEmpty || line.startsWith('%%')) continue;

    if (!sawHeader) {
      if (line != 'erDiagram') {
        throw importError(no, 'expected "erDiagram", got "$line"');
      }
      sawHeader = true;
      continue;
    }

    if (rows != null) {
      if (line == '}') {
        rows = null;
        continue;
      }
      // type name [PK|FK|UK, ...] ["comment"]
      final t = line.replaceFirst(_comment, '').split(RegExp(r'\s+'));
      if (t.length < 2) throw importError(no, 'unrecognised attribute "$line"');
      final keys = t
          .skip(2)
          .expand((k) => k.split(','))
          .map((k) => k.toUpperCase());
      rows.add({
        'name': t[1],
        'type': t[0],
        'pk': keys.contains('PK'),
        'fk': keys.contains('FK'),
      });
      continue;
    }

    final dir = RegExp(r'^direction\s+(TB|TD|LR|BT|RL)$').firstMatch(line);
    if (dir != null) {
      final d = dir.group(1)!;
      direction = d == 'TD' ? 'TB' : d;
      continue;
    }
    final rel = _rel.firstMatch(line);
    final open = _entityOpen.firstMatch(line);
    final bare = _entityBare.firstMatch(line);
    final lc = rel == null ? null : _left[rel.group(2)];
    final rc = rel == null ? null : _right[rel.group(3)];
    if (rel != null && lc != null && rc != null) {
      final a = _unquote(rel.group(1)!), b = _unquote(rel.group(4)!);
      entity(a);
      entity(b);
      if (a != b) {
        edges.add({
          'from': a,
          'to': b,
          'fromCardinality': lc,
          'toCardinality': rc,
        });
      }
    } else if (open != null) {
      rows =
          entity(_unquote(open.group(1)!))['attributes']
              as List<Map<String, dynamic>>;
    } else if (bare != null) {
      entity(_unquote(bare.group(1)!));
    } else {
      throw importError(no, 'unrecognised statement "$line"');
    }
  }
  if (!sawHeader) throw importError(1, 'empty diagram');
  if (rows != null) throw importError(lines.length, 'entity block not closed');
  return importVocabulary(
    direction: direction,
    nodes: nodes.values.toList(),
    edges: edges,
  );
}
