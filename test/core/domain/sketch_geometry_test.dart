import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/core/domain/sketch_geometry.dart';

void main() {
  group('SketchGeometry.distanceToSegment', () {
    test('returns distance to closest projection inside segment', () {
      final d = SketchGeometry.distanceToSegment(
        const Offset(5, 5),
        const Offset(0, 0),
        const Offset(10, 0),
      );
      expect(d, closeTo(5.0, 1e-9));
    });

    test('returns endpoint distance when projection is outside segment', () {
      final d = SketchGeometry.distanceToSegment(
        const Offset(-5, 0),
        const Offset(0, 0),
        const Offset(10, 0),
      );
      expect(d, closeTo(5.0, 1e-9));
    });

    test('returns endpoint distance for zero-length segment', () {
      final d = SketchGeometry.distanceToSegment(
        const Offset(3, 4),
        const Offset(0, 0),
        const Offset(0, 0),
      );
      expect(d, closeTo(5.0, 1e-9));
    });
  });

  group('SketchGeometry.pointInRotatedRect', () {
    test('axis-aligned rect uses Rect.contains', () {
      final rect = const Rect.fromLTWH(0, 0, 10, 10);
      expect(SketchGeometry.pointInRotatedRect(const Offset(5, 5), rect, 0), isTrue);
      expect(
        SketchGeometry.pointInRotatedRect(const Offset(-1, 5), rect, 0),
        isFalse,
      );
    });
  });

  group('SketchGeometry.pointInEllipse', () {
    test('centre is inside', () {
      final rect = const Rect.fromLTWH(0, 0, 20, 10);
      expect(SketchGeometry.pointInEllipse(const Offset(10, 5), rect, 0), isTrue);
    });

    test('corner of bbox is outside', () {
      final rect = const Rect.fromLTWH(0, 0, 20, 10);
      expect(SketchGeometry.pointInEllipse(const Offset(0, 0), rect, 0), isFalse);
    });
  });

  group('SketchGeometry.pointInDiamond', () {
    final rect = const Rect.fromLTWH(0, 0, 10, 10);

    test('centre is inside', () {
      expect(SketchGeometry.pointInDiamond(const Offset(5, 5), rect, 0), isTrue);
    });

    test('top vertex is on the boundary (inclusive)', () {
      expect(SketchGeometry.pointInDiamond(const Offset(5, 0), rect, 0), isTrue);
    });

    test('corner of bbox is outside', () {
      expect(SketchGeometry.pointInDiamond(const Offset(0, 0), rect, 0), isFalse);
    });
  });

  group('SketchGeometry.boundsOfPoints', () {
    test('returns Rect.zero for empty input', () {
      expect(SketchGeometry.boundsOfPoints(const []), Rect.zero);
    });

    test('computes tight bounding box', () {
      final r = SketchGeometry.boundsOfPoints(const [
        Offset(1, 2),
        Offset(5, 4),
        Offset(-3, 7),
      ]);
      expect(r, const Rect.fromLTRB(-3, 2, 5, 7));
    });
  });
}
