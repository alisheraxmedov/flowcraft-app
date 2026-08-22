import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/core/canvas/grid_painter.dart';
import 'package:flowcraft/models/flow_viewport.dart';

void main() {
  group('GridPainter.shouldRepaint', () {
    GridPainter painter({
      double spacing = 20,
      double dotRadius = 1.5,
      FlowViewport viewport = const FlowViewport(),
    }) => GridPainter(
      viewport: viewport,
      gridSpacing: spacing,
      dotRadius: dotRadius,
    );

    test('is false for an identical configuration', () {
      expect(painter().shouldRepaint(painter()), isFalse);
    });

    test('repaints when the spacing changes', () {
      expect(painter(spacing: 40).shouldRepaint(painter(spacing: 20)), isTrue);
    });

    test('repaints when the dot radius changes', () {
      expect(painter(dotRadius: 3).shouldRepaint(painter()), isTrue);
    });

    test('repaints when the viewport moves or zooms', () {
      expect(
        painter(
          viewport: const FlowViewport(offset: Offset(5, 0)),
        ).shouldRepaint(painter()),
        isTrue,
      );
      expect(
        painter(viewport: const FlowViewport(zoom: 2)).shouldRepaint(painter()),
        isTrue,
      );
    });
  });
}
