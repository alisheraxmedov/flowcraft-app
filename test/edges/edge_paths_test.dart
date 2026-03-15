import 'package:flutter_test/flutter_test.dart';
import 'package:flowcraft/flowcraft.dart';
import 'package:flutter/widgets.dart';
import 'package:flowcraft/edges/smooth_step_edge.dart';
import 'package:flowcraft/edges/straight_edge.dart';

void main() {
  group('Edge Path Calculators', () {
    test('StraightEdge.buildPath', () {
      final source = const Offset(10, 10);
      final target = const Offset(20, 20);
      final path = StraightEdge.buildPath(source, target);
      
      expect(path.computeMetrics().isNotEmpty, isTrue);
      // Ensure it starts at source
      final bounds = path.getBounds();
      expect(bounds.width, 10.0);
      expect(bounds.height, 10.0);
    });

    test('SmoothStepEdge.buildPath horizontally', () {
      final source = const Offset(10, 10);
      final target = const Offset(100, 50);
      final path = SmoothStepEdge.buildPath(
        source,
        target,
        sourcePosition: HandlePosition.right,
        targetPosition: HandlePosition.left,
      );
      
      expect(path.computeMetrics().isNotEmpty, isTrue);
    });

    test('SmoothStepEdge.buildPath vertically', () {
      final source = const Offset(10, 10);
      final target = const Offset(50, 100);
      final path = SmoothStepEdge.buildPath(
        source,
        target,
        sourcePosition: HandlePosition.bottom,
        targetPosition: HandlePosition.top,
      );
      
      expect(path.computeMetrics().isNotEmpty, isTrue);
    });
  });
}
