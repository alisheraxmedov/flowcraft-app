import 'dart:ui';

import 'package:flowcraft/core/enums/handle_position.dart';
import 'package:flowcraft/core/utils/math_utils.dart';

/// Computes a cubic bezier [Path] between two handle positions.
class BezierEdge {
  /// Builds a bezier path from [source] to [target].
  ///
  /// The control points are automatically calculated based on the
  /// handle directions.
  static Path buildPath(
    Offset source,
    Offset target, {
    HandlePosition sourcePosition = HandlePosition.bottom,
    HandlePosition targetPosition = HandlePosition.top,
  }) {
    final sourceDir = MathUtils.handleDirection(sourcePosition.name);
    final targetDir = MathUtils.handleDirection(targetPosition.name);

    final controlPoints = MathUtils.bezierControlPoints(
      source,
      target,
      sourceDirection: sourceDir,
      targetDirection: targetDir,
    );

    final path = Path()
      ..moveTo(source.dx, source.dy)
      ..cubicTo(
        controlPoints[0].dx,
        controlPoints[0].dy,
        controlPoints[1].dx,
        controlPoints[1].dy,
        target.dx,
        target.dy,
      );

    return path;
  }

  /// Returns the midpoint of the bezier curve for label placement.
  static Offset midpoint(
    Offset source,
    Offset target, {
    HandlePosition sourcePosition = HandlePosition.bottom,
    HandlePosition targetPosition = HandlePosition.top,
  }) {
    final sourceDir = MathUtils.handleDirection(sourcePosition.name);
    final targetDir = MathUtils.handleDirection(targetPosition.name);

    final controlPoints = MathUtils.bezierControlPoints(
      source,
      target,
      sourceDirection: sourceDir,
      targetDirection: targetDir,
    );

    return MathUtils.bezierMidpoint(
      source,
      controlPoints[0],
      controlPoints[1],
      target,
    );
  }
}
