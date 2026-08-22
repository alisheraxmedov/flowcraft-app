import 'dart:math' as math;

import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/core/domain/stroke_simplifier.dart';

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

    test('survives a 50 000-point stroke that splits one point at a time',
        () {
      // A spiral whose radius grows every step: the point farthest from any
      // chord is always the one next to its end, so every split peels off a
      // single point and the recursive form went as deep as the stroke is
      // long. This is what a tight scribble at 120 Hz looks like.
      const n = 50000;
      final points = <Offset>[
        for (var i = 0; i < n; i++)
          Offset(
            i * 0.02 * math.cos(i * 0.05),
            i * 0.02 * math.sin(i * 0.05),
          ),
      ];

      final out = StrokeSimplifier.simplify(points, tolerance: 0.5);

      expect(out.first, points.first);
      expect(out.last, points.last);
      expect(out.length, greaterThan(2), reason: 'a spiral is not a chord');
      expect(out.length, lessThan(n), reason: 'and it does simplify');
      // Every kept point is an original point, in order.
      var cursor = 0;
      for (final p in out) {
        cursor = points.indexOf(p, cursor);
        expect(cursor, isNonNegative);
      }
    });

    test('a staircase keeps every corner and nothing else', () {
      // The other pathological shape: monotone, farthest point adjacent to
      // an endpoint at every level.
      final points = <Offset>[];
      for (var i = 0; i < 2000; i++) {
        points.add(Offset(i.toDouble(), i.toDouble()));
        points.add(Offset(i + 1.0, i.toDouble()));
      }
      final out = StrokeSimplifier.simplify(points, tolerance: 0.1);
      expect(out.length, points.length,
          reason: 'each tread is 1px from the chord, well past tolerance');
    });
  });
}
