import 'dart:math' as math;
import 'dart:ui';

import 'package:flowcraft/core/enums/handle_position.dart';

/// Computes a smooth step (right-angle with rounded corners) [Path].
class SmoothStepEdge {
  /// Builds a smooth-step path from [source] to [target].
  ///
  /// The path consists of horizontal/vertical segments with
  /// optional rounded corners at the bends.
  static Path buildPath(
    Offset source,
    Offset target, {
    HandlePosition sourcePosition = HandlePosition.bottom,
    HandlePosition targetPosition = HandlePosition.top,
    double borderRadius = 8.0,
    double offset = 25.0,
  }) {
    final path = Path();
    path.moveTo(source.dx, source.dy);

    // Calculate intermediate waypoints based on handle positions
    final waypoints = _computeWaypoints(
      source,
      target,
      sourcePosition,
      targetPosition,
      offset,
    );

    if (waypoints.isEmpty) {
      path.lineTo(target.dx, target.dy);
      return path;
    }

    // Draw segments with rounded corners
    Offset current = source;
    for (int i = 0; i < waypoints.length; i++) {
      final next = waypoints[i];
      final afterNext =
          i < waypoints.length - 1 ? waypoints[i + 1] : target;

      _addRoundedSegment(path, current, next, afterNext, borderRadius);
      current = next;
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
          // Simple case: bottom → top
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

  static void _addRoundedSegment(
    Path path,
    Offset from,
    Offset corner,
    Offset to,
    double radius,
  ) {
    // Compute the distance to the corner in each direction
    final dx1 = corner.dx - from.dx;
    final dy1 = corner.dy - from.dy;
    final dx2 = to.dx - corner.dx;
    final dy2 = to.dy - corner.dy;

    final dist1 = math.sqrt(dx1 * dx1 + dy1 * dy1);
    final dist2 = math.sqrt(dx2 * dx2 + dy2 * dy2);

    if (dist1 < 0.01 || dist2 < 0.01) {
      path.lineTo(corner.dx, corner.dy);
      return;
    }

    // Clamp radius to half the minimum segment length
    final r = math.min(radius, math.min(dist1, dist2) / 2);

    // Point just before the corner
    final before = Offset(
      corner.dx - (dx1 / dist1) * r,
      corner.dy - (dy1 / dist1) * r,
    );

    // Point just after the corner
    final after = Offset(
      corner.dx + (dx2 / dist2) * r,
      corner.dy + (dy2 / dist2) * r,
    );

    path.lineTo(before.dx, before.dy);
    path.quadraticBezierTo(corner.dx, corner.dy, after.dx, after.dy);
  }

  /// Returns the midpoint (center of the path) for label placement.
  static Offset midpoint(Offset source, Offset target) {
    return Offset(
      (source.dx + target.dx) / 2,
      (source.dy + target.dy) / 2,
    );
  }
}
