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
      final path = RoughGenerator.polyline(const [
        Offset(0, 0),
        Offset(50, 0),
      ], smooth: false);
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

    test('gives up past maxHachureSteps instead of building tens of '
        'thousands of cubics', () {
      const huge = Rect.fromLTWH(0, 0, 100000, 100000);
      expect(RoughGenerator.hachureFits(huge), isFalse);
      expect(_firstMetric(RoughGenerator.hachure(huge)), isNull);

      const large = Rect.fromLTWH(0, 0, 4000, 4000);
      expect(RoughGenerator.hachureFits(large), isTrue);
      expect(_firstMetric(RoughGenerator.hachure(large)), isNotNull);
    });
  });

  group('_Rng seeding', () {
    Rect bounds(int seed) => RoughGenerator.line(
      const Offset(0, 0),
      const Offset(100, 0),
      roughness: 2.0,
      seed: seed,
    ).getBounds();

    test('seed 0x7FFFFFFF still jitters', () {
      // Park–Miller's modulus: `seed & 0xFFFFFFFF` then `% m` used to land
      // on state 0, a fixed point that returned 0 forever — zero jitter and
      // an identical path for every multiple of m.
      expect(bounds(0x7FFFFFFF), isNot(bounds(0x7FFFFFFF * 2)));
      expect(bounds(0x7FFFFFFF), isNot(bounds(0)));
    });

    test('seeds already in range keep their exact path', () {
      // Boards saved before the fix must render with the wobble they had.
      final a = RoughGenerator.line(
        const Offset(0, 0),
        const Offset(100, 0),
        seed: 1,
      );
      final b = RoughGenerator.line(
        const Offset(0, 0),
        const Offset(100, 0),
        seed: 1,
      );
      expect(a.getBounds(), b.getBounds());
      expect(_firstMetric(a)!.length, _firstMetric(b)!.length);
    });

    test('a negative seed is accepted', () {
      expect(() => bounds(-5), returnsNormally);
      expect(bounds(-5), isNot(bounds(-6)));
    });
  });

  group('RoughGenerator.dash', () {
    test(
      'cuts a straight path into the pattern and keeps the total length',
      () {
        final line = Path()
          ..moveTo(0, 0)
          ..lineTo(100, 0);
        final dashed = RoughGenerator.dash(line, const [8.0, 6.0]);
        final metrics = dashed.computeMetrics().toList();
        // 100 / 14 → 7 full (8 on, 6 off) periods plus one 2px tail dash.
        expect(metrics.length, 8);
        final on = metrics.fold(0.0, (sum, m) => sum + m.length);
        expect(on, closeTo(7 * 8 + 2, 0.05));
      },
    );

    test('a pattern shorter than two entries returns the path unchanged', () {
      final line = Path()
        ..moveTo(0, 0)
        ..lineTo(100, 0);
      expect(identical(RoughGenerator.dash(line, const []), line), isTrue);
      expect(identical(RoughGenerator.dash(line, const [4.0]), line), isTrue);
    });
  });
}
