import 'dart:math' as math;
import 'dart:ui';

import 'package:flowcraft/core/domain/text_metrics.dart';
import 'package:flowcraft/core/utils/id_generator.dart';
import 'package:flowcraft/models/sketch_style.dart';

/// Base for any drawable element on the sketch layer.
///
/// All elements are immutable value types. Mutating an element returns
/// a new instance via [copyWith] or a per-subclass helper.
///
/// Coordinates are in canvas-space (not screen-space).
sealed class SketchElement {
  const SketchElement({
    required this.id,
    required this.style,
    this.angle = 0.0,
    this.groupId,
  });

  final String id;
  final SketchStyle style;

  /// Rotation in radians, around the centre of [bounds].
  final double angle;

  /// Group this element belongs to, or `null` when it stands alone.
  ///
  /// Groups are flat — an element is in one group or none, and nesting is
  /// deliberately not modelled. Every transform below preserves it, because
  /// a group that dissolves the moment it is dragged is worse than no
  /// grouping at all.
  final String? groupId;

  /// Axis-aligned bounding box in canvas-space (ignoring rotation).
  Rect get bounds;

  SketchElement copyWithStyle(SketchStyle newStyle);
  SketchElement translate(Offset delta);

  /// Copy of this element under a different [id].
  ///
  /// [id] is `final`, so duplicate and paste need this to mint distinct
  /// elements: two elements sharing an id give selection, hit-testing and
  /// MCP addressing the same handle for both.
  SketchElement withId(String id);

  /// Copy of this element in group [groupId]; `null` ungroups it.
  SketchElement withGroupId(String? groupId);

  Map<String, dynamic> toJson();

  static SketchElement fromJson(Map<String, dynamic> json) {
    final type = json['type'] as String;
    switch (type) {
      case 'rectangle':
        return SketchRectangle.fromJson(json);
      case 'ellipse':
        return SketchEllipse.fromJson(json);
      case 'diamond':
        return SketchDiamond.fromJson(json);
      case 'triangle':
        return SketchTriangle.fromJson(json);
      case 'sticky':
        return SketchSticky.fromJson(json);
      case 'line':
        return SketchLine.fromJson(json);
      case 'arrow':
        return SketchArrow.fromJson(json);
      case 'freedraw':
        return SketchFreedraw.fromJson(json);
      case 'text':
        return SketchText.fromJson(json);
      default:
        throw StateError('Unknown sketch element type: $type');
    }
  }
}

// ─── Bounded shapes (rect/ellipse/diamond) ─────────────────────────────────

/// Shared base for shapes defined by an axis-aligned [Rect].
///
/// Bounded shapes can optionally carry a centred text label rendered on
/// top of their stroke. [text] is null for plain shapes; assign via the
/// per-subclass `copyWith(text: ...)`.
sealed class _SketchBoundedShape extends SketchElement {
  const _SketchBoundedShape({
    required super.id,
    required super.style,
    required this.rect,
    this.text,
    this.fontSize = 16.0,
    super.angle,
    super.groupId,
  });

  final Rect rect;
  final String? text;
  final double fontSize;

  @override
  Rect get bounds => rect;
}

class SketchRectangle extends _SketchBoundedShape {
  const SketchRectangle({
    required super.id,
    required super.style,
    required super.rect,
    super.text,
    super.fontSize,
    this.cornerRadius = 0.0,
    super.angle,
    super.groupId,
  });

  final double cornerRadius;

  SketchRectangle copyWith({
    String? id,
    Rect? rect,
    SketchStyle? style,
    double? cornerRadius,
    double? angle,
    Object? text = _unset,
    double? fontSize,
    Object? groupId = _unset,
  }) {
    return SketchRectangle(
      id: id ?? this.id,
      style: style ?? this.style,
      rect: rect ?? this.rect,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      angle: angle ?? this.angle,
      text: identical(text, _unset) ? this.text : text as String?,
      fontSize: fontSize ?? this.fontSize,
      groupId: identical(groupId, _unset) ? this.groupId : groupId as String?,
    );
  }

  @override
  SketchRectangle copyWithStyle(SketchStyle newStyle) =>
      copyWith(style: newStyle);

  @override
  SketchRectangle translate(Offset delta) =>
      copyWith(rect: rect.shift(delta));

  @override
  SketchRectangle withId(String id) => copyWith(id: id);

  @override
  SketchRectangle withGroupId(String? groupId) => copyWith(groupId: groupId);

  factory SketchRectangle.create({
    String? id,
    required Rect rect,
    SketchStyle style = const SketchStyle(),
    double cornerRadius = 0.0,
    String? text,
    double fontSize = 16.0,
  }) {
    return SketchRectangle(
      id: id ?? IdGenerator.generate('sketch'),
      style: style,
      rect: rect,
      cornerRadius: cornerRadius,
      text: text,
      fontSize: fontSize,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'rectangle',
        'id': id,
        'style': style.toJson(),
        'rect': _rectToJson(rect),
        'cornerRadius': cornerRadius,
        'angle': angle,
        if (text != null) 'text': text,
        'fontSize': fontSize,
        if (groupId != null) 'groupId': groupId,
      };

  factory SketchRectangle.fromJson(Map<String, dynamic> json) {
    return SketchRectangle(
      id: json['id'] as String,
      style: SketchStyle.fromJson(json['style'] as Map<String, dynamic>),
      rect: _rectFromJson(json['rect'] as Map<String, dynamic>),
      cornerRadius: (json['cornerRadius'] as num?)?.toDouble() ?? 0.0,
      angle: (json['angle'] as num?)?.toDouble() ?? 0.0,
      text: json['text'] as String?,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16.0,
      groupId: json['groupId'] as String?,
    );
  }
}

class SketchEllipse extends _SketchBoundedShape {
  const SketchEllipse({
    required super.id,
    required super.style,
    required super.rect,
    super.text,
    super.fontSize,
    super.angle,
    super.groupId,
  });

  SketchEllipse copyWith({
    String? id,
    Rect? rect,
    SketchStyle? style,
    double? angle,
    Object? text = _unset,
    double? fontSize,
    Object? groupId = _unset,
  }) {
    return SketchEllipse(
      id: id ?? this.id,
      style: style ?? this.style,
      rect: rect ?? this.rect,
      angle: angle ?? this.angle,
      text: identical(text, _unset) ? this.text : text as String?,
      fontSize: fontSize ?? this.fontSize,
      groupId: identical(groupId, _unset) ? this.groupId : groupId as String?,
    );
  }

  @override
  SketchEllipse copyWithStyle(SketchStyle newStyle) =>
      copyWith(style: newStyle);

  @override
  SketchEllipse translate(Offset delta) => copyWith(rect: rect.shift(delta));

  @override
  SketchEllipse withId(String id) => copyWith(id: id);

  @override
  SketchEllipse withGroupId(String? groupId) => copyWith(groupId: groupId);

  factory SketchEllipse.create({
    String? id,
    required Rect rect,
    SketchStyle style = const SketchStyle(),
    String? text,
    double fontSize = 16.0,
  }) {
    return SketchEllipse(
      id: id ?? IdGenerator.generate('sketch'),
      style: style,
      rect: rect,
      text: text,
      fontSize: fontSize,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'ellipse',
        'id': id,
        'style': style.toJson(),
        'rect': _rectToJson(rect),
        'angle': angle,
        if (text != null) 'text': text,
        'fontSize': fontSize,
        if (groupId != null) 'groupId': groupId,
      };

  factory SketchEllipse.fromJson(Map<String, dynamic> json) {
    return SketchEllipse(
      id: json['id'] as String,
      style: SketchStyle.fromJson(json['style'] as Map<String, dynamic>),
      rect: _rectFromJson(json['rect'] as Map<String, dynamic>),
      angle: (json['angle'] as num?)?.toDouble() ?? 0.0,
      text: json['text'] as String?,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16.0,
      groupId: json['groupId'] as String?,
    );
  }
}

class SketchDiamond extends _SketchBoundedShape {
  const SketchDiamond({
    required super.id,
    required super.style,
    required super.rect,
    super.text,
    super.fontSize,
    super.angle,
    super.groupId,
  });

  SketchDiamond copyWith({
    String? id,
    Rect? rect,
    SketchStyle? style,
    double? angle,
    Object? text = _unset,
    double? fontSize,
    Object? groupId = _unset,
  }) {
    return SketchDiamond(
      id: id ?? this.id,
      style: style ?? this.style,
      rect: rect ?? this.rect,
      angle: angle ?? this.angle,
      text: identical(text, _unset) ? this.text : text as String?,
      fontSize: fontSize ?? this.fontSize,
      groupId: identical(groupId, _unset) ? this.groupId : groupId as String?,
    );
  }

  @override
  SketchDiamond copyWithStyle(SketchStyle newStyle) =>
      copyWith(style: newStyle);

  @override
  SketchDiamond translate(Offset delta) => copyWith(rect: rect.shift(delta));

  @override
  SketchDiamond withId(String id) => copyWith(id: id);

  @override
  SketchDiamond withGroupId(String? groupId) => copyWith(groupId: groupId);

  factory SketchDiamond.create({
    String? id,
    required Rect rect,
    SketchStyle style = const SketchStyle(),
    String? text,
    double fontSize = 16.0,
  }) {
    return SketchDiamond(
      id: id ?? IdGenerator.generate('sketch'),
      style: style,
      rect: rect,
      text: text,
      fontSize: fontSize,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'diamond',
        'id': id,
        'style': style.toJson(),
        'rect': _rectToJson(rect),
        'angle': angle,
        if (text != null) 'text': text,
        'fontSize': fontSize,
        if (groupId != null) 'groupId': groupId,
      };

  factory SketchDiamond.fromJson(Map<String, dynamic> json) {
    return SketchDiamond(
      id: json['id'] as String,
      style: SketchStyle.fromJson(json['style'] as Map<String, dynamic>),
      rect: _rectFromJson(json['rect'] as Map<String, dynamic>),
      angle: (json['angle'] as num?)?.toDouble() ?? 0.0,
      text: json['text'] as String?,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16.0,
      groupId: json['groupId'] as String?,
    );
  }
}

class SketchTriangle extends _SketchBoundedShape {
  const SketchTriangle({
    required super.id,
    required super.style,
    required super.rect,
    super.text,
    super.fontSize,
    super.angle,
    super.groupId,
  });

  SketchTriangle copyWith({
    String? id,
    Rect? rect,
    SketchStyle? style,
    double? angle,
    Object? text = _unset,
    double? fontSize,
    Object? groupId = _unset,
  }) {
    return SketchTriangle(
      id: id ?? this.id,
      style: style ?? this.style,
      rect: rect ?? this.rect,
      angle: angle ?? this.angle,
      text: identical(text, _unset) ? this.text : text as String?,
      fontSize: fontSize ?? this.fontSize,
      groupId: identical(groupId, _unset) ? this.groupId : groupId as String?,
    );
  }

  @override
  SketchTriangle copyWithStyle(SketchStyle newStyle) =>
      copyWith(style: newStyle);

  @override
  SketchTriangle translate(Offset delta) => copyWith(rect: rect.shift(delta));

  @override
  SketchTriangle withId(String id) => copyWith(id: id);

  @override
  SketchTriangle withGroupId(String? groupId) => copyWith(groupId: groupId);

  factory SketchTriangle.create({
    String? id,
    required Rect rect,
    SketchStyle style = const SketchStyle(),
    String? text,
    double fontSize = 16.0,
  }) {
    return SketchTriangle(
      id: id ?? IdGenerator.generate('sketch'),
      style: style,
      rect: rect,
      text: text,
      fontSize: fontSize,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'triangle',
        'id': id,
        'style': style.toJson(),
        'rect': _rectToJson(rect),
        'angle': angle,
        if (text != null) 'text': text,
        'fontSize': fontSize,
        if (groupId != null) 'groupId': groupId,
      };

  factory SketchTriangle.fromJson(Map<String, dynamic> json) {
    return SketchTriangle(
      id: json['id'] as String,
      style: SketchStyle.fromJson(json['style'] as Map<String, dynamic>),
      rect: _rectFromJson(json['rect'] as Map<String, dynamic>),
      angle: (json['angle'] as num?)?.toDouble() ?? 0.0,
      text: json['text'] as String?,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16.0,
      groupId: json['groupId'] as String?,
    );
  }
}

class SketchSticky extends _SketchBoundedShape {
  const SketchSticky({
    required super.id,
    required super.style,
    required super.rect,
    super.text,
    super.fontSize,
    super.angle,
    super.groupId,
    this.cornerRadius = 4.0,
  });

  /// Default sticky-note background colour (Excalidraw-style yellow).
  static const Color defaultColor = Color(0xFFFFEC99);

  final double cornerRadius;

  SketchSticky copyWith({
    String? id,
    Rect? rect,
    SketchStyle? style,
    double? angle,
    double? cornerRadius,
    Object? text = _unset,
    double? fontSize,
    Object? groupId = _unset,
  }) {
    return SketchSticky(
      id: id ?? this.id,
      style: style ?? this.style,
      rect: rect ?? this.rect,
      angle: angle ?? this.angle,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      text: identical(text, _unset) ? this.text : text as String?,
      fontSize: fontSize ?? this.fontSize,
      groupId: identical(groupId, _unset) ? this.groupId : groupId as String?,
    );
  }

  @override
  SketchSticky copyWithStyle(SketchStyle newStyle) => copyWith(style: newStyle);

  @override
  SketchSticky translate(Offset delta) => copyWith(rect: rect.shift(delta));

  @override
  SketchSticky withId(String id) => copyWith(id: id);

  @override
  SketchSticky withGroupId(String? groupId) => copyWith(groupId: groupId);

  factory SketchSticky.create({
    String? id,
    required Rect rect,
    SketchStyle? style,
    String? text,
    double fontSize = 20.0,
    double cornerRadius = 4.0,
  }) {
    return SketchSticky(
      id: id ?? IdGenerator.generate('sketch'),
      style: style ??
          const SketchStyle(
            strokeColor: defaultColor,
            fillColor: defaultColor,
            fillStyle: FillStyle.solid,
          ),
      rect: rect,
      text: text,
      fontSize: fontSize,
      cornerRadius: cornerRadius,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'sticky',
        'id': id,
        'style': style.toJson(),
        'rect': _rectToJson(rect),
        'angle': angle,
        'cornerRadius': cornerRadius,
        if (text != null) 'text': text,
        'fontSize': fontSize,
        if (groupId != null) 'groupId': groupId,
      };

  factory SketchSticky.fromJson(Map<String, dynamic> json) {
    return SketchSticky(
      id: json['id'] as String,
      style: SketchStyle.fromJson(json['style'] as Map<String, dynamic>),
      rect: _rectFromJson(json['rect'] as Map<String, dynamic>),
      angle: (json['angle'] as num?)?.toDouble() ?? 0.0,
      cornerRadius: (json['cornerRadius'] as num?)?.toDouble() ?? 4.0,
      text: json['text'] as String?,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 20.0,
      groupId: json['groupId'] as String?,
    );
  }
}

// Sentinel for nullable copyWith parameters (allows distinguishing
// "no argument" from "explicit null").
const Object _unset = Object();

// ─── Linear shapes (line / arrow) ─────────────────────────────────────────

sealed class _SketchLinear extends SketchElement {
  const _SketchLinear({
    required super.id,
    required super.style,
    required this.start,
    required this.end,
    super.angle,
    super.groupId,
  });

  final Offset start;
  final Offset end;

  @override
  Rect get bounds {
    final left = math.min(start.dx, end.dx);
    final top = math.min(start.dy, end.dy);
    final right = math.max(start.dx, end.dx);
    final bottom = math.max(start.dy, end.dy);
    return Rect.fromLTRB(left, top, right, bottom);
  }
}

class SketchLine extends _SketchLinear {
  const SketchLine({
    required super.id,
    required super.style,
    required super.start,
    required super.end,
    super.angle,
    super.groupId,
  });

  SketchLine copyWith({
    String? id,
    Offset? start,
    Offset? end,
    SketchStyle? style,
    double? angle,
    Object? groupId = _unset,
  }) {
    return SketchLine(
      id: id ?? this.id,
      style: style ?? this.style,
      start: start ?? this.start,
      end: end ?? this.end,
      angle: angle ?? this.angle,
      groupId: identical(groupId, _unset) ? this.groupId : groupId as String?,
    );
  }

  @override
  SketchLine copyWithStyle(SketchStyle newStyle) => copyWith(style: newStyle);

  @override
  SketchLine translate(Offset delta) =>
      copyWith(start: start + delta, end: end + delta);

  @override
  SketchLine withId(String id) => copyWith(id: id);

  @override
  SketchLine withGroupId(String? groupId) => copyWith(groupId: groupId);

  factory SketchLine.create({
    String? id,
    required Offset start,
    required Offset end,
    SketchStyle style = const SketchStyle(),
  }) {
    return SketchLine(
      id: id ?? IdGenerator.generate('sketch'),
      style: style,
      start: start,
      end: end,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'line',
        'id': id,
        'style': style.toJson(),
        'start': _offsetToJson(start),
        'end': _offsetToJson(end),
        'angle': angle,
        if (groupId != null) 'groupId': groupId,
      };

  factory SketchLine.fromJson(Map<String, dynamic> json) {
    return SketchLine(
      id: json['id'] as String,
      style: SketchStyle.fromJson(json['style'] as Map<String, dynamic>),
      start: _offsetFromJson(json['start'] as Map<String, dynamic>),
      end: _offsetFromJson(json['end'] as Map<String, dynamic>),
      angle: (json['angle'] as num?)?.toDouble() ?? 0.0,
      groupId: json['groupId'] as String?,
    );
  }
}

class SketchArrow extends _SketchLinear {
  const SketchArrow({
    required super.id,
    required super.style,
    required super.start,
    required super.end,
    this.arrowSize = 10.0,
    super.angle,
    super.groupId,
    this.startBinding,
    this.endBinding,
  });

  final double arrowSize;

  /// Shape this arrow's tail is attached to — reserved, always `null` for
  /// now. See [SketchBinding] for why it exists before the feature does.
  final SketchBinding? startBinding;

  /// Shape this arrow's head is attached to — reserved, see [startBinding].
  final SketchBinding? endBinding;

  SketchArrow copyWith({
    String? id,
    Offset? start,
    Offset? end,
    SketchStyle? style,
    double? arrowSize,
    double? angle,
    Object? groupId = _unset,
    Object? startBinding = _unset,
    Object? endBinding = _unset,
  }) {
    return SketchArrow(
      id: id ?? this.id,
      style: style ?? this.style,
      start: start ?? this.start,
      end: end ?? this.end,
      arrowSize: arrowSize ?? this.arrowSize,
      angle: angle ?? this.angle,
      groupId: identical(groupId, _unset) ? this.groupId : groupId as String?,
      startBinding: identical(startBinding, _unset)
          ? this.startBinding
          : startBinding as SketchBinding?,
      endBinding: identical(endBinding, _unset)
          ? this.endBinding
          : endBinding as SketchBinding?,
    );
  }

  @override
  SketchArrow copyWithStyle(SketchStyle newStyle) => copyWith(style: newStyle);

  @override
  SketchArrow translate(Offset delta) =>
      copyWith(start: start + delta, end: end + delta);

  @override
  SketchArrow withId(String id) => copyWith(id: id);

  @override
  SketchArrow withGroupId(String? groupId) => copyWith(groupId: groupId);

  factory SketchArrow.create({
    String? id,
    required Offset start,
    required Offset end,
    SketchStyle style = const SketchStyle(),
    double arrowSize = 10.0,
  }) {
    return SketchArrow(
      id: id ?? IdGenerator.generate('sketch'),
      style: style,
      start: start,
      end: end,
      arrowSize: arrowSize,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'arrow',
        'id': id,
        'style': style.toJson(),
        'start': _offsetToJson(start),
        'end': _offsetToJson(end),
        'arrowSize': arrowSize,
        'angle': angle,
        if (groupId != null) 'groupId': groupId,
        if (startBinding != null) 'startBinding': startBinding!.toJson(),
        if (endBinding != null) 'endBinding': endBinding!.toJson(),
      };

  factory SketchArrow.fromJson(Map<String, dynamic> json) {
    return SketchArrow(
      id: json['id'] as String,
      style: SketchStyle.fromJson(json['style'] as Map<String, dynamic>),
      start: _offsetFromJson(json['start'] as Map<String, dynamic>),
      end: _offsetFromJson(json['end'] as Map<String, dynamic>),
      arrowSize: (json['arrowSize'] as num?)?.toDouble() ?? 10.0,
      angle: (json['angle'] as num?)?.toDouble() ?? 0.0,
      groupId: json['groupId'] as String?,
      startBinding: _bindingFromJson(json['startBinding']),
      endBinding: _bindingFromJson(json['endBinding']),
    );
  }
}

/// Attachment of one arrow endpoint to another element.
///
/// Reserved: nothing binds arrows yet, and nothing reads these fields. It
/// ships in v1 anyway because the alternative is worse — a field that first
/// appears in a later release makes every file already saved by a v1 user
/// forward-incompatible and forces a schema bump to fix. Reserving it now
/// costs one class.
///
/// A value type rather than a bare element id for the same reason: [focus]
/// and [gap] are what the binding feature will need, and introducing them
/// later would be a second migration.
class SketchBinding {
  const SketchBinding({
    required this.elementId,
    this.focus = 0.0,
    this.gap = 0.0,
  });

  /// Element the endpoint is attached to.
  final String elementId;

  /// Where along the bound element the arrow aims, `-1..1`, with `0` for
  /// its centre.
  final double focus;

  /// Canvas-space distance the endpoint keeps from the bound element's edge.
  final double gap;

  Map<String, dynamic> toJson() => {
        'elementId': elementId,
        'focus': focus,
        'gap': gap,
      };

  factory SketchBinding.fromJson(Map<String, dynamic> json) {
    return SketchBinding(
      elementId: json['elementId'] as String,
      focus: (json['focus'] as num?)?.toDouble() ?? 0.0,
      gap: (json['gap'] as num?)?.toDouble() ?? 0.0,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is SketchBinding &&
        other.elementId == elementId &&
        other.focus == focus &&
        other.gap == gap;
  }

  @override
  int get hashCode => Object.hash(elementId, focus, gap);
}

SketchBinding? _bindingFromJson(Object? raw) =>
    raw is Map ? SketchBinding.fromJson(raw.cast<String, dynamic>()) : null;

// ─── Freedraw ──────────────────────────────────────────────────────────────

class SketchFreedraw extends SketchElement {
  SketchFreedraw({
    required super.id,
    required super.style,
    required List<Offset> points,
    super.angle,
    super.groupId,
  })  : assert(points.isNotEmpty, 'freedraw must contain at least one point'),
        points = List<Offset>.unmodifiable(points);

  final List<Offset> points;

  @override
  Rect get bounds {
    double minX = points.first.dx, minY = points.first.dy;
    double maxX = minX, maxY = minY;
    for (var i = 1; i < points.length; i++) {
      final p = points[i];
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }

  SketchFreedraw copyWith({
    String? id,
    List<Offset>? points,
    SketchStyle? style,
    double? angle,
    Object? groupId = _unset,
  }) {
    return SketchFreedraw(
      id: id ?? this.id,
      style: style ?? this.style,
      points: points ?? this.points,
      angle: angle ?? this.angle,
      groupId: identical(groupId, _unset) ? this.groupId : groupId as String?,
    );
  }

  @override
  SketchFreedraw copyWithStyle(SketchStyle newStyle) =>
      copyWith(style: newStyle);

  @override
  SketchFreedraw withId(String id) => copyWith(id: id);

  @override
  SketchFreedraw withGroupId(String? groupId) => copyWith(groupId: groupId);

  @override
  SketchFreedraw translate(Offset delta) {
    final shifted = <Offset>[
      for (final p in points) p + delta,
    ];
    return copyWith(points: shifted);
  }

  factory SketchFreedraw.create({
    String? id,
    required List<Offset> points,
    SketchStyle style = const SketchStyle(),
  }) {
    return SketchFreedraw(
      id: id ?? IdGenerator.generate('sketch'),
      style: style,
      points: points,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'freedraw',
        'id': id,
        'style': style.toJson(),
        'points': [
          for (final p in points) _offsetToJson(p),
        ],
        'angle': angle,
        if (groupId != null) 'groupId': groupId,
      };

  factory SketchFreedraw.fromJson(Map<String, dynamic> json) {
    final raw = json['points'] as List<dynamic>;
    return SketchFreedraw(
      id: json['id'] as String,
      style: SketchStyle.fromJson(json['style'] as Map<String, dynamic>),
      points: [
        for (final p in raw) _offsetFromJson(p as Map<String, dynamic>),
      ],
      angle: (json['angle'] as num?)?.toDouble() ?? 0.0,
      groupId: json['groupId'] as String?,
    );
  }
}

// ─── Text ──────────────────────────────────────────────────────────────────

class SketchText extends SketchElement {
  const SketchText({
    required super.id,
    required super.style,
    required this.position,
    required this.text,
    this.fontSize = 16.0,
    this.fontFamily,
    super.angle,
    super.groupId,
  });

  final Offset position;
  final String text;
  final double fontSize;
  final String? fontFamily;

  @override
  Rect get bounds {
    // Measured through the same layout the painter draws with, so the box
    // hit-testing and culling see is exactly the box the user sees. An
    // approximation here silently desynchronises the two.
    final size = TextMetrics.measure(
      text: text,
      fontSize: fontSize,
      fontFamily: fontFamily,
    );
    return Rect.fromLTWH(position.dx, position.dy, size.width, size.height);
  }

  SketchText copyWith({
    String? id,
    Offset? position,
    String? text,
    double? fontSize,
    String? fontFamily,
    SketchStyle? style,
    double? angle,
    Object? groupId = _unset,
  }) {
    return SketchText(
      id: id ?? this.id,
      style: style ?? this.style,
      position: position ?? this.position,
      text: text ?? this.text,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      angle: angle ?? this.angle,
      groupId: identical(groupId, _unset) ? this.groupId : groupId as String?,
    );
  }

  @override
  SketchText copyWithStyle(SketchStyle newStyle) => copyWith(style: newStyle);

  @override
  SketchText translate(Offset delta) =>
      copyWith(position: position + delta);

  @override
  SketchText withId(String id) => copyWith(id: id);

  @override
  SketchText withGroupId(String? groupId) => copyWith(groupId: groupId);

  factory SketchText.create({
    String? id,
    required Offset position,
    required String text,
    double fontSize = 16.0,
    String? fontFamily,
    SketchStyle style = const SketchStyle(),
  }) {
    return SketchText(
      id: id ?? IdGenerator.generate('sketch'),
      style: style,
      position: position,
      text: text,
      fontSize: fontSize,
      fontFamily: fontFamily,
    );
  }

  @override
  Map<String, dynamic> toJson() => {
        'type': 'text',
        'id': id,
        'style': style.toJson(),
        'position': _offsetToJson(position),
        'text': text,
        'fontSize': fontSize,
        if (fontFamily != null) 'fontFamily': fontFamily,
        'angle': angle,
        if (groupId != null) 'groupId': groupId,
      };

  factory SketchText.fromJson(Map<String, dynamic> json) {
    return SketchText(
      id: json['id'] as String,
      style: SketchStyle.fromJson(json['style'] as Map<String, dynamic>),
      position: _offsetFromJson(json['position'] as Map<String, dynamic>),
      text: json['text'] as String,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16.0,
      fontFamily: json['fontFamily'] as String?,
      angle: (json['angle'] as num?)?.toDouble() ?? 0.0,
      groupId: json['groupId'] as String?,
    );
  }
}

// ─── JSON helpers ──────────────────────────────────────────────────────────

Map<String, double> _offsetToJson(Offset o) => {'dx': o.dx, 'dy': o.dy};

Offset _offsetFromJson(Map<String, dynamic> json) => Offset(
      (json['dx'] as num).toDouble(),
      (json['dy'] as num).toDouble(),
    );

Map<String, double> _rectToJson(Rect r) => {
      'l': r.left,
      't': r.top,
      'w': r.width,
      'h': r.height,
    };

Rect _rectFromJson(Map<String, dynamic> json) => Rect.fromLTWH(
      (json['l'] as num).toDouble(),
      (json['t'] as num).toDouble(),
      (json['w'] as num).toDouble(),
      (json['h'] as num).toDouble(),
    );
