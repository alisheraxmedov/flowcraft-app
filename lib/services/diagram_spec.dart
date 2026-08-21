import 'dart:ui';

import 'package:flowcraft/flowcraft.dart';

/// Translates the simplified JSON diagram shapes accepted by the MCP
/// bridge's `/draw` endpoint into real [SketchElement]s, using each
/// element's `.create()` factory so unspecified fields fall back to the
/// same defaults the whiteboard toolbar uses.
///
/// Kept isolated in the example app on purpose: the core `flowcraft`
/// package stays a plain, dependency-free widget library and knows
/// nothing about MCP or HTTP.
class DiagramSpecException implements Exception {
  DiagramSpecException(this.message);
  final String message;

  @override
  String toString() => message;
}

List<SketchElement> parseDiagramElements(List<dynamic> raw) {
  return [for (final entry in raw) _parseOne(entry)];
}

SketchElement _parseOne(dynamic entry) {
  if (entry is! Map) {
    throw DiagramSpecException('Element must be an object, got: $entry');
  }
  final map = entry.cast<String, dynamic>();
  final type = map['type'] as String?;
  if (type == null) {
    throw DiagramSpecException('Element is missing a "type" field.');
  }

  final style = SketchStyle(
    strokeColor: _color(map['strokeColor']) ?? const Color(0xFF1E1E1E),
    fillColor: _color(map['fillColor']),
  );
  final text = map['text'] as String?;
  final fontSize = (map['fontSize'] as num?)?.toDouble() ?? 16.0;

  switch (type) {
    case 'rectangle':
      return SketchRectangle.create(
        rect: _rect(map),
        style: style,
        text: text,
        fontSize: fontSize,
      );
    case 'ellipse':
      return SketchEllipse.create(
        rect: _rect(map),
        style: style,
        text: text,
        fontSize: fontSize,
      );
    case 'diamond':
      return SketchDiamond.create(
        rect: _rect(map),
        style: style,
        text: text,
        fontSize: fontSize,
      );
    case 'triangle':
      return SketchTriangle.create(
        rect: _rect(map),
        style: style,
        text: text,
        fontSize: fontSize,
      );
    case 'sticky':
      return SketchSticky.create(
        rect: _rect(map),
        style: map['strokeColor'] == null && map['fillColor'] == null
            ? null
            : style,
        text: text,
        fontSize: fontSize,
      );
    case 'text':
      if (text == null) {
        throw DiagramSpecException('A "text" element needs a "text" field.');
      }
      return SketchText.create(
        position: Offset(
          (map['x'] as num?)?.toDouble() ?? 0,
          (map['y'] as num?)?.toDouble() ?? 0,
        ),
        text: text,
        fontSize: fontSize,
        style: style,
      );
    case 'arrow':
      return SketchArrow.create(
        start: _offset(map, 'fromX', 'fromY'),
        end: _offset(map, 'toX', 'toY'),
        style: style,
      );
    case 'line':
      return SketchLine.create(
        start: _offset(map, 'fromX', 'fromY'),
        end: _offset(map, 'toX', 'toY'),
        style: style,
      );
    default:
      throw DiagramSpecException('Unknown element type: "$type"');
  }
}

Rect _rect(Map<String, dynamic> map) {
  final x = (map['x'] as num?)?.toDouble() ?? 0;
  final y = (map['y'] as num?)?.toDouble() ?? 0;
  final width = (map['width'] as num?)?.toDouble() ?? 160;
  final height = (map['height'] as num?)?.toDouble() ?? 80;
  return Rect.fromLTWH(x, y, width, height);
}

Offset _offset(Map<String, dynamic> map, String xKey, String yKey) {
  return Offset(
    (map[xKey] as num?)?.toDouble() ?? 0,
    (map[yKey] as num?)?.toDouble() ?? 0,
  );
}

Color? _color(dynamic hex) {
  if (hex is! String || hex.isEmpty) return null;
  var value = hex.startsWith('#') ? hex.substring(1) : hex;
  if (value.length == 6) value = 'FF$value';
  final parsed = int.tryParse(value, radix: 16);
  if (parsed == null) {
    throw DiagramSpecException('Invalid hex color: "$hex"');
  }
  return Color(parsed);
}
