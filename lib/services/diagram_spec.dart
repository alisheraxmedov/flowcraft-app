import 'dart:ui';

import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/models/sketch_style.dart';

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

/// Ceiling on how many elements one draw call may hand over.
///
/// The canvas has to keep painting after the call returns, so a request for
/// a million rectangles is a frame-time and memory problem long after the
/// HTTP response is gone — and it arrives from a model, which can miscount
/// by orders of magnitude without noticing. Agent-drawn diagrams run to
/// tens of elements; 10,000 leaves room for a generated import while still
/// refusing a runaway.
const int maxDiagramElements = 10000;

/// Largest coordinate or dimension, in canvas pixels, an element may carry.
///
/// Finiteness alone isn't enough: `1e300` is a perfectly ordinary double
/// that still wedges layout and rasterization. A million pixels is already
/// far outside anything a diagram places.
const double maxDiagramCoordinate = 1000000;

/// Largest font size the text layout can be asked for. Well past legible;
/// short of the values that turn one glyph into a full-screen raster.
const double maxDiagramFontSize = 512;

/// Longest `text` one element may carry, in UTF-16 code units.
///
/// The request body is capped at 8 MiB, but nothing else stood between one
/// `{"type":"text","text":"<7 MB>"}` element and the canvas — where it
/// would be laid out by the painter every frame, autosaved to disk and
/// rasterised by the PNG exporter. A label or a sticky note runs to a
/// sentence or a paragraph; 4,096 characters is a page.
const int maxDiagramTextLength = 4096;

/// Hex colour as the schema documents it: `RRGGBB` or `AARRGGBB`, with an
/// optional leading `#`. Anything else — a sign, three-digit shorthand, a
/// named colour — is refused rather than guessed at, because `int.tryParse`
/// accepted `"#-1"` and `"#FFF"` became a nearly transparent black.
final RegExp _hexColor = RegExp(r'^#?[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$');

List<SketchElement> parseDiagramElements(List<dynamic> raw) {
  if (raw.length > maxDiagramElements) {
    throw DiagramSpecException(
      'Too many elements: ${raw.length}. At most $maxDiagramElements can be '
      'drawn per call — split the diagram across several calls.',
    );
  }
  return [for (final entry in raw) _parseOne(entry)];
}

SketchElement _parseOne(dynamic entry) {
  if (entry is! Map) {
    throw DiagramSpecException('Element must be an object, got: $entry');
  }
  final map = entry.cast<String, dynamic>();
  final type = _string(map, 'type');
  if (type == null) {
    throw DiagramSpecException('Element is missing a "type" field.');
  }

  final style = SketchStyle(
    strokeColor: _color(map['strokeColor']) ?? const Color(0xFF1E1E1E),
    fillColor: _color(map['fillColor']),
  );
  final text = _string(map, 'text');
  if (text != null && text.length > maxDiagramTextLength) {
    throw DiagramSpecException(
      '"text" is too long: ${text.length} characters (max '
      '$maxDiagramTextLength). Split it across several elements.',
    );
  }
  final fontSize = _fontSize(map);

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
        position: Offset(_number(map, 'x', 0), _number(map, 'y', 0)),
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

/// Reads one string field, or `null` when it is absent.
///
/// Checked, not cast: `map['text'] as String?` on `{"text": 5}` throws a
/// `TypeError`, which is not a [DiagramSpecException] — on the REST path
/// that surfaced as a 500 "internal server error", on MCP as the raw Dart
/// cast message, neither of which tells the caller what to change.
String? _string(Map<String, dynamic> map, String key) {
  final raw = map[key];
  if (raw == null) return null;
  if (raw is! String) {
    throw DiagramSpecException('"$key" must be a string, got: $raw');
  }
  return raw;
}

Rect _rect(Map<String, dynamic> map) {
  return Rect.fromLTWH(
    _number(map, 'x', 0),
    _number(map, 'y', 0),
    _dimension(map, 'width', 160),
    _dimension(map, 'height', 80),
  );
}

Offset _offset(Map<String, dynamic> map, String xKey, String yKey) {
  return Offset(_number(map, xKey, 0), _number(map, yKey, 0));
}

/// Reads one numeric field, or [fallback] when it is absent.
///
/// JSON has no literal for the values this rejects, but `1e999` decodes to
/// `Infinity` and `Infinity - Infinity` on the way to a bound gives `NaN` —
/// and both reach [Rect] and [Offset], where a non-finite edge quietly drops
/// the element out of every hit test and can stall the painter. Refusing
/// them here means the MCP layer reports a tool error the model can act on
/// instead of the canvas going strange several frames later.
double _number(Map<String, dynamic> map, String key, double fallback) {
  final raw = map[key];
  if (raw == null) return fallback;
  if (raw is! num) {
    throw DiagramSpecException('"$key" must be a number, got: $raw');
  }
  final value = raw.toDouble();
  if (!value.isFinite) {
    throw DiagramSpecException('"$key" must be a finite number, got: $raw');
  }
  if (value.abs() > maxDiagramCoordinate) {
    throw DiagramSpecException(
      '"$key" is out of range: $raw (max ±$maxDiagramCoordinate).',
    );
  }
  return value;
}

/// A [_number] that also has to describe an extent, so it can't be negative
/// — [Rect.fromLTWH] would accept it and hand back an inverted rectangle.
double _dimension(Map<String, dynamic> map, String key, double fallback) {
  final value = _number(map, key, fallback);
  if (value < 0) {
    throw DiagramSpecException('"$key" cannot be negative, got: $value');
  }
  return value;
}

double _fontSize(Map<String, dynamic> map) {
  final value = _number(map, 'fontSize', 16);
  if (value <= 0 || value > maxDiagramFontSize) {
    throw DiagramSpecException(
      '"fontSize" must be between 0 and $maxDiagramFontSize, got: $value',
    );
  }
  return value;
}

Color? _color(dynamic hex) {
  if (hex == null) return null;
  if (hex is! String) {
    throw DiagramSpecException('Color must be a hex string, got: $hex');
  }
  if (hex.isEmpty) return null;
  if (!_hexColor.hasMatch(hex)) {
    throw DiagramSpecException(
      'Invalid hex color: "$hex" (expected "#RRGGBB" or "#AARRGGBB")',
    );
  }
  var value = hex.startsWith('#') ? hex.substring(1) : hex;
  if (value.length == 6) value = 'FF$value';
  return Color(int.parse(value, radix: 16));
}
