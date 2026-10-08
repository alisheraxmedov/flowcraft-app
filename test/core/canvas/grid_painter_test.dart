import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/core/theme/fc_tokens.dart';

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

  test('dot paint matches the mockup token alpha and 1.2px radius at 1x', () {
    for (final dot in [FcTokens.light.dot, FcTokens.dark.dot]) {
      final p = GridPainter(viewport: const FlowViewport(), gridColor: dot);
      expect(p.dotRadius, 1.2);
      expect(p.gridOpacity, 1.0);
      // Painted alpha = token alpha * gridOpacity * zoom clamp (1 at 1x).
      expect(dot.a * p.gridOpacity, closeTo(dot.a, 1e-9));
    }
    expect(FcTokens.light.dot.a, closeTo(0.2, 0.01));
    expect(FcTokens.dark.dot.a, closeTo(0.1, 0.01));
  });
}
