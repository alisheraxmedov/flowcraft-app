import 'dart:ui';

import 'package:flowcraft/core/domain/sketch_geometry.dart';

/// Polyline simplification utilities.
///
/// Use [simplify] to reduce point count of a freedraw stroke before
/// persisting or rendering. The default tolerance of 0.5 canvas-space
/// pixels is virtually invisible while typically cutting point counts
/// by 60–90%.
class StrokeSimplifier {
  StrokeSimplifier._();

  /// Ramer–Douglas–Peucker simplification. Returns a new list containing
  /// a subset of [points] approximating the original within [tolerance].
  ///
  /// O(n log n) average case.
  static List<Offset> simplify(
    List<Offset> points, {
    double tolerance = 0.5,
  }) {
    if (points.length < 3 || tolerance <= 0) {
      return List<Offset>.unmodifiable(points);
    }

    final keep = List<bool>.filled(points.length, false);
    keep[0] = true;
    keep[points.length - 1] = true;

    _rdp(points, 0, points.length - 1, tolerance, keep);

    final result = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      if (keep[i]) result.add(points[i]);
    }
    return List<Offset>.unmodifiable(result);
  }

  static void _rdp(
    List<Offset> points,
    int start,
    int end,
    double tolerance,
    List<bool> keep,
  ) {
    if (end <= start + 1) return;

    double maxDist = 0;
    int idx = start;
    final a = points[start];
    final b = points[end];

    for (var i = start + 1; i < end; i++) {
      final d = SketchGeometry.distanceToSegment(points[i], a, b);
      if (d > maxDist) {
        maxDist = d;
        idx = i;
      }
    }

    if (maxDist > tolerance) {
      keep[idx] = true;
      _rdp(points, start, idx, tolerance, keep);
      _rdp(points, idx, end, tolerance, keep);
    }
  }

  /// Catmull–Rom spline interpolation. Inserts [subdivisions] points
  /// between each pair of input control points, producing a smoother
  /// curve suitable for rendering.
  static List<Offset> smooth(
    List<Offset> points, {
    int subdivisions = 4,
    double tension = 0.5,
  }) {
    if (points.length < 2 || subdivisions <= 0) {
      return List<Offset>.unmodifiable(points);
    }
    if (points.length == 2) {
      return List<Offset>.unmodifiable(points);
    }

    final result = <Offset>[points.first];
    for (var i = 0; i < points.length - 1; i++) {
      final p0 = i == 0 ? points[i] : points[i - 1];
      final p1 = points[i];
      final p2 = points[i + 1];
      final p3 = i + 2 < points.length ? points[i + 2] : points[i + 1];

      for (var j = 1; j <= subdivisions; j++) {
        final t = j / (subdivisions + 1);
        result.add(_catmull(p0, p1, p2, p3, t, tension));
      }
      result.add(p2);
    }
    return List<Offset>.unmodifiable(result);
  }

  static Offset _catmull(
    Offset p0,
    Offset p1,
    Offset p2,
    Offset p3,
    double t,
    double tension,
  ) {
    final t2 = t * t;
    final t3 = t2 * t;
    final a = (-tension * t3 + 2 * tension * t2 - tension * t);
    final b = ((2 - tension) * t3 + (tension - 3) * t2 + 1);
    final c = ((tension - 2) * t3 + (3 - 2 * tension) * t2 + tension * t);
    final d = (tension * t3 - tension * t2);
    return Offset(
      a * p0.dx + b * p1.dx + c * p2.dx + d * p3.dx,
      a * p0.dy + b * p1.dy + c * p2.dy + d * p3.dy,
    );
  }
}
