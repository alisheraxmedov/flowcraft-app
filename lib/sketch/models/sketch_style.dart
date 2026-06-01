import 'dart:ui';

/// Stroke pattern for sketch element borders.
enum StrokeStyle {
  solid,
  dashed,
  dotted;

  /// Returns the dash pattern in canvas-space pixels (pre-zoom).
  /// Empty list means solid.
  List<double> get pattern {
    switch (this) {
      case StrokeStyle.solid:
        return const <double>[];
      case StrokeStyle.dashed:
        return const [8.0, 6.0];
      case StrokeStyle.dotted:
        return const [2.0, 4.0];
    }
  }
}

/// Fill pattern for closed sketch elements.
enum FillStyle {
  none,
  solid,
  hachure,
  crossHatch;
}

/// Immutable visual style for a [SketchElement].
///
/// Use [copyWith] to derive a modified style; instances are otherwise frozen.
class SketchStyle {
  const SketchStyle({
    this.strokeColor = const Color(0xFF1E1E1E),
    this.fillColor,
    this.strokeWidth = 2.0,
    this.strokeStyle = StrokeStyle.solid,
    this.roughness = 1.0,
    this.fillStyle = FillStyle.none,
    this.opacity = 1.0,
    this.seed = 1,
  }) : assert(roughness >= 0.0),
       assert(opacity >= 0.0 && opacity <= 1.0),
       assert(strokeWidth >= 0.0);

  final Color strokeColor;
  final Color? fillColor;
  final double strokeWidth;
  final StrokeStyle strokeStyle;

  /// Sketchiness level. 0 = clean geometric; 1 = normal; 2 = very rough.
  final double roughness;

  final FillStyle fillStyle;
  final double opacity;

  /// PRNG seed for deterministic sketchy rendering. Bump when style mutates
  /// in a way that should re-randomize the strokes; keep stable to reuse
  /// cached rough paths.
  final int seed;

  SketchStyle copyWith({
    Color? strokeColor,
    Object? fillColor = _sentinel,
    double? strokeWidth,
    StrokeStyle? strokeStyle,
    double? roughness,
    FillStyle? fillStyle,
    double? opacity,
    int? seed,
  }) {
    return SketchStyle(
      strokeColor: strokeColor ?? this.strokeColor,
      fillColor: identical(fillColor, _sentinel)
          ? this.fillColor
          : fillColor as Color?,
      strokeWidth: strokeWidth ?? this.strokeWidth,
      strokeStyle: strokeStyle ?? this.strokeStyle,
      roughness: roughness ?? this.roughness,
      fillStyle: fillStyle ?? this.fillStyle,
      opacity: opacity ?? this.opacity,
      seed: seed ?? this.seed,
    );
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'strokeColor': strokeColor.toARGB32(),
        if (fillColor != null) 'fillColor': fillColor!.toARGB32(),
        'strokeWidth': strokeWidth,
        'strokeStyle': strokeStyle.name,
        'roughness': roughness,
        'fillStyle': fillStyle.name,
        'opacity': opacity,
        'seed': seed,
      };

  factory SketchStyle.fromJson(Map<String, dynamic> json) {
    return SketchStyle(
      strokeColor: Color(json['strokeColor'] as int),
      fillColor: json['fillColor'] == null
          ? null
          : Color(json['fillColor'] as int),
      strokeWidth: (json['strokeWidth'] as num).toDouble(),
      strokeStyle: StrokeStyle.values.byName(json['strokeStyle'] as String),
      roughness: (json['roughness'] as num).toDouble(),
      fillStyle: FillStyle.values.byName(json['fillStyle'] as String),
      opacity: (json['opacity'] as num).toDouble(),
      seed: json['seed'] as int,
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    if (other is! SketchStyle) return false;
    return strokeColor == other.strokeColor &&
        fillColor == other.fillColor &&
        strokeWidth == other.strokeWidth &&
        strokeStyle == other.strokeStyle &&
        roughness == other.roughness &&
        fillStyle == other.fillStyle &&
        opacity == other.opacity &&
        seed == other.seed;
  }

  @override
  int get hashCode => Object.hash(
        strokeColor,
        fillColor,
        strokeWidth,
        strokeStyle,
        roughness,
        fillStyle,
        opacity,
        seed,
      );
}

const Object _sentinel = Object();
