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
enum FillStyle { none, solid, hachure, crossHatch }

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
    this.seed = defaultSeed,
  }) : assert(roughness >= 0.0),
       assert(opacity >= 0.0 && opacity <= 1.0),
       assert(strokeWidth >= 0.0);

  /// The seed a style has when nobody chose one.
  ///
  /// Every element `create` factory treats a style carrying this seed as
  /// unseeded and gives the element a random one of its own, so that two
  /// same-sized shapes don't wobble identically. A style built with any
  /// other seed is left alone, and `fromJson` never re-seeds: a saved
  /// scene keeps rendering exactly as it was saved.
  static const int defaultSeed = 1;

  /// Widest stroke a file may ask for. The UI stops at 12; the cap only
  /// keeps a hostile value from handing Skia a stroke wider than the board.
  static const double maxStrokeWidth = 64.0;

  /// Thinnest stroke a file may ask for — a stroke has to be a stroke.
  static const double minStrokeWidth = 0.1;

  /// Roughest a file may ask for. The UI stops at 2.5.
  static const double maxRoughness = 10.0;

  final Color strokeColor;
  final Color? fillColor;
  final double strokeWidth;
  final StrokeStyle strokeStyle;

  /// Sketchiness level. 0 = clean geometric; 1 = normal; 2 = very rough.
  final double roughness;

  final FillStyle fillStyle;
  final double opacity;

  /// PRNG seed for deterministic sketchy rendering. Assigned per element at
  /// creation (see [defaultSeed]); keep stable to reuse cached rough paths.
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

  /// Derives a style with [fillColor] applied, keeping [fillStyle] in step.
  ///
  /// `SketchPainter` only paints a fill when `fillStyle != none && fillColor
  /// != null`, so the two fields have to move together: picking a colour out
  /// of the fill palette while [fillStyle] is still [FillStyle.none] paints
  /// nothing at all, which reads as "the colour tool is broken" long before
  /// the user finds the separate fill-style popover. A concrete colour
  /// therefore promotes a `none` style to [FillStyle.solid]; the palette's
  /// "none" sentinel (`null`) drops it back to [FillStyle.none].
  SketchStyle withFillColor(Color? fillColor) {
    if (fillColor == null) {
      return copyWith(fillColor: null, fillStyle: FillStyle.none);
    }
    return copyWith(
      fillColor: fillColor,
      fillStyle: fillStyle == FillStyle.none ? FillStyle.solid : fillStyle,
    );
  }

  /// Derives a style with [fillStyle] applied, keeping [fillColor] in step —
  /// the mirror of [withFillColor].
  ///
  /// A visible fill style with no fill colour is exactly as invisible as a
  /// fill colour with [FillStyle.none], so it adopts [strokeColor]: the one
  /// colour the user has actually picked, and one the fill swatch shows
  /// immediately, so the pick is visible and correctable instead of a
  /// silent no-op. [FillStyle.none] clears the colour in return, so "no
  /// fill" reads the same way from either control.
  SketchStyle withFillStyle(FillStyle fillStyle) {
    if (fillStyle == FillStyle.none) {
      return copyWith(fillColor: null, fillStyle: FillStyle.none);
    }
    return copyWith(fillColor: fillColor ?? strokeColor, fillStyle: fillStyle);
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

  /// Reads a style, clamping the numeric fields into range.
  ///
  /// The constructor's range checks are `assert`s, which a release build
  /// strips — so a file saying `"opacity": 7` or `"strokeWidth": -3` used
  /// to load cleanly in release and hand those numbers straight to Skia,
  /// while throwing in debug. Clamped rather than refused because these are
  /// presentation values: a shape with an out-of-range opacity is still the
  /// user's shape, and dropping it costs more than drawing it at 100%.
  /// Non-finite values take the default for the same reason.
  factory SketchStyle.fromJson(Map<String, dynamic> json) {
    const defaults = SketchStyle();
    return SketchStyle(
      strokeColor: Color(json['strokeColor'] as int),
      fillColor: json['fillColor'] == null
          ? null
          : Color(json['fillColor'] as int),
      strokeWidth: _clamped(
        json['strokeWidth'] as num,
        minStrokeWidth,
        maxStrokeWidth,
        defaults.strokeWidth,
      ),
      strokeStyle: StrokeStyle.values.byName(json['strokeStyle'] as String),
      roughness: _clamped(
        json['roughness'] as num,
        0.0,
        maxRoughness,
        defaults.roughness,
      ),
      fillStyle: FillStyle.values.byName(json['fillStyle'] as String),
      opacity: _clamped(json['opacity'] as num, 0.0, 1.0, defaults.opacity),
      seed: json['seed'] as int,
    );
  }

  /// [raw] within [min]..[max], or [fallback] when it is not a finite number.
  static double _clamped(num raw, double min, double max, double fallback) {
    final value = raw.toDouble();
    if (!value.isFinite) return fallback;
    return value.clamp(min, max);
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
