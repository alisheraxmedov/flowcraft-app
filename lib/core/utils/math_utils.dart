import 'dart:math' as math;
import 'dart:ui';

/// Mathematical utilities for edge path calculations
/// and coordinate transforms.
class MathUtils {
  /// Calculates the cubic bezier control points for an edge going
  /// from [source] handle position to [target] handle position.
  ///
  /// The [sourceDirection] and [targetDirection] indicate the direction
  /// the handle faces (e.g., bottom → downward vector).
  static List<Offset> bezierControlPoints(
    Offset source,
    Offset target, {
    Offset sourceDirection = const Offset(0, 1),
    Offset targetDirection = const Offset(0, -1),
  }) {
    final dx = (target.dx - source.dx).abs();
    final dy = (target.dy - source.dy).abs();
    final distance = math.max(dx, dy);
    final controlDistance = math.max(distance * 0.5, 50.0);

    final cp1 = Offset(
      source.dx + sourceDirection.dx * controlDistance,
      source.dy + sourceDirection.dy * controlDistance,
    );
    final cp2 = Offset(
      target.dx + targetDirection.dx * controlDistance,
      target.dy + targetDirection.dy * controlDistance,
    );
    return [cp1, cp2];
  }

  /// Returns the direction vector for a handle position.
  static Offset handleDirection(String position) {
    switch (position) {
      case 'top':
        return const Offset(0, -1);
      case 'bottom':
        return const Offset(0, 1);
      case 'left':
        return const Offset(-1, 0);
      case 'right':
        return const Offset(1, 0);
      default:
        return const Offset(0, 1);
    }
  }

  /// Linearly interpolates between two offsets.
  static Offset lerpOffset(Offset a, Offset b, double t) {
    return Offset(
      a.dx + (b.dx - a.dx) * t,
      a.dy + (b.dy - a.dy) * t,
    );
  }

  /// Calculates the midpoint of a cubic bezier curve.
  static Offset bezierMidpoint(
      Offset p0, Offset p1, Offset p2, Offset p3) {
    const t = 0.5;
    final u = 1 - t;
    return Offset(
      u * u * u * p0.dx +
          3 * u * u * t * p1.dx +
          3 * u * t * t * p2.dx +
          t * t * t * p3.dx,
      u * u * u * p0.dy +
          3 * u * u * t * p1.dy +
          3 * u * t * t * p2.dy +
          t * t * t * p3.dy,
    );
  }

  /// Clamps a value between [min] and [max].
  static double clampDouble(double value, double min, double max) {
    if (value < min) return min;
    if (value > max) return max;
    return value;
  }

  /// Calculates the distance between two points.
  static double distance(Offset a, Offset b) {
    final dx = a.dx - b.dx;
    final dy = a.dy - b.dy;
    return math.sqrt(dx * dx + dy * dy);
  }

  /// Returns the bounding rect that contains all given offsets with padding.
  static Rect boundingRect(List<Offset> points, {double padding = 50}) {
    if (points.isEmpty) return Rect.zero;

    double minX = points.first.dx;
    double minY = points.first.dy;
    double maxX = points.first.dx;
    double maxY = points.first.dy;

    for (final p in points) {
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }

    return Rect.fromLTRB(
      minX - padding,
      minY - padding,
      maxX + padding,
      maxY + padding,
    );
  }
}
