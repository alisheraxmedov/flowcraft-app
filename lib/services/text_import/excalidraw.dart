import 'dart:convert';
import 'dart:ui';

import 'package:flowcraft/core/utils/id_generator.dart';
import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/models/sketch_style.dart';

import '../diagram_spec.dart';

const _shapes = {'rectangle', 'ellipse', 'diamond'};

double? _num(Object? v) => v is num && v.isFinite ? v.toDouble() : null;

/// `#RRGGBB` / `#RRGGBBAA`; anything else (`transparent`, names) is no colour.
Color? _color(Object? v) {
  final m = v is String
      ? RegExp(r'^#([0-9a-fA-F]{6})([0-9a-fA-F]{2})?$').firstMatch(v)
      : null;
  if (m == null) return null;
  final rgb = int.parse(m.group(1)!, radix: 16);
  final a = m.group(2) == null ? 0xFF : int.parse(m.group(2)!, radix: 16);
  return Color((a << 24) | rgb);
}

SketchStyle _style(Map e) {
  var s = const SketchStyle();
  final stroke = _color(e['strokeColor']);
  if (stroke != null) s = s.copyWith(strokeColor: stroke);
  final fill = _color(e['backgroundColor']);
  if (fill != null) {
    s = s.withFillColor(fill);
    final fs = switch (e['fillStyle']) {
      'hachure' => FillStyle.hachure,
      'cross-hatch' => FillStyle.crossHatch,
      _ => null,
    };
    if (fs != null) s = s.copyWith(fillStyle: fs);
  }
  final w = _num(e['strokeWidth']);
  final o = _num(e['opacity']); // Excalidraw: 0..100
  final r = _num(e['roughness']);
  return s.copyWith(
    strokeWidth: w?.clamp(
      SketchStyle.minStrokeWidth,
      SketchStyle.maxStrokeWidth,
    ),
    opacity: o == null ? null : (o / 100).clamp(0.0, 1.0),
    roughness: r?.clamp(0.0, SketchStyle.maxRoughness),
    strokeStyle: switch (e['strokeStyle']) {
      'dashed' => StrokeStyle.dashed,
      'dotted' => StrokeStyle.dotted,
      _ => null,
    },
  );
}

/// Imports an Excalidraw scene (the `.excalidraw` JSON) as FlowCraft
/// elements. Supports rectangle, ellipse, diamond, arrow, line, text and
/// freedraw; text bound to a shape becomes its label and arrow endpoints
/// stay bound to the (re-id'd) shapes. Everything else — images, frames,
/// embeds, labels on arrows, unreadable elements — is skipped and counted
/// in `dropped`. Deleted elements are ignored without counting.
///
/// ponytail: arrows/lines with more than two points keep only the chord
/// from first to last point; the model has no polylines. Fonts, rotation and
/// corner roundness are not mapped.
({List<SketchElement> elements, int dropped}) parseExcalidraw(String text) {
  final Object? root;
  try {
    root = jsonDecode(text);
  } on FormatException catch (e) {
    throw DiagramSpecException('Not valid JSON: ${e.message}');
  }
  final raw = root is Map ? root['elements'] : null;
  if (raw is! List) {
    throw DiagramSpecException('Excalidraw scene needs an "elements" list.');
  }
  if (raw.length > maxDiagramElements) {
    throw DiagramSpecException(
      'Too many elements: ${raw.length}. At most $maxDiagramElements can be '
      'imported at once.',
    );
  }

  final live = [
    for (final e in raw)
      if (e is Map && e['isDeleted'] != true) e,
  ];
  var dropped = raw.where((e) => e is! Map).length;
  final used = <String>{};
  String fresh() {
    String id;
    do {
      id = IdGenerator.generate('sketch');
    } while (!used.add(id));
    return id;
  }

  // Pass 1: ids for shapes (arrow bindings target these) + text containers.
  final ids = <Object?, String>{};
  for (final e in live) {
    if (_shapes.contains(e['type'])) ids[e['id']] = fresh();
  }
  final labels = <Object?, Map>{};
  for (final e in live) {
    if (e['type'] == 'text' && ids.containsKey(e['containerId'])) {
      labels[e['containerId']] = e;
    }
  }

  SketchBinding? bind(Object? b) {
    final target = b is Map ? ids[b['elementId']] : null;
    if (target == null) return null;
    return SketchBinding(
      elementId: target,
      focus: (_num((b as Map)['focus']) ?? 0).clamp(-1.0, 1.0),
      gap: (_num(b['gap']) ?? 0).clamp(0.0, 1000.0),
    );
  }

  final out = <SketchElement>[];
  for (final e in live) {
    final type = e['type'];
    final x = _num(e['x']), y = _num(e['y']);
    final w = _num(e['width']) ?? 0, h = _num(e['height']) ?? 0;
    if (x == null || y == null) {
      dropped++;
      continue;
    }
    final style = _style(e);
    if (_shapes.contains(type)) {
      final rect = Rect.fromLTWH(x, y, w.abs(), h.abs());
      final label = labels[e['id']];
      final lt = label?['text'];
      final txt = lt is String && lt.isNotEmpty ? _checkedText(lt) : null;
      final fs =
          _num(label?['fontSize'])?.clamp(1.0, maxDiagramFontSize) ?? 16.0;
      final id = ids[e['id']]!;
      out.add(switch (type) {
        'rectangle' => SketchRectangle.create(
          id: id,
          rect: rect,
          style: style,
          text: txt,
          fontSize: fs,
        ),
        'ellipse' => SketchEllipse.create(
          id: id,
          rect: rect,
          style: style,
          text: txt,
          fontSize: fs,
        ),
        _ => SketchDiamond.create(
          id: id,
          rect: rect,
          style: style,
          text: txt,
          fontSize: fs,
        ),
      });
    } else if (type == 'arrow' || type == 'line') {
      final pts = e['points'];
      final p0 = pts is List && pts.length >= 2 ? _point(pts.first) : null;
      final p1 = pts is List && pts.length >= 2 ? _point(pts.last) : null;
      if (p0 == null || p1 == null) {
        dropped++;
        continue;
      }
      final start = Offset(x + p0.dx, y + p0.dy),
          end = Offset(x + p1.dx, y + p1.dy);
      out.add(
        type == 'line'
            ? SketchLine.create(
                id: fresh(),
                start: start,
                end: end,
                style: style,
              )
            : SketchArrow.create(
                id: fresh(),
                start: start,
                end: end,
                style: style,
              ).copyWith(
                startBinding: bind(e['startBinding']),
                endBinding: bind(e['endBinding']),
              ),
      );
    } else if (type == 'text') {
      final t = e['text'];
      if (labels[e['containerId']] == e) continue; // consumed as a label
      // A label on an arrow (or on something dropped) has no slot.
      if (t is! String || t.isEmpty || e['containerId'] != null) {
        dropped++;
        continue;
      }
      out.add(
        SketchText.create(
          id: fresh(),
          position: Offset(x, y),
          text: _checkedText(t),
          fontSize: _num(e['fontSize'])?.clamp(1.0, maxDiagramFontSize) ?? 16.0,
          style: style,
        ),
      );
    } else if (type == 'freedraw') {
      final pts = e['points'];
      final abs = pts is List
          ? [
              for (final p in pts)
                if (_point(p) case final o?) Offset(x + o.dx, y + o.dy),
            ]
          : <Offset>[];
      if (abs.isEmpty) {
        dropped++;
        continue;
      }
      out.add(SketchFreedraw.create(id: fresh(), points: abs, style: style));
    } else {
      dropped++;
    }
  }
  return (elements: out, dropped: dropped);
}

Offset? _point(Object? p) {
  if (p is! List || p.length < 2) return null;
  final a = _num(p[0]), b = _num(p[1]);
  return a == null || b == null ? null : Offset(a, b);
}

String _checkedText(String t) {
  if (t.length > maxDiagramTextLength) {
    throw DiagramSpecException(
      'Text is too long: ${t.length} characters (max $maxDiagramTextLength).',
    );
  }
  return t;
}
