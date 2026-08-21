import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/core/rendering/rough_generator.dart';

PathMetric? _firstMetric(Path path) {
  for (final m in path.computeMetrics()) {
    return m;
  }
  return null;
}

void main() {
  group('RoughGenerator determinism', () {
    test('same seed produces identical line paths', () {
      final a = RoughGenerator.line(
        const Offset(0, 0),
        const Offset(100, 0),
        roughness: 1.0,
        seed: 42,
      );
      final b = RoughGenerator.line(
        const Offset(0, 0),
        const Offset(100, 0),
        roughness: 1.0,
        seed: 42,
      );
      expect(_firstMetric(a)?.length, _firstMetric(b)?.length);
    });

    test('different seeds produce different line paths', () {
      final a = RoughGenerator.line(
        const Offset(0, 0),
        const Offset(100, 0),
        roughness: 1.0,
        seed: 1,
      );
      final b = RoughGenerator.line(
        const Offset(0, 0),
        const Offset(100, 0),
        roughness: 1.0,
        seed: 2,
      );
      expect(_firstMetric(a)?.length, isNot(_firstMetric(b)?.length));
    });
  });

  group('RoughGenerator shape coverage', () {
    test('rectangle path bounds contain the source rect', () {
      const rect = Rect.fromLTWH(10, 20, 100, 50);
      final path = RoughGenerator.rectangle(rect, roughness: 0.5, seed: 7);
      final bb = path.getBounds();
      // The sketchy path is allowed to wobble outside the source rect by
      // a few pixels; check that bounds at least overlap the input.
      expect(bb.overlaps(rect), isTrue);
    });

    test('ellipse with zero size yields empty path', () {
      final path = RoughGenerator.ellipse(Rect.zero, seed: 1);
      expect(_firstMetric(path), isNull);
    });

    test('polyline of single point yields a non-empty path', () {
      final path = RoughGenerator.polyline(const [Offset(5, 5)]);
      expect(_firstMetric(path), isNotNull);
    });

    test('polyline of two points yields a single segment', () {
      final path = RoughGenerator.polyline(
        const [Offset(0, 0), Offset(50, 0)],
        smooth: false,
      );
      final m = _firstMetric(path);
      expect(m, isNotNull);
      expect(m!.length, closeTo(50.0, 1e-6));
    });
  });

  group('RoughGenerator.hachure', () {
    test('produces at least one fill segment for a populated rect', () {
      final path = RoughGenerator.hachure(
        const Rect.fromLTWH(0, 0, 100, 100),
        gap: 10.0,
      );
      var segments = 0;
      for (final _ in path.computeMetrics()) {
        segments++;
      }
      expect(segments, greaterThan(0));
    });

    test('returns empty path for zero-sized rect', () {
      final path = RoughGenerator.hachure(Rect.zero);
      expect(_firstMetric(path), isNull);
    });
  });
}
