import 'dart:ui' show Offset;

/// Orthogonal routing for elbowed arrows.
///
/// The route is derived from the two endpoints on every read and never
/// stored, so a bound arrow that follows its shapes re-routes for free.
/// ponytail: no obstacle avoidance — the route ignores other shapes; add
/// a grid/visibility-graph router if overlap with unrelated shapes matters.
class ElbowRouter {
  const ElbowRouter._();

  /// Polyline from [a] to [b] with right-angle bends at the midpoint of the
  /// dominant axis: horizontal-vertical-horizontal when `|dx| >= |dy|`,
  /// vertical-horizontal-vertical otherwise. Endpoints already on one line
  /// need no bend and come back as just `[a, b]`.
  static List<Offset> route(Offset a, Offset b) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    if (dx.abs() >= dy.abs()) {
      if (dy == 0) return [a, b];
      final mid = a.dx + dx / 2;
      return [a, Offset(mid, a.dy), Offset(mid, b.dy), b];
    }
    if (dx == 0) return [a, b];
    final mid = a.dy + dy / 2;
    return [a, Offset(a.dx, mid), Offset(b.dx, mid), b];
  }
}
