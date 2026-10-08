import 'mermaid_flowchart.dart';

const _n = r'(?:"[^"]+"|[\w.]+)'; // identifier, optionally quoted / dotted
final _table = RegExp(
  '^Table\\s+($_n)(?:\\s+as\\s+($_n))?\\s*(?:\\[[^\\]]*\\])?\\s*\\{\$',
  caseSensitive: false,
);
final _refStart = RegExp(
  '^Ref(?:\\s+($_n))?\\s*(?::\\s*(.*)|\\{)\$',
  caseSensitive: false,
);
final _skipped = RegExp(
  r'^(Enum|TableGroup|Project|Note|indexes)\b',
  caseSensitive: false,
);

/// Inside a table only these are not columns (a column may be *named* note).
final _tableExtra = RegExp(
  r'^(indexes\s*\{|Note\s*[:{])',
  caseSensitive: false,
);
final _refBody = RegExp('^($_n)\\s*(<>|>|<|-)\\s*($_n)\\s*(?:\\[.*\\])?\$');

/// Removes `//` and `/* */` comments and collapses `'''…'''` notes, keeping
/// every newline so reported line numbers still match the user's text.
String _clean(String s) {
  final out = StringBuffer();
  var quote = '';
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (quote.isNotEmpty) {
      out.write(c);
      if (c == quote) quote = '';
    } else if (s.startsWith("'''", i)) {
      final end = s.indexOf("'''", i + 3);
      final stop = end < 0 ? s.length : end + 3;
      out.write(s.substring(i, stop).replaceAll(RegExp(r'[^\n]'), ''));
      i = stop - 1;
    } else if (s.startsWith('//', i)) {
      while (i + 1 < s.length && s[i + 1] != '\n') {
        i++;
      }
    } else if (s.startsWith('/*', i)) {
      final end = s.indexOf('*/', i + 2);
      final stop = end < 0 ? s.length : end + 2;
      out.write(s.substring(i, stop).replaceAll(RegExp(r'[^\n]'), ''));
      i = stop - 1;
    } else {
      if (c == '"' || c == "'") quote = c;
      out.write(c);
    }
  }
  return out.toString();
}

String _unq(String s) => s.replaceAll('"', '');

/// `schema.table.col` / `table.col` → (table, col); schema is discarded
/// because table nodes are keyed by bare name.
(String, String)? _endpoint(String s) {
  final p = _unq(s).split('.');
  return p.length < 2 ? null : (p[p.length - 2], p.last);
}

/// Splits on top-level commas (not inside quotes, parens or brackets).
List<String> _splitSettings(String s) {
  final out = <String>[];
  var depth = 0, from = 0;
  String? quote;
  for (var i = 0; i < s.length; i++) {
    final c = s[i];
    if (quote != null) {
      if (c == quote) quote = null;
    } else if (c == '"' || c == "'" || c == '`') {
      quote = c;
    } else if ('([{'.contains(c)) {
      depth++;
    } else if (')]}'.contains(c)) {
      depth--;
    } else if (c == ',' && depth == 0) {
      out.add(s.substring(from, i).trim());
      from = i + 1;
    }
  }
  out.add(s.substring(from).trim());
  return out;
}

/// Parses DBML into the diagram vocabulary (entity nodes + relationship
/// edges). `Enum`, `TableGroup`, `Project`, `Note` and `indexes` blocks are
/// skipped. The foreign key flag lands on the referencing column: the left
/// side of `>` and `-`, the right side of `<`; `<>` (many-to-many) sets none.
/// Composite refs such as `t.(a, b)` are not supported.
Map<String, dynamic> parseDbml(String text) {
  final nodes = <String, Map<String, dynamic>>{};
  final aliases = <String, String>{};
  // line, left, op, right
  final refs = <(int, (String, String), String, (String, String))>[];
  List<Map<String, dynamic>>? cols;
  String? table;
  var inRefBlock = false;
  var skipDepth = 0;

  void addRef(int no, String body) {
    final m = _refBody.firstMatch(body.trim());
    final l = m == null ? null : _endpoint(m.group(1)!);
    final r = m == null ? null : _endpoint(m.group(3)!);
    if (m == null || l == null || r == null) {
      throw importError(no, 'unrecognised statement "${body.trim()}"');
    }
    refs.add((no, l, m.group(2)!, r));
  }

  final lines = _clean(text).split('\n');
  for (var i = 0; i < lines.length; i++) {
    final no = i + 1;
    final line = lines[i].trim();
    if (line.isEmpty) continue;

    if (skipDepth > 0) {
      skipDepth += '{'.allMatches(line).length - '}'.allMatches(line).length;
      continue;
    }
    if (inRefBlock) {
      if (line == '}') {
        inRefBlock = false;
      } else {
        addRef(no, line);
      }
      continue;
    }

    if (cols != null) {
      if (line == '}') {
        cols = null;
        table = null;
      } else if (_tableExtra.hasMatch(line)) {
        skipDepth = '{'.allMatches(line).length - '}'.allMatches(line).length;
      } else {
        cols.add(_column(no, line, table!, refs));
      }
      continue;
    }

    final t = _table.firstMatch(line);
    final r = _refStart.firstMatch(line);
    if (t != null) {
      table = _unq(t.group(1)!).split('.').last;
      if (t.group(2) != null) aliases[_unq(t.group(2)!)] = table;
      cols = <Map<String, dynamic>>[];
      nodes[table] = {
        'id': table,
        'label': table,
        'shape': 'entity',
        'attributes': cols,
      };
    } else if (r != null) {
      final body = r.group(2);
      if (body == null) {
        inRefBlock = true;
      } else {
        addRef(no, body);
      }
    } else if (_skipped.hasMatch(line)) {
      skipDepth = '{'.allMatches(line).length - '}'.allMatches(line).length;
    } else {
      throw importError(no, 'unrecognised statement "$line"');
    }
  }
  if (cols != null || inRefBlock || skipDepth > 0) {
    throw importError(lines.length, 'block not closed');
  }

  final edges = <Map<String, dynamic>>[];
  Map<String, dynamic> col(int no, (String, String) e) {
    final tbl = aliases[e.$1] ?? e.$1;
    final node = nodes[tbl];
    if (node == null) throw importError(no, 'unknown table "${e.$1}"');
    return (node['attributes'] as List<Map<String, dynamic>>).firstWhere(
      (c) => c['name'] == e.$2,
      orElse: () =>
          throw importError(no, 'table "$tbl" has no column "${e.$2}"'),
    );
  }

  for (final (no, l, op, r) in refs) {
    final lc = col(no, l), rc = col(no, r);
    if (op == '<') {
      rc['fk'] = true;
    } else if (op != '<>') {
      lc['fk'] = true;
    }
    final (fromC, toC) = switch (op) {
      '>' => ('many', 'one'),
      '<' => ('one', 'many'),
      '-' => ('one', 'one'),
      _ => ('many', 'many'),
    };
    final from = aliases[l.$1] ?? l.$1, to = aliases[r.$1] ?? r.$1;
    // ponytail: self-references dropped, layout rejects loops.
    if (from == to) continue;
    edges.add({
      'from': from,
      'to': to,
      'fromCardinality': fromC,
      'toCardinality': toC,
      'fromAttribute': l.$2,
      'toAttribute': r.$2,
    });
  }
  return importVocabulary(
    direction: 'LR',
    nodes: nodes.values.toList(),
    edges: edges,
  );
}

/// One column line: `name type [settings]`. An inline `ref:` is queued on
/// [refs] exactly as if it were a `Ref:` statement.
Map<String, dynamic> _column(
  int no,
  String line,
  String table,
  List<(int, (String, String), String, (String, String))> refs,
) {
  final name = RegExp('^($_n)\\s+').firstMatch(line);
  if (name == null) throw importError(no, 'unrecognised statement "$line"');
  var pos = name.end;
  // Type: quoted, or up to whitespace / '[' outside parentheses.
  var depth = 0;
  final typeStart = pos;
  if (pos < line.length && line[pos] == '"') {
    pos = line.indexOf('"', pos + 1) + 1;
    if (pos == 0) throw importError(no, 'unterminated quote in "$line"');
  } else {
    while (pos < line.length) {
      final c = line[pos];
      if (c == '(') depth++;
      if (c == ')') depth--;
      if (depth == 0 && (c == ' ' || c == '\t' || c == '[')) break;
      pos++;
    }
  }
  final type = _unq(line.substring(typeStart, pos));
  if (type.isEmpty) throw importError(no, 'unrecognised statement "$line"');
  var pk = false;
  final open = line.indexOf('[', pos);
  if (open >= 0) {
    final close = line.lastIndexOf(']');
    if (close < open) throw importError(no, 'missing "]" in "$line"');
    final colName = _unq(name.group(1)!);
    for (final s in _splitSettings(line.substring(open + 1, close))) {
      final low = s.toLowerCase();
      if (low == 'pk' || low == 'primary key') pk = true;
      final ref = RegExp(
        r'^ref\s*:\s*(.*)$',
        caseSensitive: false,
      ).firstMatch(s);
      if (ref != null) {
        final m = RegExp(
          '^(<>|>|<|-)\\s*($_n)\$',
        ).firstMatch(ref.group(1)!.trim());
        final to = m == null ? null : _endpoint(m.group(2)!);
        if (m == null || to == null) {
          throw importError(no, 'unrecognised ref "${ref.group(1)}"');
        }
        refs.add((no, (table, colName), m.group(1)!, to));
      }
    }
  }
  return {'name': _unq(name.group(1)!), 'type': type, 'pk': pk, 'fk': false};
}
