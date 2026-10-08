import 'dart:convert';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flowcraft/models/icon_catalog.dart';
import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/models/sketch_style.dart';

// The caps now live in the model (a loaded file obeys them too); re-exported
// so MCP-side callers keep importing them from here.
export 'package:flowcraft/models/sketch_element.dart'
    show maxDiagramTextLength, maxEntityAttributes;

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

/// Hex colour as the schema documents it: `RRGGBB` or `AARRGGBB`, with an
/// optional leading `#`. Anything else — a sign, three-digit shorthand, a
/// named colour — is refused rather than guessed at, because `int.tryParse`
/// accepted `"#-1"` and `"#FFF"` became a nearly transparent black.
final RegExp _hexColor = RegExp(r'^#?[0-9a-fA-F]{6}([0-9a-fA-F]{2})?$');

/// Parses a draw payload. [bindableIds] are the ids of elements an arrow's
/// `fromId`/`toId` may attach to; the default (none) refuses any binding,
/// which is what the legacy REST `/draw` wants. [entities] are the canvas's
/// existing entities by id, so `fromAttribute`/`toAttribute` can be checked
/// against real rows.
///
/// Frames are stable-partitioned to the front of the result: the canvas
/// stacks in list order, and a frame has to land *behind* what it contains.
/// Images arrive already resolved to `mimeType` + base64 `data` (see
/// `ImageSource.resolve`); their bytes are counted across the batch against
/// [maxSceneImageBytes].
List<SketchElement> parseDiagramElements(
  List<dynamic> raw, {
  Set<String> bindableIds = const {},
  Map<String, SketchEntity> entities = const {},
}) {
  if (raw.length > maxDiagramElements) {
    throw DiagramSpecException(
      'Too many elements: ${raw.length}. At most $maxDiagramElements can be '
      'drawn per call — split the diagram across several calls.',
    );
  }
  final imageBytes = _ImageBudget();
  final parsed = [
    for (final entry in raw)
      _parseOne(entry, bindableIds, entities, imageBytes),
  ];
  return [
    ...parsed.whereType<SketchFrame>(),
    ...parsed.where((e) => e is! SketchFrame),
  ];
}

/// Running total of image bytes in one batch.
class _ImageBudget {
  int total = 0;
}

SketchElement _parseOne(
  dynamic entry,
  Set<String> bindableIds,
  Map<String, SketchEntity> entities,
  _ImageBudget images,
) {
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
  _refuseForeignKeys(map, type, 'a "$type"');
  final family = _fontFamily(map, null);
  final bold = _bool(map, 'bold');

  switch (type) {
    case 'rectangle':
      return SketchRectangle.create(
        rect: _rect(map),
        style: style,
        text: text,
        fontSize: fontSize,
      ).copyWith(fontFamily: family, bold: bold);
    case 'ellipse':
      return SketchEllipse.create(
        rect: _rect(map),
        style: style,
        text: text,
        fontSize: fontSize,
      ).copyWith(fontFamily: family, bold: bold);
    case 'diamond':
      return SketchDiamond.create(
        rect: _rect(map),
        style: style,
        text: text,
        fontSize: fontSize,
      ).copyWith(fontFamily: family, bold: bold);
    case 'triangle':
      return SketchTriangle.create(
        rect: _rect(map),
        style: style,
        text: text,
        fontSize: fontSize,
      ).copyWith(fontFamily: family, bold: bold);
    case 'sticky':
      return SketchSticky.create(
        rect: _rect(map),
        style: map['strokeColor'] == null && map['fillColor'] == null
            ? null
            : style,
        text: text,
        fontSize: fontSize,
      ).copyWith(fontFamily: family, bold: bold);
    case 'text':
      if (text == null) {
        throw DiagramSpecException('A "text" element needs a "text" field.');
      }
      return SketchText.create(
        position: Offset(_number(map, 'x', 0), _number(map, 'y', 0)),
        text: text,
        fontSize: fontSize,
        fontFamily: family,
        bold: bold ?? false,
        align: _align(map) ?? TextAlign.start,
        style: style,
      );
    case 'frame':
      final frameName = _string(map, 'name') ?? '';
      _checkTextLength(frameName);
      return SketchFrame.create(
        rect: _rect(map),
        name: frameName,
        style: style,
      );
    case 'icon':
      final name = _string(map, 'name');
      if (name == null || !iconCatalog.containsKey(name)) {
        throw DiagramSpecException(
          'Unknown icon "${name ?? ''}". Valid names: '
          '${iconCatalog.keys.join(', ')}.',
        );
      }
      return SketchIcon.create(
        rect: Rect.fromLTWH(
          _number(map, 'x', 0),
          _number(map, 'y', 0),
          _dimension(map, 'width', 64),
          _dimension(map, 'height', 64),
        ),
        name: name,
        style: style,
      );
    case 'image':
      return _parseImage(map, style, images);
    case 'entity':
      final name = _string(map, 'name');
      if (name == null || name.isEmpty) {
        throw DiagramSpecException('An "entity" needs a non-empty "name".');
      }
      _checkTextLength(name);
      return SketchEntity.create(
        rect: Rect.fromLTWH(
          _number(map, 'x', 0),
          _number(map, 'y', 0),
          _dimension(map, 'width', 200),
          0,
        ),
        name: name,
        attributes: _attributes(map['attributes']),
        fontSize: _fontSizeOr(map, SketchEntity.defaultFontSize),
        style: style,
      );
    case 'arrow':
      final fromId = _bindingId(map, 'fromId', bindableIds);
      final toId = _bindingId(map, 'toId', bindableIds);
      _refuseSelfLoop(fromId, toId);
      final fromAttr = _attributeFor(
        map,
        'fromAttribute',
        'fromId',
        fromId,
        entities,
      );
      final toAttr = _attributeFor(map, 'toAttribute', 'toId', toId, entities);
      final end = _offset(map, 'toX', 'toY');
      // A bound end's coordinates are only a placeholder — the controller
      // snaps the tip onto the shape's outline — so a missing one borrows the
      // other end instead of landing on (0, 0).
      final start = fromId != null && map['fromX'] == null
          ? end
          : _offset(map, 'fromX', 'fromY');
      return SketchArrow.create(
        start: start,
        end: toId != null && map['toX'] == null ? start : end,
        style: style,
        elbowed: _bool(map, 'elbow') ?? false,
        startHead: _head(map, 'startHead', ArrowheadStyle.none),
        endHead: _head(map, 'endHead', ArrowheadStyle.arrow),
      ).copyWith(
        startBinding: fromId == null
            ? null
            : SketchBinding(elementId: fromId, attribute: fromAttr),
        endBinding: toId == null
            ? null
            : SketchBinding(elementId: toId, attribute: toAttr),
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

/// Keys that only mean something on one kind of element. Anywhere else they
/// are a mistake worth naming rather than silently dropping.
const _arrowOnlyKeys = [
  'fromId',
  'toId',
  'elbow',
  'startHead',
  'endHead',
  'fromAttribute',
  'toAttribute',
];

void _refuseForeignKeys(Map<String, dynamic> map, String type, String what) {
  void refuse(List<String> keys, String onlyFor) {
    for (final key in keys) {
      if (map[key] != null) {
        throw DiagramSpecException(
          '"$key" only applies to $onlyFor, not $what.',
        );
      }
    }
  }

  if (type != 'arrow') refuse(_arrowOnlyKeys, 'arrows');
  if (type != 'text') refuse(const ['align'], 'text elements');
  if (!_labelled.contains(type) && type != 'text') {
    refuse(const ['fontFamily', 'bold'], 'text and labelled shapes');
  }
}

/// Types whose label takes `fontFamily`/`bold` (text is handled beside them).
const _labelled = {'rectangle', 'ellipse', 'diamond', 'triangle', 'sticky'};

/// Reads an arrow's `fromId`/`toId`: `null` when absent or `""` (no binding),
/// otherwise an id that must be in [bindableIds].
String? _bindingId(
  Map<String, dynamic> map,
  String key,
  Set<String> bindableIds,
) {
  final id = _string(map, key);
  if (id == null || id.isEmpty) return null;
  if (!bindableIds.contains(id)) {
    throw DiagramSpecException(
      '"$key" refers to "$id", which is not a shape on the canvas an arrow '
      'can attach to (rectangle, ellipse, diamond, triangle or sticky that '
      'already exists). Get ids from flowcraft_read, or use flowcraft_diagram '
      'to draw shapes and their arrows together.',
    );
  }
  return id;
}

void _refuseSelfLoop(String? fromId, String? toId) {
  if (fromId != null && fromId == toId) {
    throw DiagramSpecException(
      '"fromId" and "toId" are the same shape ("$fromId"); an arrow must '
      'connect two different shapes.',
    );
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

/// Reads a boolean field, or `null` when absent.
bool? _bool(Map<String, dynamic> map, String key) {
  final raw = map[key];
  if (raw == null) return null;
  if (raw is! bool) {
    throw DiagramSpecException('"$key" must be true or false, got: $raw');
  }
  return raw;
}

/// `fontFamily`: `sans` or `mono`, [current] when absent. There is no
/// hand-drawn face bundled, so anything else is refused rather than falling
/// back silently to the platform default.
String? _fontFamily(Map<String, dynamic> map, String? current) {
  final raw = _string(map, 'fontFamily');
  if (raw == null) return current;
  if (raw != 'sans' && raw != 'mono') {
    throw DiagramSpecException(
      'Unknown fontFamily "$raw". Use "sans" or "mono".',
    );
  }
  return raw;
}

const _aligns = {
  'left': TextAlign.left,
  'center': TextAlign.center,
  'right': TextAlign.right,
};

TextAlign? _align(Map<String, dynamic> map) {
  final raw = _string(map, 'align');
  if (raw == null) return null;
  return _aligns[raw] ??
      (throw DiagramSpecException(
        'Unknown align "$raw". Use left, center or right.',
      ));
}

/// An [ArrowheadStyle] by name, [fallback] when the key is absent.
ArrowheadStyle _head(
  Map<String, dynamic> map,
  String key,
  ArrowheadStyle fallback,
) {
  final raw = _string(map, key);
  if (raw == null) return fallback;
  for (final style in ArrowheadStyle.values) {
    if (style.name == raw) return style;
  }
  throw DiagramSpecException(
    'Unknown $key "$raw". Use one of '
    '${ArrowheadStyle.values.map((s) => s.name).join(', ')}.',
  );
}

/// An arrow end's entity row: `null` when [attrKey] is absent or `""`,
/// otherwise it needs a bound end ([id], from [idKey]) that is an entity in
/// [entities] with a row of that name.
String? _attributeFor(
  Map<String, dynamic> map,
  String attrKey,
  String idKey,
  String? id,
  Map<String, SketchEntity> entities,
) {
  final attr = _string(map, attrKey);
  if (attr == null || attr.isEmpty) return null;
  if (id == null) {
    throw DiagramSpecException(
      '"$attrKey" needs "$idKey" naming the entity the row belongs to.',
    );
  }
  final entity = entities[id];
  if (entity == null) {
    throw DiagramSpecException(
      '"$attrKey" refers to a row of "$id", which is not an entity.',
    );
  }
  if (!entity.attributes.any((a) => a.name == attr)) {
    throw DiagramSpecException(
      'Entity "${entity.name}" has no attribute "$attr". Its attributes: '
      '${entity.attributes.map((a) => a.name).join(', ')}.',
    );
  }
  return attr;
}

/// Entity rows: `[{name, type?, pk?, fk?}]` with unique, non-empty names
/// (a row is addressed by name when an arrow binds to it).
List<EntityAttribute> _attributes(Object? raw) {
  if (raw == null) return const [];
  if (raw is! List) {
    throw DiagramSpecException('"attributes" must be a list, got: $raw');
  }
  if (raw.length > maxEntityAttributes) {
    throw DiagramSpecException(
      'Too many attributes: ${raw.length} (max $maxEntityAttributes).',
    );
  }
  final seen = <String>{};
  final rows = <EntityAttribute>[];
  for (final row in raw) {
    if (row is! Map) {
      throw DiagramSpecException('An attribute must be an object, got: $row');
    }
    final m = row.cast<String, dynamic>();
    final name = _string(m, 'name');
    if (name == null || name.isEmpty) {
      throw DiagramSpecException('Every attribute needs a non-empty "name".');
    }
    if (!seen.add(name)) {
      throw DiagramSpecException('Duplicate attribute "$name".');
    }
    final type = _string(m, 'type') ?? '';
    _checkTextLength(name);
    _checkTextLength(type);
    rows.add(
      EntityAttribute(
        name: name,
        type: type,
        primaryKey: _bool(m, 'pk') ?? false,
        foreignKey: _bool(m, 'fk') ?? false,
      ),
    );
  }
  return rows;
}

/// An image whose bytes are already resolved (`mimeType` + base64 `data`).
/// Enforces the mime allow-list, the per-image cap and the batch's running
/// total — this is the trust boundary for anything an agent embeds.
SketchImage _parseImage(
  Map<String, dynamic> map,
  SketchStyle style,
  _ImageBudget budget,
) {
  final mime = _string(map, 'mimeType');
  if (mime == null || !imageMimeTypes.contains(mime)) {
    throw DiagramSpecException(
      'Unsupported image mimeType "${mime ?? ''}". Use one of '
      '${imageMimeTypes.join(', ')}.',
    );
  }
  final data = _string(map, 'data');
  if (data == null || data.isEmpty) {
    throw DiagramSpecException(
      'An "image" needs base64 "data" (or a "path"/"dataUrl", which the '
      'server resolves before parsing).',
    );
  }
  if (map['width'] == null || map['height'] == null) {
    throw DiagramSpecException('An "image" needs "width" and "height".');
  }
  // Cheap check before decoding: base64 inflates by 4/3.
  if (data.length > maxImageBytes * 4 ~/ 3 + 4) {
    throw DiagramSpecException(
      'Image is larger than the ${maxImageBytes ~/ (1024 * 1024)} MiB limit.',
    );
  }
  final Uint8List bytes;
  try {
    bytes = base64Decode(data);
  } on FormatException {
    throw DiagramSpecException('Image "data" is not valid base64.');
  }
  if (bytes.isEmpty || bytes.length > maxImageBytes) {
    throw DiagramSpecException(
      'Image is empty or larger than the ${maxImageBytes ~/ (1024 * 1024)} MiB '
      'limit.',
    );
  }
  budget.total += bytes.length;
  if (budget.total > maxSceneImageBytes) {
    throw DiagramSpecException(
      'Images in this call add up to more than the '
      '${maxSceneImageBytes ~/ (1024 * 1024)} MiB limit.',
    );
  }
  return SketchImage.create(
    rect: _rect(map),
    mimeType: mime,
    bytes: bytes,
    style: style,
  );
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
      return _describeBounded(
        el,
        'rectangle',
        el.text,
        el.fontSize,
        fontFamily: el.fontFamily,
        bold: el.bold,
      );
    case SketchEllipse():
      return _describeBounded(
        el,
        'ellipse',
        el.text,
        el.fontSize,
        fontFamily: el.fontFamily,
        bold: el.bold,
      );
    case SketchDiamond():
      return _describeBounded(
        el,
        'diamond',
        el.text,
        el.fontSize,
        fontFamily: el.fontFamily,
        bold: el.bold,
      );
    case SketchTriangle():
      return _describeBounded(
        el,
        'triangle',
        el.text,
        el.fontSize,
        fontFamily: el.fontFamily,
        bold: el.bold,
      );
    case SketchSticky():
      return _describeBounded(
        el,
        'sticky',
        el.text,
        el.fontSize,
        fontFamily: el.fontFamily,
        bold: el.bold,
      );
    case SketchText():
      final b = el.unrotatedBounds;
      return {
        'id': el.id,
        'type': 'text',
        'x': b.left,
        'y': b.top,
        'text': el.text,
        'fontSize': el.fontSize,
        'fontFamily': ?el.fontFamily,
        if (el.bold) 'bold': true,
        if (el.align != TextAlign.start) 'align': el.align.name,
        'strokeColor': _hex(el.style.strokeColor),
      };
    case SketchLine():
      return _describeLinear(el, 'line', el.start, el.end);
    case SketchArrow():
      return {
        ..._describeLinear(el, 'arrow', el.start, el.end),
        'fromId': ?el.startBinding?.elementId,
        'toId': ?el.endBinding?.elementId,
        'fromAttribute': ?el.startBinding?.attribute,
        'toAttribute': ?el.endBinding?.attribute,
        if (el.elbowed) 'elbow': true,
        if (el.startHead != ArrowheadStyle.none) 'startHead': el.startHead.name,
        if (el.endHead != ArrowheadStyle.arrow) 'endHead': el.endHead.name,
      };
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
    case SketchFrame():
      return {..._describeBounded(el, 'frame', null, 0), 'name': el.name};
    case SketchIcon():
      return {..._describeBounded(el, 'icon', null, 0), 'name': el.name};
    case SketchImage():
      // Carries the bytes so a read → draw round trip is lossless; the
      // 4 MiB per-image cap bounds what one element adds to a read.
      return {
        ..._describeBounded(el, 'image', null, 0),
        'mimeType': el.mimeType,
        'data': base64Encode(el.bytes),
      };
    case SketchEntity():
      return {
        ..._describeBounded(el, 'entity', null, 0),
        'name': el.name,
        'attributes': [for (final a in el.attributes) a.toJson()],
        'fontSize': el.fontSize,
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
  double fontSize, {
  String? fontFamily,
  bool bold = false,
}) {
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
    'fontFamily': ?fontFamily,
    if (bold) 'bold': true,
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
///
/// For an arrow, `fromId`/`toId` (de)attach an end: an id binds it, `""`
/// detaches it, and absent leaves it — except that moving the end with
/// `fromX`/`fromY` (`toX`/`toY`) and no id detaches it, since an explicit
/// coordinate would otherwise be overwritten by the next re-anchor.
SketchElement applyDiagramPatch(
  SketchElement existing,
  Map<String, dynamic> patch, {
  Set<String> bindableIds = const {},
  Map<String, SketchEntity> entities = const {},
}) {
  final requestedType = _string(patch, 'type');
  final currentType = _wireType(existing);
  if (requestedType != null && requestedType != currentType) {
    throw DiagramSpecException(
      "Cannot change an element's type (id ${existing.id}): it is a "
      '$currentType. Delete it and draw a new $requestedType instead.',
    );
  }

  _refuseForeignKeys(patch, currentType, 'a $currentType (id ${existing.id})');

  switch (existing) {
    case SketchFrame():
      final frameName = _string(patch, 'name') ?? existing.name;
      _checkTextLength(frameName);
      return existing.copyWith(
        rect: _patchedRect(existing.rect, patch),
        style: _patchedStyle(existing.style, patch, allowFill: true),
        name: frameName,
      );
    case SketchIcon():
      final name = _string(patch, 'name') ?? existing.name;
      if (!iconCatalog.containsKey(name)) {
        throw DiagramSpecException(
          'Unknown icon "$name". Valid names: ${iconCatalog.keys.join(', ')}.',
        );
      }
      return existing.copyWith(
        rect: _patchedRect(existing.rect, patch),
        style: _patchedStyle(existing.style, patch, allowFill: false),
        name: name,
      );
    case SketchImage():
      // Pixels are fixed once drawn; `describe` echoes them back, so the
      // same bytes are fine, different ones are not.
      for (final key in const ['path', 'dataUrl']) {
        if (patch[key] != null) {
          throw DiagramSpecException(
            'An image (id ${existing.id}) cannot change its pixels. Delete '
            'it and draw a new one.',
          );
        }
      }
      if ((patch['mimeType'] ?? existing.mimeType) != existing.mimeType ||
          (patch['data'] ?? base64Encode(existing.bytes)) !=
              base64Encode(existing.bytes)) {
        throw DiagramSpecException(
          'An image (id ${existing.id}) cannot change its pixels. Delete it '
          'and draw a new one.',
        );
      }
      return existing.copyWith(
        rect: _patchedRect(existing.rect, patch),
        style: _patchedStyle(existing.style, patch, allowFill: false),
      );
    case SketchEntity():
      final name = patch.containsKey('name')
          ? _string(patch, 'name')
          : existing.name;
      if (name == null || name.isEmpty) {
        throw DiagramSpecException('An entity needs a non-empty "name".');
      }
      _checkTextLength(name);
      // Height is derived from the rows, so a `height` from `describe` is
      // accepted and ignored rather than fought.
      return existing
          .copyWith(
            rect: Rect.fromLTWH(
              _number(patch, 'x', existing.rect.left),
              _number(patch, 'y', existing.rect.top),
              _dimension(patch, 'width', existing.rect.width),
              existing.rect.height,
            ),
            name: name,
            attributes: patch.containsKey('attributes')
                ? _attributes(patch['attributes'])
                : existing.attributes,
            fontSize: _fontSizeOr(patch, existing.fontSize),
            style: _patchedStyle(existing.style, patch, allowFill: true),
          )
          .fittedToAttributes();
    case SketchRectangle():
      return existing.copyWith(
        rect: _patchedRect(existing.rect, patch),
        style: _patchedStyle(existing.style, patch, allowFill: true),
        text: _patchedLabel(patch, existing.text),
        fontSize: _fontSizeOr(patch, existing.fontSize),
        fontFamily: _fontFamily(patch, existing.fontFamily),
        bold: _bool(patch, 'bold') ?? existing.bold,
      );
    case SketchEllipse():
      return existing.copyWith(
        rect: _patchedRect(existing.rect, patch),
        style: _patchedStyle(existing.style, patch, allowFill: true),
        text: _patchedLabel(patch, existing.text),
        fontSize: _fontSizeOr(patch, existing.fontSize),
        fontFamily: _fontFamily(patch, existing.fontFamily),
        bold: _bool(patch, 'bold') ?? existing.bold,
      );
    case SketchDiamond():
      return existing.copyWith(
        rect: _patchedRect(existing.rect, patch),
        style: _patchedStyle(existing.style, patch, allowFill: true),
        text: _patchedLabel(patch, existing.text),
        fontSize: _fontSizeOr(patch, existing.fontSize),
        fontFamily: _fontFamily(patch, existing.fontFamily),
        bold: _bool(patch, 'bold') ?? existing.bold,
      );
    case SketchTriangle():
      return existing.copyWith(
        rect: _patchedRect(existing.rect, patch),
        style: _patchedStyle(existing.style, patch, allowFill: true),
        text: _patchedLabel(patch, existing.text),
        fontSize: _fontSizeOr(patch, existing.fontSize),
        fontFamily: _fontFamily(patch, existing.fontFamily),
        bold: _bool(patch, 'bold') ?? existing.bold,
      );
    case SketchSticky():
      return existing.copyWith(
        rect: _patchedRect(existing.rect, patch),
        style: _patchedStyle(existing.style, patch, allowFill: true),
        text: _patchedLabel(patch, existing.text),
        fontSize: _fontSizeOr(patch, existing.fontSize),
        fontFamily: _fontFamily(patch, existing.fontFamily),
        bold: _bool(patch, 'bold') ?? existing.bold,
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
        fontFamily: _fontFamily(patch, existing.fontFamily),
        bold: _bool(patch, 'bold') ?? existing.bold,
        align: _align(patch) ?? existing.align,
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
      final start = _patchedBinding(
        patch,
        'fromId',
        'fromX',
        'fromY',
        existing.startBinding,
        bindableIds,
        entities,
        'fromAttribute',
      );
      final end = _patchedBinding(
        patch,
        'toId',
        'toX',
        'toY',
        existing.endBinding,
        bindableIds,
        entities,
        'toAttribute',
      );
      _refuseSelfLoop(start?.elementId, end?.elementId);
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
        elbowed: _bool(patch, 'elbow') ?? existing.elbowed,
        startHead: _head(patch, 'startHead', existing.startHead),
        endHead: _head(patch, 'endHead', existing.endHead),
        startBinding: start,
        endBinding: end,
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

/// One arrow end's binding after [patch]: the id key wins (bind or `""`
/// detach), else a coordinate key detaches, else [current] is kept.
SketchBinding? _patchedBinding(
  Map<String, dynamic> patch,
  String idKey,
  String xKey,
  String yKey,
  SketchBinding? current,
  Set<String> bindableIds,
  Map<String, SketchEntity> entities,
  String attrKey,
) {
  SketchBinding? binding;
  if (patch[idKey] != null) {
    final id = _bindingId(patch, idKey, bindableIds);
    // `describe` re-emits the id (and row); re-sending what is already bound
    // must not rebuild the binding and lose its focus/gap/row.
    if (id != null &&
        id == current?.elementId &&
        (patch[attrKey] == null || patch[attrKey] == current?.attribute)) {
      return current;
    }
    binding = id == null
        ? null
        : SketchBinding(
            elementId: id,
            attribute: _attributeFor(patch, attrKey, idKey, id, entities),
          );
  } else if (patch[xKey] != null || patch[yKey] != null) {
    binding = null;
  } else {
    binding = current;
  }
  // A row named without any bound end is a mistake, not a no-op; a row
  // named for the kept binding re-targets just the row.
  if (patch[attrKey] != null && patch[idKey] == null) {
    if (binding == null) {
      _attributeFor(patch, attrKey, idKey, null, entities); // throws unless ""
      return null;
    }
    final attr = _attributeFor(
      patch,
      attrKey,
      idKey,
      binding.elementId,
      entities,
    );
    return SketchBinding(
      elementId: binding.elementId,
      focus: binding.focus,
      gap: binding.gap,
      attribute: attr,
    );
  }
  return binding;
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
  SketchFrame() => 'frame',
  SketchIcon() => 'icon',
  SketchImage() => 'image',
  SketchEntity() => 'entity',
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
