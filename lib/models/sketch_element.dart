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
  });

  final String id;
  final SketchStyle style;

  /// Rotation in radians, around the centre of [bounds].
  final double angle;

  /// Axis-aligned bounding box in canvas-space (ignoring rotation).
  Rect get bounds;

  SketchElement copyWithStyle(SketchStyle newStyle);
  SketchElement translate(Offset delta);

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
  });

  final double cornerRadius;

  SketchRectangle copyWith({
    Rect? rect,
    SketchStyle? style,
    double? cornerRadius,
    double? angle,
    Object? text = _textSentinel,
    double? fontSize,
  }) {
    return SketchRectangle(
      id: id,
      style: style ?? this.style,
      rect: rect ?? this.rect,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      angle: angle ?? this.angle,
      text: identical(text, _textSentinel) ? this.text : text as String?,
      fontSize: fontSize ?? this.fontSize,
    );
  }

  @override
  SketchRectangle copyWithStyle(SketchStyle newStyle) =>
      copyWith(style: newStyle);

  @override
  SketchRectangle translate(Offset delta) =>
      copyWith(rect: rect.shift(delta));

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
  });

  SketchEllipse copyWith({
    Rect? rect,
    SketchStyle? style,
    double? angle,
    Object? text = _textSentinel,
    double? fontSize,
  }) {
    return SketchEllipse(
      id: id,
      style: style ?? this.style,
      rect: rect ?? this.rect,
      angle: angle ?? this.angle,
      text: identical(text, _textSentinel) ? this.text : text as String?,
      fontSize: fontSize ?? this.fontSize,
    );
  }

  @override
  SketchEllipse copyWithStyle(SketchStyle newStyle) =>
      copyWith(style: newStyle);

  @override
  SketchEllipse translate(Offset delta) => copyWith(rect: rect.shift(delta));

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
      };

  factory SketchEllipse.fromJson(Map<String, dynamic> json) {
    return SketchEllipse(
      id: json['id'] as String,
      style: SketchStyle.fromJson(json['style'] as Map<String, dynamic>),
      rect: _rectFromJson(json['rect'] as Map<String, dynamic>),
      angle: (json['angle'] as num?)?.toDouble() ?? 0.0,
      text: json['text'] as String?,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16.0,
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
  });

  SketchDiamond copyWith({
    Rect? rect,
    SketchStyle? style,
    double? angle,
    Object? text = _textSentinel,
    double? fontSize,
  }) {
    return SketchDiamond(
      id: id,
      style: style ?? this.style,
      rect: rect ?? this.rect,
      angle: angle ?? this.angle,
      text: identical(text, _textSentinel) ? this.text : text as String?,
      fontSize: fontSize ?? this.fontSize,
    );
  }

  @override
  SketchDiamond copyWithStyle(SketchStyle newStyle) =>
      copyWith(style: newStyle);

  @override
  SketchDiamond translate(Offset delta) => copyWith(rect: rect.shift(delta));

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
      };

  factory SketchDiamond.fromJson(Map<String, dynamic> json) {
    return SketchDiamond(
      id: json['id'] as String,
      style: SketchStyle.fromJson(json['style'] as Map<String, dynamic>),
      rect: _rectFromJson(json['rect'] as Map<String, dynamic>),
      angle: (json['angle'] as num?)?.toDouble() ?? 0.0,
      text: json['text'] as String?,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16.0,
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
  });

  SketchTriangle copyWith({
    Rect? rect,
    SketchStyle? style,
    double? angle,
    Object? text = _textSentinel,
    double? fontSize,
  }) {
    return SketchTriangle(
      id: id,
      style: style ?? this.style,
      rect: rect ?? this.rect,
      angle: angle ?? this.angle,
      text: identical(text, _textSentinel) ? this.text : text as String?,
      fontSize: fontSize ?? this.fontSize,
    );
  }

  @override
  SketchTriangle copyWithStyle(SketchStyle newStyle) =>
      copyWith(style: newStyle);

  @override
  SketchTriangle translate(Offset delta) => copyWith(rect: rect.shift(delta));

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
      };

  factory SketchTriangle.fromJson(Map<String, dynamic> json) {
    return SketchTriangle(
      id: json['id'] as String,
      style: SketchStyle.fromJson(json['style'] as Map<String, dynamic>),
      rect: _rectFromJson(json['rect'] as Map<String, dynamic>),
      angle: (json['angle'] as num?)?.toDouble() ?? 0.0,
      text: json['text'] as String?,
      fontSize: (json['fontSize'] as num?)?.toDouble() ?? 16.0,
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
    this.cornerRadius = 4.0,
  });

  /// Default sticky-note background colour (Excalidraw-style yellow).
  static const Color defaultColor = Color(0xFFFFEC99);

  final double cornerRadius;

  SketchSticky copyWith({
    Rect? rect,
    SketchStyle? style,
    double? angle,
    double? cornerRadius,
    Object? text = _textSentinel,
    double? fontSize,
  }) {
    return SketchSticky(
      id: id,
      style: style ?? this.style,
      rect: rect ?? this.rect,
      angle: angle ?? this.angle,
      cornerRadius: cornerRadius ?? this.cornerRadius,
      text: identical(text, _textSentinel) ? this.text : text as String?,
      fontSize: fontSize ?? this.fontSize,
    );
  }

  @override
  SketchSticky copyWithStyle(SketchStyle newStyle) => copyWith(style: newStyle);

  @override
  SketchSticky translate(Offset delta) => copyWith(rect: rect.shift(delta));

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
    );
  }
}

// Sentinel for nullable copyWith parameters (allows distinguishing
// "no argument" from "explicit null").
const Object _textSentinel = Object();

// ─── Linear shapes (line / arrow) ─────────────────────────────────────────

sealed class _SketchLinear extends SketchElement {
  const _SketchLinear({
    required super.id,
    required super.style,
    required this.start,
    required this.end,
    super.angle,
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
  });

  SketchLine copyWith({
    Offset? start,
    Offset? end,
    SketchStyle? style,
    double? angle,
  }) {
    return SketchLine(
      id: id,
      style: style ?? this.style,
      start: start ?? this.start,
      end: end ?? this.end,
      angle: angle ?? this.angle,
    );
  }

  @override
  SketchLine copyWithStyle(SketchStyle newStyle) => copyWith(style: newStyle);

  @override
  SketchLine translate(Offset delta) =>
      copyWith(start: start + delta, end: end + delta);

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
      };

  factory SketchLine.fromJson(Map<String, dynamic> json) {
    return SketchLine(
      id: json['id'] as String,
      style: SketchStyle.fromJson(json['style'] as Map<String, dynamic>),
      start: _offsetFromJson(json['start'] as Map<String, dynamic>),
      end: _offsetFromJson(json['end'] as Map<String, dynamic>),
      angle: (json['angle'] as num?)?.toDouble() ?? 0.0,
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
  });

  final double arrowSize;

  SketchArrow copyWith({
    Offset? start,
    Offset? end,
    SketchStyle? style,
    double? arrowSize,
    double? angle,
  }) {
    return SketchArrow(
      id: id,
      style: style ?? this.style,
      start: start ?? this.start,
      end: end ?? this.end,
      arrowSize: arrowSize ?? this.arrowSize,
      angle: angle ?? this.angle,
    );
  }

  @override
  SketchArrow copyWithStyle(SketchStyle newStyle) => copyWith(style: newStyle);

  @override
  SketchArrow translate(Offset delta) =>
      copyWith(start: start + delta, end: end + delta);

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
      };

  factory SketchArrow.fromJson(Map<String, dynamic> json) {
    return SketchArrow(
      id: json['id'] as String,
      style: SketchStyle.fromJson(json['style'] as Map<String, dynamic>),
      start: _offsetFromJson(json['start'] as Map<String, dynamic>),
      end: _offsetFromJson(json['end'] as Map<String, dynamic>),
      arrowSize: (json['arrowSize'] as num?)?.toDouble() ?? 10.0,
      angle: (json['angle'] as num?)?.toDouble() ?? 0.0,
    );
  }
}

// ─── Freedraw ──────────────────────────────────────────────────────────────

class SketchFreedraw extends SketchElement {
  SketchFreedraw({
    required super.id,
    required super.style,
    required List<Offset> points,
    super.angle,
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
    List<Offset>? points,
    SketchStyle? style,
    double? angle,
  }) {
    return SketchFreedraw(
      id: id,
      style: style ?? this.style,
      points: points ?? this.points,
      angle: angle ?? this.angle,
    );
  }

  @override
  SketchFreedraw copyWithStyle(SketchStyle newStyle) =>
      copyWith(style: newStyle);

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
    Offset? position,
    String? text,
    double? fontSize,
    String? fontFamily,
    SketchStyle? style,
    double? angle,
  }) {
    return SketchText(
      id: id,
      style: style ?? this.style,
      position: position ?? this.position,
      text: text ?? this.text,
      fontSize: fontSize ?? this.fontSize,
      fontFamily: fontFamily ?? this.fontFamily,
      angle: angle ?? this.angle,
    );
  }

  @override
  SketchText copyWithStyle(SketchStyle newStyle) => copyWith(style: newStyle);

  @override
  SketchText translate(Offset delta) =>
      copyWith(position: position + delta);

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
