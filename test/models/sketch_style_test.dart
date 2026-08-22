import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/models/sketch_style.dart';

/// Coverage for the fill colour ⇄ fill style coupling.
///
/// `SketchPainter` only paints a fill when both are set, so a pick that
/// touches one without the other is invisible — the "fill colour does
/// nothing" the user reported.
void main() {
  const fill = Color(0xFFFFE3E3);

  group('SketchStyle.withFillColor', () {
    test('promotes a none fill style so the colour is actually visible', () {
      const style = SketchStyle();
      expect(style.fillStyle, FillStyle.none);

      final next = style.withFillColor(fill);
      expect(next.fillColor, fill);
      expect(next.fillStyle, FillStyle.solid);
    });

    test('leaves an already-visible fill style alone', () {
      const style = SketchStyle(
        fillColor: Color(0xFF00FF00),
        fillStyle: FillStyle.hachure,
      );
      final next = style.withFillColor(fill);
      expect(next.fillColor, fill);
      expect(next.fillStyle, FillStyle.hachure);
    });

    test('the "none" sentinel clears both halves', () {
      const style = SketchStyle(fillColor: fill, fillStyle: FillStyle.solid);
      final next = style.withFillColor(null);
      expect(next.fillColor, isNull);
      expect(next.fillStyle, FillStyle.none);
    });

    test('leaves every other field untouched', () {
      const style = SketchStyle(strokeWidth: 5, roughness: 2, opacity: 0.5);
      final next = style.withFillColor(fill);
      expect(next.strokeColor, style.strokeColor);
      expect(next.strokeWidth, 5);
      expect(next.roughness, 2);
      expect(next.opacity, 0.5);
    });
  });

  group('SketchStyle.withFillStyle', () {
    test('adopts the stroke colour when no fill colour is set', () {
      const style = SketchStyle(strokeColor: Color(0xFF1971C2));
      expect(style.fillColor, isNull);

      final next = style.withFillStyle(FillStyle.hachure);
      expect(next.fillStyle, FillStyle.hachure);
      expect(next.fillColor, const Color(0xFF1971C2));
    });

    test('keeps an existing fill colour', () {
      const style = SketchStyle(fillColor: fill, fillStyle: FillStyle.solid);
      final next = style.withFillStyle(FillStyle.crossHatch);
      expect(next.fillStyle, FillStyle.crossHatch);
      expect(next.fillColor, fill);
    });

    test('none clears the colour, mirroring withFillColor(null)', () {
      const style = SketchStyle(fillColor: fill, fillStyle: FillStyle.solid);
      final next = style.withFillStyle(FillStyle.none);
      expect(next.fillStyle, FillStyle.none);
      expect(next.fillColor, isNull);
      expect(next, style.withFillColor(null));
    });
  });

  group('SketchStyle.fromJson', () {
    // The constructor's range checks are asserts, which release builds
    // strip: a file with `"opacity": 7` loaded cleanly in release and went
    // straight to Skia, while the same file threw in debug. Out-of-range
    // values are clamped, not refused — a shape with a silly opacity is
    // still the user's shape.
    Map<String, dynamic> json({
      Object? strokeWidth,
      Object? roughness,
      Object? opacity,
    }) =>
        <String, dynamic>{
          ...const SketchStyle().toJson(),
          'strokeWidth': ?strokeWidth,
          'roughness': ?roughness,
          'opacity': ?opacity,
        };

    test('round-trips in-range values untouched', () {
      const style = SketchStyle(
        strokeWidth: 3.5,
        roughness: 1.7,
        opacity: 0.4,
        seed: 99,
      );
      expect(SketchStyle.fromJson(style.toJson()), style);
    });

    test('clamps opacity into 0..1', () {
      expect(SketchStyle.fromJson(json(opacity: 7)).opacity, 1.0);
      expect(SketchStyle.fromJson(json(opacity: -2)).opacity, 0.0);
    });

    test('clamps strokeWidth to a positive, finite width', () {
      expect(
        SketchStyle.fromJson(json(strokeWidth: -3)).strokeWidth,
        SketchStyle.minStrokeWidth,
      );
      expect(
        SketchStyle.fromJson(json(strokeWidth: 0)).strokeWidth,
        SketchStyle.minStrokeWidth,
      );
      expect(
        SketchStyle.fromJson(json(strokeWidth: 1e6)).strokeWidth,
        SketchStyle.maxStrokeWidth,
      );
      expect(SketchStyle.fromJson(json(strokeWidth: 12)).strokeWidth, 12);
    });

    test('clamps roughness to non-negative', () {
      expect(SketchStyle.fromJson(json(roughness: -1)).roughness, 0.0);
      expect(
        SketchStyle.fromJson(json(roughness: 500)).roughness,
        SketchStyle.maxRoughness,
      );
    });

    test('a non-finite number takes the default rather than NaN', () {
      const defaults = SketchStyle();
      expect(
        SketchStyle.fromJson(json(opacity: double.nan)).opacity,
        defaults.opacity,
      );
      expect(
        SketchStyle.fromJson(json(strokeWidth: double.infinity)).strokeWidth,
        defaults.strokeWidth,
      );
      expect(
        SketchStyle.fromJson(json(roughness: double.negativeInfinity))
            .roughness,
        defaults.roughness,
      );
    });

    test('is identical in debug and release: never asserts', () {
      // Reached through fromJson, an out-of-range value must not trip the
      // constructor's assert — that is the whole point of clamping first.
      expect(() => SketchStyle.fromJson(json(opacity: 7)), returnsNormally);
      expect(
        () => SketchStyle.fromJson(json(strokeWidth: -3)),
        returnsNormally,
      );
    });
  });
}
