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

double _fontSize(Map<String, dynamic> map) => _fontSizeOr(map, 16);

/// [_fontSize] with the fallback the caller chooses, so a patch that omits
/// `fontSize` keeps the element's current size instead of snapping to 16.
double _fontSizeOr(Map<String, dynamic> map, double fallback) {
  final value = _number(map, 'fontSize', fallback);
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

// ─── Reading the canvas back ─────────────────────────────────────────────

/// One element as a simplified, MCP-facing description — the inverse of
/// [_parseOne], and the payload `flowcraft_read` hands the model.
///
/// The vocabulary is deliberately the *same words* `flowcraft_draw` accepts
/// (`type`, `x`/`y`/`width`/`height`, `fromX`/`fromY`/`toX`/`toY`, `text`,
/// `fontSize`, `strokeColor`, `fillColor`), plus the element's [id] — so an
/// agent that reads the canvas can turn round and feed the very same fields
/// straight into `flowcraft_update` without a second mental model. It is a
/// lossy view on purpose: only the fields the draw/update vocabulary can
/// express appear, which is enough to move, resize, recolour and relabel an
/// element, and enough to name any element for deletion.
Map<String, Object?> describeDiagramElement(SketchElement el) {
  switch (el) {
    case SketchRectangle():
      return _describeBounded(el, 'rectangle', el.text, el.fontSize);
    case SketchEllipse():
      return _describeBounded(el, 'ellipse', el.text, el.fontSize);
    case SketchDiamond():
      return _describeBounded(el, 'diamond', el.text, el.fontSize);
    case SketchTriangle():
      return _describeBounded(el, 'triangle', el.text, el.fontSize);
    case SketchSticky():
      return _describeBounded(el, 'sticky', el.text, el.fontSize);
    case SketchText():
      final b = el.unrotatedBounds;
      return {
        'id': el.id,
        'type': 'text',
        'x': b.left,
        'y': b.top,
        'text': el.text,
        'fontSize': el.fontSize,
        'strokeColor': _hex(el.style.strokeColor),
      };
    case SketchLine():
      return _describeLinear(el, 'line', el.start, el.end);
    case SketchArrow():
      return _describeLinear(el, 'arrow', el.start, el.end);
    case SketchFreedraw():
      // Freedraw geometry is a point list the draw vocabulary has no field
      // for, so only its bounding box and stroke are reported. That is not
      // enough to reshape it via `flowcraft_update` — and `applyDiagramPatch`
      // refuses to try — but it is enough to see it is there and delete it
      // by id, which is the point of listing it at all.
      final b = el.unrotatedBounds;
      return {
        'id': el.id,
        'type': 'freedraw',
        'x': b.left,
        'y': b.top,
        'width': b.width,
        'height': b.height,
        'strokeColor': _hex(el.style.strokeColor),
      };
  }
}

/// [describeDiagramElement] over a whole canvas, in stacking order.
List<Map<String, Object?>> describeDiagramElements(
  Iterable<SketchElement> els,
) {
  return [for (final el in els) describeDiagramElement(el)];
}

Map<String, Object?> _describeBounded(
  SketchElement el,
  String type,
  String? text,
  double fontSize,
) {
  // `unrotatedBounds` rather than a stored `rect` so linear and text
  // elements can share the same "left/top/width/height" reading; for the
  // bounded shapes it *is* the rect. A collapsed sticky reports its badge
  // box, which is what is actually on the canvas.
  final b = el.unrotatedBounds;
  return {
    'id': el.id,
    'type': type,
    'x': b.left,
    'y': b.top,
    'width': b.width,
    'height': b.height,
    'text': ?text,
    if (text != null) 'fontSize': fontSize,
    'strokeColor': _hex(el.style.strokeColor),
    if (el.style.fillColor != null) 'fillColor': _hex(el.style.fillColor!),
  };
}

Map<String, Object?> _describeLinear(
  SketchElement el,
  String type,
  Offset start,
  Offset end,
) {
  return {
    'id': el.id,
    'type': type,
    'fromX': start.dx,
    'fromY': start.dy,
    'toX': end.dx,
    'toY': end.dy,
    'strokeColor': _hex(el.style.strokeColor),
  };
}

/// A colour as `#AARRGGBB`, the 8-digit form [_color] round-trips exactly.
///
/// Always eight digits (alpha included) so a fully-opaque colour comes back
/// as the same string the draw path would accept, rather than a 6-digit
/// value that would silently reset alpha on the way back in.
String _hex(Color c) => '#${c.toARGB32().toRadixString(16).padLeft(8, '0')}';

// ─── Editing existing elements ───────────────────────────────────────────

/// A new element of the *same concrete type* as [existing], with only the
/// fields named in [patch] overridden and everything else preserved.
///
/// This is what `flowcraft_update` applies: an agent reads an element with
/// [describeDiagramElement], changes the handful of fields it wants, and
/// hands the result back here keyed by [SketchElement.id]. Crucially the
/// element's identity ([SketchElement.id]), its [SketchElement.angle], its
/// [SketchElement.groupId] and every unspecified geometry, style or text
/// field survive untouched — an omitted field means "leave it alone", which
/// is why the numeric validators below fall back to the element's *current*
/// value rather than a fixed default.
///
/// The one thing a patch may not do is change an element's kind: a
/// `type` that disagrees with [existing] is refused, because a rectangle and
/// an arrow share no geometry, and silently discarding the mismatched fields
/// would be worse than an error the agent can act on. An agent that wants a
/// different shape deletes this one and draws a new one.
SketchElement applyDiagramPatch(
  SketchElement existing,
  Map<String, dynamic> patch,
) {
  final requestedType = _string(patch, 'type');
  final currentType = _wireType(existing);
  if (requestedType != null && requestedType != currentType) {
    throw DiagramSpecException(
      "Cannot change an element's type (id ${existing.id}): it is a "
      '$currentType. Delete it and draw a new $requestedType instead.',
    );
  }

  switch (existing) {
    case SketchRectangle():
      return existing.copyWith(
        rect: _patchedRect(existing.rect, patch),
        style: _patchedStyle(existing.style, patch, allowFill: true),
        text: _patchedLabel(patch, existing.text),
        fontSize: _fontSizeOr(patch, existing.fontSize),
      );
    case SketchEllipse():
      return existing.copyWith(
        rect: _patchedRect(existing.rect, patch),
        style: _patchedStyle(existing.style, patch, allowFill: true),
        text: _patchedLabel(patch, existing.text),
        fontSize: _fontSizeOr(patch, existing.fontSize),
      );
    case SketchDiamond():
      return existing.copyWith(
        rect: _patchedRect(existing.rect, patch),
        style: _patchedStyle(existing.style, patch, allowFill: true),
        text: _patchedLabel(patch, existing.text),
        fontSize: _fontSizeOr(patch, existing.fontSize),
      );
    case SketchTriangle():
      return existing.copyWith(
        rect: _patchedRect(existing.rect, patch),
        style: _patchedStyle(existing.style, patch, allowFill: true),
        text: _patchedLabel(patch, existing.text),
        fontSize: _fontSizeOr(patch, existing.fontSize),
      );
    case SketchSticky():
      return existing.copyWith(
        rect: _patchedRect(existing.rect, patch),
        style: _patchedStyle(existing.style, patch, allowFill: true),
        text: _patchedLabel(patch, existing.text),
        fontSize: _fontSizeOr(patch, existing.fontSize),
      );
    case SketchText():
      // A `SketchText` *is* its text — emptying it would leave nothing to
      // draw, the same reason committing an empty text edit deletes it. So
      // an empty `text` here is refused with a message pointing at the tool
      // that is actually meant for it, rather than silently dropping the
      // element out from under an update.
      final label = patch.containsKey('text')
          ? _string(patch, 'text')
          : existing.text;
      if (label == null || label.isEmpty) {
        throw DiagramSpecException(
          'A text element (id ${existing.id}) cannot be emptied — its text is '
          'all it is. Use flowcraft_delete to remove it instead.',
        );
      }
      _checkTextLength(label);
      final b = existing.unrotatedBounds;
      return existing.copyWith(
        position: Offset(
          _number(patch, 'x', b.left),
          _number(patch, 'y', b.top),
        ),
        text: label,
        fontSize: _fontSizeOr(patch, existing.fontSize),
        style: _patchedStyle(existing.style, patch, allowFill: false),
      );
    case SketchLine():
      return existing.copyWith(
        start: Offset(
          _number(patch, 'fromX', existing.start.dx),
          _number(patch, 'fromY', existing.start.dy),
        ),
        end: Offset(
          _number(patch, 'toX', existing.end.dx),
          _number(patch, 'toY', existing.end.dy),
        ),
        style: _patchedStyle(existing.style, patch, allowFill: false),
      );
    case SketchArrow():
      return existing.copyWith(
        start: Offset(
          _number(patch, 'fromX', existing.start.dx),
          _number(patch, 'fromY', existing.start.dy),
        ),
        end: Offset(
          _number(patch, 'toX', existing.end.dx),
          _number(patch, 'toY', existing.end.dy),
        ),
        style: _patchedStyle(existing.style, patch, allowFill: false),
      );
    case SketchFreedraw():
      // Freedraw geometry is a raw point list, which the draw/update
      // vocabulary has no field for. Rather than accept and silently ignore
      // an `x`/`width`/`fromX`/… the agent clearly meant to take effect,
      // refuse it and say so; only a recolour is honoured.
      for (final key in const [
        'x',
        'y',
        'width',
        'height',
        'fromX',
        'fromY',
        'toX',
        'toY',
        'text',
        'fontSize',
      ]) {
        if (patch.containsKey(key)) {
          throw DiagramSpecException(
            'A freedraw stroke (id ${existing.id}) can only be recoloured via '
            "MCP; its geometry isn't editable. Delete it and draw a "
            'replacement if you need a different shape.',
          );
        }
      }
      return existing.copyWith(
        style: _patchedStyle(existing.style, patch, allowFill: false),
      );
  }
}

/// The wire `type` string [SketchElement.fromJson] switches on, for [el].
String _wireType(SketchElement el) => switch (el) {
  SketchRectangle() => 'rectangle',
  SketchEllipse() => 'ellipse',
  SketchDiamond() => 'diamond',
  SketchTriangle() => 'triangle',
  SketchSticky() => 'sticky',
  SketchLine() => 'line',
  SketchArrow() => 'arrow',
  SketchText() => 'text',
  SketchFreedraw() => 'freedraw',
};

/// [current] with any of `x`/`y`/`width`/`height` present in [patch] applied,
/// each validated exactly as the draw path validates it.
Rect _patchedRect(Rect current, Map<String, dynamic> patch) => Rect.fromLTWH(
  _number(patch, 'x', current.left),
  _number(patch, 'y', current.top),
  _dimension(patch, 'width', current.width),
  _dimension(patch, 'height', current.height),
);

/// [current] style with `strokeColor` and (when [allowFill]) `fillColor`
/// overridden where [patch] names them, keeping every other style field.
///
/// A missing colour leaves the current one; an explicit empty `fillColor`
/// clears the fill, mirroring how the draw path reads an empty colour.
SketchStyle _patchedStyle(
  SketchStyle current,
  Map<String, dynamic> patch, {
  required bool allowFill,
}) {
  var style = current;
  final stroke = _color(patch['strokeColor']);
  if (stroke != null) style = style.copyWith(strokeColor: stroke);
  if (allowFill && patch.containsKey('fillColor')) {
    style = style.copyWith(fillColor: _color(patch['fillColor']));
  }
  return style;
}

/// The label a bounded shape carries after [patch]: the current one when
/// `text` is absent, `null` (cleared) when it is an empty string, otherwise
/// the new value — length-checked like the draw path.
String? _patchedLabel(Map<String, dynamic> patch, String? current) {
  if (!patch.containsKey('text')) return current;
  final text = _string(patch, 'text');
  if (text == null || text.isEmpty) return null;
  _checkTextLength(text);
  return text;
}

void _checkTextLength(String text) {
  if (text.length > maxDiagramTextLength) {
    throw DiagramSpecException(
      '"text" is too long: ${text.length} characters (max '
      '$maxDiagramTextLength). Split it across several elements.',
    );
  }
}
