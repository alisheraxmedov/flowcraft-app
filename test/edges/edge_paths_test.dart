import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';

void main() {
  group('Edge Path Calculators', () {
    test('StraightEdge.buildPath', () {
      const source = Offset(10, 10);
      const target = Offset(20, 20);
      final path = StraightEdge.buildPath(source, target);

      expect(path.computeMetrics().isNotEmpty, isTrue);
      final bounds = path.getBounds();
      expect(bounds.width, 10.0);
      expect(bounds.height, 10.0);
    });

    test('StraightEdge.midpoint returns center', () {
      final mid = StraightEdge.midpoint(const Offset(0, 0), const Offset(100, 200));
      expect(mid, const Offset(50, 100));
    });

    test('SmoothStepEdge.buildPath horizontal', () {
      final path = SmoothStepEdge.buildPath(
        const Offset(10, 10),
        const Offset(100, 50),
        sourcePosition: HandlePosition.right,
        targetPosition: HandlePosition.left,
      );
      expect(path.computeMetrics().isNotEmpty, isTrue);
    });

    test('SmoothStepEdge.buildPath vertical', () {
      final path = SmoothStepEdge.buildPath(
        const Offset(10, 10),
        const Offset(50, 100),
        sourcePosition: HandlePosition.bottom,
        targetPosition: HandlePosition.top,
      );
      expect(path.computeMetrics().isNotEmpty, isTrue);
    });

    test('SmoothStepEdge.midpoint returns center', () {
      final mid = SmoothStepEdge.midpoint(const Offset(0, 0), const Offset(200, 100));
      expect(mid, const Offset(100, 50));
    });
  });

  group('StepEdge', () {
    test('bottom-to-top path', () {
      final path = StepEdge.buildPath(
        const Offset(50, 50), const Offset(200, 200),
        sourcePosition: HandlePosition.bottom,
        targetPosition: HandlePosition.top,
      );
      expect(path.computeMetrics().isNotEmpty, isTrue);
      expect(path.computeMetrics().first.length, greaterThan(0));
    });

    test('right-to-left path', () {
      final path = StepEdge.buildPath(
        const Offset(10, 50), const Offset(300, 150),
        sourcePosition: HandlePosition.right,
        targetPosition: HandlePosition.left,
      );
      expect(path.computeMetrics().isNotEmpty, isTrue);
      expect(path.computeMetrics().first.length, greaterThan(0));
    });

    test('top-to-bottom path', () {
      final path = StepEdge.buildPath(
        const Offset(100, 300), const Offset(200, 50),
        sourcePosition: HandlePosition.top,
        targetPosition: HandlePosition.bottom,
      );
      expect(path.computeMetrics().isNotEmpty, isTrue);
    });

    test('left-to-right path', () {
      final path = StepEdge.buildPath(
        const Offset(300, 50), const Offset(10, 150),
        sourcePosition: HandlePosition.left,
        targetPosition: HandlePosition.right,
      );
      expect(path.computeMetrics().isNotEmpty, isTrue);
    });

    test('non-matching target positions', () {
      final path = StepEdge.buildPath(
        const Offset(50, 50), const Offset(200, 200),
        sourcePosition: HandlePosition.bottom,
        targetPosition: HandlePosition.right,
      );
      expect(path.computeMetrics().isNotEmpty, isTrue);
    });

    test('midpoint returns center', () {
      final mid = StepEdge.midpoint(const Offset(0, 0), const Offset(100, 200));
      expect(mid, const Offset(50, 100));
    });

    test('same source and target produces valid path', () {
      const point = Offset(50, 50);
      final path = StepEdge.buildPath(
        point, point,
        sourcePosition: HandlePosition.bottom,
        targetPosition: HandlePosition.top,
      );
      expect(path, isNotNull);
    });

    test('custom offset changes path length', () {
      const source = Offset(50, 50);
      const target = Offset(200, 200);

      final path1 = StepEdge.buildPath(
        source, target,
        sourcePosition: HandlePosition.right,
        targetPosition: HandlePosition.left,
        offset: 10.0,
      );
      final path2 = StepEdge.buildPath(
        source, target,
        sourcePosition: HandlePosition.right,
        targetPosition: HandlePosition.left,
        offset: 200.0,
      );

      expect(path1.computeMetrics().isNotEmpty, isTrue);
      expect(path2.computeMetrics().isNotEmpty, isTrue);
      expect(
        path1.computeMetrics().first.length,
        isNot(path2.computeMetrics().first.length),
      );
    });
  });

  group('EdgeType', () {
    test('has step variant', () {
      expect(EdgeType.values.contains(EdgeType.step), isTrue);
    });

    test('fromString parses step', () {
      expect(EdgeType.fromString('step'), EdgeType.step);
    });

    test('fromString defaults to bezier for unknown', () {
      expect(EdgeType.fromString('unknown'), EdgeType.bezier);
    });

    test('all expected values present', () {
      expect(EdgeType.values, containsAll([
        EdgeType.bezier, EdgeType.smoothStep, EdgeType.step, EdgeType.straight,
      ]));
    });
  });
}
