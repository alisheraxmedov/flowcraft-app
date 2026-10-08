import 'dart:convert';

import '../diagram_spec.dart';
import 'mermaid_er.dart';
import 'mermaid_flowchart.dart';

enum TextFormat { json, excalidraw, mermaid, dbml, unknown }

final _mermaidHeader = RegExp(r'^(graph|flowchart|erDiagram)(\s|;|$)');
final _dbmlStart = RegExp(
  r'^(Table|Ref|Enum|TableGroup|Project)\b',
  caseSensitive: false,
);

/// Sniffs what [text] is without fully parsing it. Excalidraw is tested
/// before FlowCraft JSON because both carry `version` and `elements`.
TextFormat detectTextFormat(String text) {
  final t = text.trim();
  if (t.startsWith('{')) {
    try {
      final j = jsonDecode(t);
      if (j is Map) {
        if (j['type'] == 'excalidraw') return TextFormat.excalidraw;
        if (j.containsKey('version') && j.containsKey('elements')) {
          return TextFormat.json;
        }
      }
    } on FormatException {
      // fall through: not JSON after all
    }
    return TextFormat.unknown;
  }
  for (final raw in t.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('%%') || line.startsWith('//')) {
      continue;
    }
    if (_mermaidHeader.hasMatch(line)) return TextFormat.mermaid;
    if (_dbmlStart.hasMatch(line)) return TextFormat.dbml;
    break;
  }
  return TextFormat.unknown;
}

/// Parses either Mermaid dialect (`erDiagram` or flowchart) by its header.
Map<String, dynamic> parseMermaid(String text) {
  for (final raw in text.split('\n')) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('%%')) continue;
    return line.startsWith('erDiagram')
        ? parseMermaidEr(text)
        : parseMermaidFlowchart(text);
  }
  throw DiagramSpecException('line 1: empty diagram');
}
