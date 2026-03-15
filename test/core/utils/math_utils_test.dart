import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';
import 'package:flutter/widgets.dart';

void main() {
  group('MathUtils', () {
    test('handleDirection returns correct vectors', () {
      expect(MathUtils.handleDirection('top'), const Offset(0, -1));
      expect(MathUtils.handleDirection('bottom'), const Offset(0, 1));
      expect(MathUtils.handleDirection('left'), const Offset(-1, 0));
      expect(MathUtils.handleDirection('right'), const Offset(1, 0));
      expect(MathUtils.handleDirection('unknown'), const Offset(0, 1));
    });

    test('lerpOffset interpolates correctly', () {
      const a = Offset(0, 0);
      const b = Offset(100, 100);
      expect(MathUtils.lerpOffset(a, b, 0.5), const Offset(50, 50));
      expect(MathUtils.lerpOffset(a, b, 0.0), const Offset(0, 0));
      expect(MathUtils.lerpOffset(a, b, 1.0), const Offset(100, 100));
    });

    test('clampDouble clamps correctly', () {
      expect(MathUtils.clampDouble(5.0, 0.0, 10.0), 5.0);
      expect(MathUtils.clampDouble(-5.0, 0.0, 10.0), 0.0);
      expect(MathUtils.clampDouble(15.0, 0.0, 10.0), 10.0);
    });

    test('distance calculates correctly', () {
      expect(MathUtils.distance(const Offset(0, 0), const Offset(3, 4)), 5.0);
    });

    test('bezierControlPoints calculate correctly', () {
      const source = Offset(0, 0);
      const target = Offset(100, 100);
      
      final cps = MathUtils.bezierControlPoints(source, target);
      expect(cps.length, 2);
      expect(cps[0], const Offset(0, 50));
      expect(cps[1], const Offset(100, 50));
    });

    test('bezierMidpoint calculates correctly', () {
      const p0 = Offset(0, 0);
      const p1 = Offset(0, 50);
      const p2 = Offset(100, 50);
      const p3 = Offset(100, 100);
      
      final mid = MathUtils.bezierMidpoint(p0, p1, p2, p3);
      expect(mid.dx, 50.0);
      expect(mid.dy, 50.0);
    });

    test('boundingRect wraps points correctly', () {
      expect(MathUtils.boundingRect([]), Rect.zero);
      
      final points = [
        const Offset(10, 10),
        const Offset(20, 30),
        const Offset(5, 40),
      ];
      final rect = MathUtils.boundingRect(points, padding: 10);
      expect(rect.left, -5);
      expect(rect.top, 0);
      expect(rect.right, 30);
      expect(rect.bottom, 50);
    });
  });
}
