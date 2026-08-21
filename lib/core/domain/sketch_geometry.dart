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

  /// Rotates [point] by `-angle` radians around [centre] and returns the
  /// offset of the result *relative to* [centre] (i.e. `rotated - centre`).
  ///
  /// This is the shared "unrotate into local space" step behind every
  /// `pointInX` test below — each just interprets the resulting delta
  /// differently (added back to `centre` for absolute-space tests,
  /// normalised by radius for ellipse/diamond tests, etc).
  static Offset _rotatedDelta(Offset point, Offset centre, double angle) {
    final cos = math.cos(-angle);
    final sin = math.sin(-angle);
    final dx = point.dx - centre.dx;
    final dy = point.dy - centre.dy;
    return Offset(dx * cos - dy * sin, dx * sin + dy * cos);
  }

  /// True iff [point] lies inside the rotated rectangle [rect] (rotated by
  /// [angle] radians around its centre).
  static bool pointInRotatedRect(Offset point, Rect rect, double angle) {
    if (angle == 0.0) return rect.contains(point);
    final local = _rotatedDelta(point, rect.center, angle) + rect.center;
    return rect.contains(local);
  }

  /// True iff [point] lies inside the axis-aligned ellipse inscribed in
  /// [rect], optionally rotated.
  static bool pointInEllipse(Offset point, Rect rect, double angle) {
    if (rect.width == 0 || rect.height == 0) return false;
    final centre = rect.center;
    final rx = rect.width / 2;
    final ry = rect.height / 2;

    final local = angle == 0.0
        ? point - centre
        : _rotatedDelta(point, centre, angle);
    final nx = local.dx / rx;
    final ny = local.dy / ry;
    return nx * nx + ny * ny <= 1.0;
  }

  /// True iff [point] lies inside the diamond (rhombus) inscribed in [rect].
  static bool pointInDiamond(Offset point, Rect rect, double angle) {
    if (rect.width == 0 || rect.height == 0) return false;
    final centre = rect.center;
    final local = angle == 0.0
        ? point - centre
        : _rotatedDelta(point, centre, angle);
    final localX = local.dx.abs();
    final localY = local.dy.abs();
    return (localX / (rect.width / 2)) + (localY / (rect.height / 2)) <= 1.0;
  }

  /// True iff [point] lies inside the isosceles triangle inscribed in
  /// [rect] (apex at top-centre, base along the bottom edge).
  static bool pointInTriangle(Offset point, Rect rect, double angle) {
    if (rect.width == 0 || rect.height == 0) return false;
    final centre = rect.center;
    final p = angle == 0.0
        ? point
        : _rotatedDelta(point, centre, angle) + centre;
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
