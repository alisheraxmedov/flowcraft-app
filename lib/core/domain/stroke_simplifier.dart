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
  /// O(n log n) on a typical stroke, O(n²) in the worst case — but never
  /// deep: the split ranges are worked off an explicit stack rather than
  /// by recursion. The recursive form's depth was the number of points on
  /// a stroke whose farthest point is always next to an endpoint (a tight
  /// spiral, a staircase), and this runs on the UI thread at pointer-up for
  /// every freedraw and again on every save, where a multi-thousand-point
  /// scribble from a 120 Hz input is the normal case, not the edge.
  static List<Offset> simplify(List<Offset> points, {double tolerance = 0.5}) {
    if (points.length < 3 || tolerance <= 0) {
      return List<Offset>.unmodifiable(points);
    }

    final keep = List<bool>.filled(points.length, false);
    keep[0] = true;
    keep[points.length - 1] = true;

    _rdp(points, tolerance, keep);

    final result = <Offset>[];
    for (var i = 0; i < points.length; i++) {
      if (keep[i]) result.add(points[i]);
    }
    return List<Offset>.unmodifiable(result);
  }

  /// Marks in [keep] every point RDP retains, over the whole of [points].
  ///
  /// Ranges still to be examined live on [stack] as `(start, end)` pairs;
  /// a range is split at its farthest point when that point is further than
  /// [tolerance] from the chord, and both halves are pushed back.
  static void _rdp(List<Offset> points, double tolerance, List<bool> keep) {
    final stack = <(int, int)>[(0, points.length - 1)];

    while (stack.isNotEmpty) {
      final (start, end) = stack.removeLast();
      if (end <= start + 1) continue;

      double maxDist = 0;
      var idx = start;
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
        stack.add((start, idx));
        stack.add((idx, end));
      }
    }
  }
}
