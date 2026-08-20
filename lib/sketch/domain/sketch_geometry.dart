import 'dart:math' as math;
import 'dart:ui';

/// Pure geometric helpers used by hit-testing, gesture handling, and tests.
///
/// All functions are deterministic and free of Flutter framework deps.
class SketchGeometry {
  SketchGeometry._();

  /// Perpendicular distance from [point] to the line segment [a]–[b].
  static double distanceToSegment(Offset point, Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    final lenSq = dx * dx + dy * dy;
    if (lenSq == 0) return (point - a).distance;

    var t = ((point.dx - a.dx) * dx + (point.dy - a.dy) * dy) / lenSq;
    t = t.clamp(0.0, 1.0);
    final proj = Offset(a.dx + t * dx, a.dy + t * dy);
    return (point - proj).distance;
  }

  /// True iff [point] lies inside the rotated rectangle [rect] (rotated by
  /// [angle] radians around its centre).
  static bool pointInRotatedRect(Offset point, Rect rect, double angle) {
    if (angle == 0.0) return rect.contains(point);
    final centre = rect.center;
    final cos = math.cos(-angle);
    final sin = math.sin(-angle);
    final dx = point.dx - centre.dx;
    final dy = point.dy - centre.dy;
    final localX = dx * cos - dy * sin + centre.dx;
    final localY = dx * sin + dy * cos + centre.dy;
    return rect.contains(Offset(localX, localY));
  }

  /// True iff [point] lies inside the axis-aligned ellipse inscribed in
  /// [rect], optionally rotated.
  static bool pointInEllipse(Offset point, Rect rect, double angle) {
    if (rect.width == 0 || rect.height == 0) return false;
    final centre = rect.center;
    final rx = rect.width / 2;
    final ry = rect.height / 2;

    double localX, localY;
    if (angle == 0.0) {
      localX = point.dx - centre.dx;
      localY = point.dy - centre.dy;
    } else {
      final cos = math.cos(-angle);
      final sin = math.sin(-angle);
      final dx = point.dx - centre.dx;
      final dy = point.dy - centre.dy;
      localX = dx * cos - dy * sin;
      localY = dx * sin + dy * cos;
    }
    final nx = localX / rx;
    final ny = localY / ry;
    return nx * nx + ny * ny <= 1.0;
  }

  /// True iff [point] lies inside the diamond (rhombus) inscribed in [rect].
  static bool pointInDiamond(Offset point, Rect rect, double angle) {
    if (rect.width == 0 || rect.height == 0) return false;
    final centre = rect.center;
    double localX, localY;
    if (angle == 0.0) {
      localX = (point.dx - centre.dx).abs();
      localY = (point.dy - centre.dy).abs();
    } else {
      final cos = math.cos(-angle);
      final sin = math.sin(-angle);
      final dx = point.dx - centre.dx;
      final dy = point.dy - centre.dy;
      localX = (dx * cos - dy * sin).abs();
      localY = (dx * sin + dy * cos).abs();
    }
    return (localX / (rect.width / 2)) + (localY / (rect.height / 2)) <= 1.0;
  }

  /// True iff [point] lies inside the isosceles triangle inscribed in
  /// [rect] (apex at top-centre, base along the bottom edge).
  static bool pointInTriangle(Offset point, Rect rect, double angle) {
    if (rect.width == 0 || rect.height == 0) return false;
    final centre = rect.center;
    double px = point.dx, py = point.dy;
    if (angle != 0.0) {
      final cos = math.cos(-angle);
      final sin = math.sin(-angle);
      final dx = point.dx - centre.dx;
      final dy = point.dy - centre.dy;
      px = dx * cos - dy * sin + centre.dx;
      py = dx * sin + dy * cos + centre.dy;
    }
    final p = Offset(px, py);
    final a = Offset(centre.dx, rect.top);
    final b = Offset(rect.left, rect.bottom);
    final c = Offset(rect.right, rect.bottom);
    return _cross(p, a, b) >= 0 && _cross(p, b, c) >= 0 && _cross(p, c, a) >= 0;
  }

  /// Signed cross product used by [pointInTriangle]. Positive when [p] is
  /// to the left of the directed edge [a]→[b].
  static double _cross(Offset p, Offset a, Offset b) =>
      (p.dx - b.dx) * (a.dy - b.dy) - (a.dx - b.dx) * (p.dy - b.dy);

  /// True iff [point] is within [tolerance] pixels of any segment in the
  /// polyline defined by [points].
  static bool pointNearPolyline(
    Offset point,
    List<Offset> points,
    double tolerance,
  ) {
    if (points.isEmpty) return false;
    if (points.length == 1) return (point - points.first).distance <= tolerance;
    for (var i = 0; i < points.length - 1; i++) {
      if (distanceToSegment(point, points[i], points[i + 1]) <= tolerance) {
        return true;
      }
    }
    return false;
  }

  /// Inflates a rect by [margin] on every side.
  static Rect inflate(Rect rect, double margin) => Rect.fromLTRB(
        rect.left - margin,
        rect.top - margin,
        rect.right + margin,
        rect.bottom + margin,
      );

  /// Computes the bounding rect of a list of points.
  /// Returns [Rect.zero] for empty input.
  static Rect boundsOfPoints(List<Offset> points) {
    if (points.isEmpty) return Rect.zero;
    double minX = points.first.dx, minY = points.first.dy;
    double maxX = minX, maxY = minY;
    for (var i = 1; i < points.length; i++) {
      final p = points[i];
      if (p.dx < minX) minX = p.dx;
      if (p.dy < minY) minY = p.dy;
      if (p.dx > maxX) maxX = p.dx;
      if (p.dy > maxY) maxY = p.dy;
    }
    return Rect.fromLTRB(minX, minY, maxX, maxY);
  }
}
