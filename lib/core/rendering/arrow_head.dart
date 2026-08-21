import 'dart:math' as math;

import 'package:flutter/rendering.dart';

/// Shared geometry for the filled triangular arrow-head drawn at the end
/// of an arrow.
///
/// Used by both [SketchPainter] (committed arrows) and
/// [SketchPreviewPainter] (in-progress arrow preview) so the two stay
/// visually identical instead of drifting apart as separately-maintained
/// copies of the same formula.
class ArrowHead {
  ArrowHead._();

  /// Builds the closed triangle path for an arrow-head pointing from
  /// [start] toward [end], with wingspan proportional to [size].
  static Path path(Offset start, Offset end, double size) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final angle = math.atan2(dy, dx);
    final left = Offset(
      end.dx - size * math.cos(angle - 0.5),
      end.dy - size * math.sin(angle - 0.5),
    );
    final right = Offset(
      end.dx - size * math.cos(angle + 0.5),
      end.dy - size * math.sin(angle + 0.5),
    );
    return Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
  }
}
