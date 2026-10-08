import '../diagram_spec.dart';

/// `line N: message` — every text-import parser reports syntax problems the
/// same way so the caller can point the user at the offending line.
DiagramSpecException importError(int line, String message) =>
    DiagramSpecException('line $line: $message');

/// Final gate shared by the Mermaid and DBML parsers: enforces the element
/// and label caps (the text is untrusted) and assembles the vocabulary map
/// `buildDiagram` / `flowcraft_diagram` accept. Frames with no members are
/// dropped, since there is nothing to enclose.
Map<String, dynamic> importVocabulary({
  required String direction,
  required List<Map<String, dynamic>> nodes,
  required List<Map<String, dynamic>> edges,
  List<Map<String, dynamic>> frames = const [],
}) {
  if (nodes.length + edges.length > maxDiagramElements) {
    throw DiagramSpecException(
      'Too many elements: ${nodes.length + edges.length}. At most '
      '$maxDiagramElements nodes and edges fit in one import.',
    );
  }
  for (final n in nodes) {
    final label = n['label'] as String;
    if (label.length > maxDiagramTextLength) {
      throw DiagramSpecException(
        'Node "${n['id']}": label is too long: ${label.length} characters '
        '(max $maxDiagramTextLength).',
      );
    }
  }
  return {
    'direction': direction,
    'nodes': nodes,
    'edges': edges,
    'frames': [
      for (final f in frames)
        if ((f['members'] as List).isNotEmpty) f,
    ],
  };
}

/// Statements that only style or wire up interactivity — nothing to draw.
final _ignored = RegExp(
  r'^(classDef|class|style|click|linkStyle|direction|accTitle|accDescr)\b',
);
final _header = RegExp(
  r'^(?:graph|flowchart)(?:\s+(TB|TD|LR|BT|RL))?\s*;?$',
  caseSensitive: false,
);
final _id = RegExp(r'[\p{L}\p{N}_]+', unicode: true);
final _classSuffix = RegExp(r':::[\w-]+');

/// Node bracket pairs, two-character openers first so `([` is not read as
/// `(` + `[`. Value is (closer, shape).
const _brackets = <String, (String, String)>{
  '([': ('])', 'ellipse'),
  '((': ('))', 'ellipse'),
  '[[': (']]', 'rectangle'),
  '[(': (')]', 'ellipse'),
  '{{': ('}}', 'rectangle'),
  '(': (')', 'ellipse'),
  '[': (']', 'rectangle'),
  '{': ('}', 'diamond'),
  '>': (']', 'rectangle'),
};

/// `-- text -->`, `== text ==>`, `-. text .->`: the label sits inside the
/// link. Tried before the plain operators.
final _textLink = RegExp(
  r'^(?:--|==|-\.)\s+(.+?)\s+(?:-{2,}[>xo]?|={2,}>?|\.+->?)(?=\s|$)',
);
final _link = RegExp(r'^<?(?:-\.+->?|-{2,}[>xo]?|={2,}>?)');
final _pipeLabel = RegExp(r'\s*\|[^|]*\|');

/// Parses the Mermaid flowchart subset into the diagram vocabulary.
///
/// Subgraph membership is flattened: a node belongs to the innermost
/// subgraph it is first mentioned in, and an outer subgraph holds only its
/// own direct nodes. Self-loops (`a --> a`) are dropped because the layout
/// refuses them. Edge labels are dropped (no slot for them).
Map<String, dynamic> parseMermaidFlowchart(String text) {
  final nodes = <String, Map<String, dynamic>>{};
  final edges = <Map<String, dynamic>>[];
  final frames = <Map<String, dynamic>>[];
  final open = <Map<String, dynamic>>[];
  var direction = 'TB';
  var sawHeader = false;
  final framed = <String>{};

  void touch(String id, {String? label, String? shape}) {
    final n = nodes.putIfAbsent(
      id,
      () => {'id': id, 'label': id, 'shape': 'rectangle'},
    );
    if (shape != null) {
      n['label'] = label;
      n['shape'] = shape;
    }
    if (open.isNotEmpty && framed.add(id)) {
      (open.last['members'] as List).add(id);
    }
  }

  final lines = text.split('\n');
  for (var i = 0; i < lines.length; i++) {
    final no = i + 1;
    var line = lines[i].trim();
    if (line.endsWith(';')) line = line.substring(0, line.length - 1).trim();
    if (line.isEmpty || line.startsWith('%%')) continue;

    if (!sawHeader) {
      final m = _header.firstMatch(line);
      if (m == null) {
        throw importError(no, 'expected "graph" or "flowchart", got "$line"');
      }
      final d = m.group(1)?.toUpperCase();
      direction = d == null || d == 'TD' ? 'TB' : d;
      sawHeader = true;
      continue;
    }
    if (_ignored.hasMatch(line)) continue;

    if (line.startsWith('subgraph')) {
      var name = line.substring(8).trim();
      final br = RegExp(r'^[^\[]*\[(.*)\]$').firstMatch(name);
      name = (br?.group(1) ?? name).trim();
      if (name.length >= 2 && name.startsWith('"') && name.endsWith('"')) {
        name = name.substring(1, name.length - 1);
      }
      final frame = <String, dynamic>{'name': name, 'members': <String>[]};
      frames.add(frame);
      open.add(frame);
      continue;
    }
    if (line == 'end') {
      if (open.isEmpty) throw importError(no, '"end" without "subgraph"');
      open.removeLast();
      continue;
    }

    // Statement: group (link group)*, where group = node (& node)*.
    var pos = 0;
    List<String>? prev;
    while (true) {
      final group = <String>[];
      while (true) {
        while (pos < line.length && line[pos] == ' ') {
          pos++;
        }
        final idm = _id.matchAsPrefix(line, pos);
        if (idm == null) {
          throw importError(no, 'unrecognised statement "$line"');
        }
        final id = idm.group(0)!;
        pos = idm.end;
        String? label, shape;
        for (final e in _brackets.entries) {
          if (!line.startsWith(e.key, pos)) continue;
          var start = pos + e.key.length;
          final (closer, s) = e.value;
          while (start < line.length && line[start] == ' ') {
            start++;
          }
          int end;
          if (start < line.length && line[start] == '"') {
            final q = line.indexOf('"', start + 1);
            if (q < 0) throw importError(no, 'unterminated quote in "$line"');
            label = line.substring(start + 1, q);
            end = line.indexOf(closer, q);
          } else {
            end = line.indexOf(closer, start);
            if (end >= 0) label = line.substring(start, end).trim();
          }
          if (end < 0) {
            throw importError(no, 'missing "$closer" in "$line"');
          }
          label = label!.replaceAll(RegExp(r'<br\s*/?>'), '\n');
          shape = s;
          pos = end + closer.length;
          break;
        }
        touch(id, label: label, shape: shape);
        group.add(id);
        pos = _classSuffix.matchAsPrefix(line, pos)?.end ?? pos;
        while (pos < line.length && line[pos] == ' ') {
          pos++;
        }
        if (pos < line.length && line[pos] == '&') {
          pos++;
          continue;
        }
        break;
      }
      if (prev != null) {
        for (final a in prev) {
          for (final b in group) {
            // ponytail: self-loops dropped, layout rejects them; add loop
            // support to buildDiagram first if they matter.
            if (a != b) edges.add({'from': a, 'to': b});
          }
        }
      }
      if (pos >= line.length) break;
      final rest = line.substring(pos);
      final len = (_textLink.firstMatch(rest) ?? _link.firstMatch(rest))?.end;
      if (len == null) throw importError(no, 'unrecognised statement "$line"');
      pos += len;
      pos = _pipeLabel.matchAsPrefix(line, pos)?.end ?? pos;
      prev = group;
    }
  }
  if (!sawHeader) throw importError(1, 'empty diagram');
  if (open.isNotEmpty) {
    throw importError(lines.length, '"subgraph" without matching "end"');
  }
  return importVocabulary(
    direction: direction,
    nodes: nodes.values.toList(),
    edges: edges,
    frames: frames,
  );
}
