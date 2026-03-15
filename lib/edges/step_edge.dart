import 'dart:math' as math;
import 'dart:ui';

import 'package:flowcraft/core/enums/handle_position.dart';

/// Computes a step (right-angle with sharp corners) [Path].
///
/// Similar to [SmoothStepEdge] but without rounded corners.
class StepEdge {
  /// Builds a step path from [source] to [target].
  ///
  /// The path consists of horizontal/vertical segments
  /// with sharp 90° corners at the bends.
  static Path buildPath(
    Offset source,
    Offset target, {
    HandlePosition sourcePosition = HandlePosition.bottom,
    HandlePosition targetPosition = HandlePosition.top,
    double offset = 25.0,
  }) {
    final path = Path();
    path.moveTo(source.dx, source.dy);

    final waypoints = _computeWaypoints(
      source,
      target,
      sourcePosition,
      targetPosition,
      offset,
    );

    for (final wp in waypoints) {
      path.lineTo(wp.dx, wp.dy);
    }

    path.lineTo(target.dx, target.dy);
    return path;
  }

  static List<Offset> _computeWaypoints(
    Offset source,
    Offset target,
    HandlePosition sourcePos,
    HandlePosition targetPos,
    double offset,
  ) {
    final waypoints = <Offset>[];

    switch (sourcePos) {
      case HandlePosition.bottom:
        final midY = source.dy + (target.dy - source.dy) / 2;
        if (targetPos == HandlePosition.top) {
          final actualMidY = math.max(midY, source.dy + offset);
          waypoints.add(Offset(source.dx, actualMidY));
          waypoints.add(Offset(target.dx, actualMidY));
        } else {
          waypoints.add(Offset(source.dx, source.dy + offset));
          waypoints.add(Offset(target.dx, source.dy + offset));
        }
        break;
      case HandlePosition.top:
        final midY = target.dy + (source.dy - target.dy) / 2;
        if (targetPos == HandlePosition.bottom) {
          final actualMidY = math.min(midY, source.dy - offset);
          waypoints.add(Offset(source.dx, actualMidY));
          waypoints.add(Offset(target.dx, actualMidY));
        } else {
          waypoints.add(Offset(source.dx, source.dy - offset));
          waypoints.add(Offset(target.dx, source.dy - offset));
        }
        break;
      case HandlePosition.right:
        final midX = source.dx + (target.dx - source.dx) / 2;
        if (targetPos == HandlePosition.left) {
          final actualMidX = math.max(midX, source.dx + offset);
          waypoints.add(Offset(actualMidX, source.dy));
          waypoints.add(Offset(actualMidX, target.dy));
        } else {
          waypoints.add(Offset(source.dx + offset, source.dy));
          waypoints.add(Offset(source.dx + offset, target.dy));
        }
        break;
      case HandlePosition.left:
        final midX = target.dx + (source.dx - target.dx) / 2;
        if (targetPos == HandlePosition.right) {
          final actualMidX = math.min(midX, source.dx - offset);
          waypoints.add(Offset(actualMidX, source.dy));
          waypoints.add(Offset(actualMidX, target.dy));
        } else {
          waypoints.add(Offset(source.dx - offset, source.dy));
          waypoints.add(Offset(source.dx - offset, target.dy));
        }
        break;
    }

    return waypoints;
  }

  /// Returns the midpoint for label placement.
  static Offset midpoint(Offset source, Offset target) {
    return Offset(
      (source.dx + target.dx) / 2,
      (source.dy + target.dy) / 2,
    );
  }
}
