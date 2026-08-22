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
}
