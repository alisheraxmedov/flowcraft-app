import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/sketch/domain/stroke_simplifier.dart';

void main() {
  group('StrokeSimplifier.simplify', () {
    test('returns input unchanged when < 3 points', () {
      final points = [const Offset(0, 0), const Offset(10, 10)];
      expect(StrokeSimplifier.simplify(points), points);
    });

    test('collinear points are reduced to endpoints', () {
      final points = [
        for (var i = 0; i <= 10; i++) Offset(i.toDouble(), 0),
      ];
      final out = StrokeSimplifier.simplify(points, tolerance: 0.01);
      expect(out, [const Offset(0, 0), const Offset(10, 0)]);
    });

    test('preserves shape within tolerance', () {
      final points = [
        const Offset(0, 0),
        const Offset(1, 0.05),
        const Offset(2, 0),
        const Offset(3, 5),
        const Offset(4, 0),
        const Offset(5, 0.04),
        const Offset(6, 0),
      ];
      final out = StrokeSimplifier.simplify(points, tolerance: 0.1);
      expect(out.first, points.first);
      expect(out.last, points.last);
      // The spike at index 3 must be retained.
      expect(out, contains(const Offset(3, 5)));
      // Tolerance keeps the result shorter than the input.
      expect(out.length, lessThan(points.length));
    });

    test('returns unmodifiable list', () {
      final out = StrokeSimplifier.simplify([
        const Offset(0, 0),
        const Offset(1, 1),
        const Offset(2, 0),
      ]);
      expect(() => out.add(Offset.zero), throwsUnsupportedError);
    });
  });

  group('StrokeSimplifier.smooth', () {
    test('two-point input is returned unchanged', () {
      final points = [const Offset(0, 0), const Offset(10, 0)];
      expect(StrokeSimplifier.smooth(points), points);
    });

    test('output length scales with subdivisions', () {
      final points = [
        const Offset(0, 0),
        const Offset(10, 5),
        const Offset(20, 0),
        const Offset(30, 5),
      ];
      final out2 = StrokeSimplifier.smooth(points, subdivisions: 2);
      final out6 = StrokeSimplifier.smooth(points, subdivisions: 6);
      expect(out6.length, greaterThan(out2.length));
      expect(out2.first, points.first);
      expect(out2.last, points.last);
    });

    test('output produces finite numbers only', () {
      final points = [
        for (var i = 0; i < 10; i++)
          Offset(i.toDouble(), math.sin(i.toDouble())),
      ];
      final out = StrokeSimplifier.smooth(points);
      for (final p in out) {
        expect(p.dx.isFinite, isTrue);
        expect(p.dy.isFinite, isTrue);
      }
    });
  });
}
