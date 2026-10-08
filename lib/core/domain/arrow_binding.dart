import 'dart:math' as math;
import 'dart:ui' show Offset;

import 'package:flowcraft/core/domain/sketch_geometry.dart';
import 'package:flowcraft/models/sketch_element.dart';

/// Pure geometry behind arrow-to-shape binding: which shapes an arrow can
/// attach to, where on their outline it lands, and how a bound arrow is
/// re-anchored after the scene changes.
///
/// Statics only and no controller dependency, so `SketchController` can call
/// [resolve] from its single paint-bump choke point and tests can drive it
/// with plain element maps.
class ArrowBinding {
  const ArrowBinding._();

  /// Bisection steps along the ray. 30 halvings of a shape-sized interval is
  /// far below a hundredth of a pixel, so the result reads as exact.
  static const int _steps = 30;

  /// Whether an arrow may attach to [e]. Lines, text, freedraw and other
  /// arrows are not targets: they have no enclosed area to leave a ray from.
  static bool isBindable(SketchElement e) =>
      e is SketchRectangle ||
      e is SketchEllipse ||
      e is SketchDiamond ||
      e is SketchTriangle ||
      e is SketchSticky;

  /// Topmost bindable element whose bounds, grown by [tolerance], contain
  /// [point], skipping the element with id [exclude].
  static SketchElement? targetAt(
    List<SketchElement> els,
    Offset point,
    double tolerance, {
    String? exclude,
  }) {
    for (var i = els.length - 1; i >= 0; i--) {
      final el = els[i];
      if (el.id == exclude || !isBindable(el)) continue;
      if (el.bounds.inflate(tolerance).contains(point)) return el;
    }
    return null;
  }

  /// Whether [p] is inside [shape]'s true outline (not its bounding box).
  static bool _contains(SketchElement shape, Offset p) {
    final r = shape.unrotatedBounds;
    final a = shape.angle;
    return switch (shape) {
      SketchEllipse() => SketchGeometry.pointInEllipse(p, r, a),
      SketchDiamond() => SketchGeometry.pointInDiamond(p, r, a),
      SketchTriangle() => SketchGeometry.pointInTriangle(p, r, a),
      // Rectangle, and a sticky — whose unrotatedBounds is the badge when
      // collapsed, so the arrow re-routes to what is actually drawn.
      _ => SketchGeometry.pointInRotatedRect(p, r, a),
    };
  }

  /// Where the ray from [shape]'s centre toward [toward] leaves its outline,
  /// pushed [gap] further out along that ray.
  ///
  /// Found by bisection over the existing `pointIn*` predicates rather than a
  /// closed form per shape: one routine, exact for all four outlines, and
  /// rotation-aware for free. The ray starts at the centre, so an [toward]
  /// that lies inside the shape still exits through the boundary. Returns the
  /// centre when [toward] is the centre (no direction to leave in).
  static Offset boundaryPoint(
    SketchElement shape,
    Offset toward, {
    double gap = 0,
  }) {
    final box = shape.unrotatedBounds;
    final centre = box.center;
    final delta = toward - centre;
    if (delta == Offset.zero) return centre;
    final dir = delta / delta.distance;
    var lo = 0.0;
    // The full diagonal comfortably exceeds any outline's reach from centre.
    var hi = math.sqrt(box.width * box.width + box.height * box.height);
    for (var i = 0; i < _steps; i++) {
      final mid = (lo + hi) / 2;
      if (_contains(shape, centre + dir * mid)) {
        lo = mid;
      } else {
        hi = mid;
      }
    }
    return centre + dir * ((lo + hi) / 2 + gap);
  }

  /// [arrow] with its bindings validated against [byId] and its bound ends
  /// re-anchored on the shapes' outlines. Returns the identical instance
  /// when nothing changes, so callers can detect a no-op by identity.
  ///
  /// A binding to a missing or non-bindable element is cleared (the endpoint
  /// stays where it was), and when both ends name the same shape the end
  /// binding is dropped — a loop onto one shape has no direction to aim.
  /// An end aims at the centre of the other end's shape if that end is
  /// bound, else at the other end's stored point, which keeps the result
  /// independent of evaluation order.
  ///
  /// `SketchBinding.focus` is reserved and ignored (always aims at the
  /// centre); `gap` is honoured.
  static SketchArrow resolve(
    SketchArrow arrow,
    Map<String, SketchElement> byId,
  ) {
    final sb = arrow.startBinding;
    final eb = arrow.endBinding;
    if (sb == null && eb == null) return arrow;
    // ponytail: a rotated arrow's stored points are pre-rotation, so
    // re-anchoring them would need the inverse rotation; left alone until
    // something can actually produce one.
    if (arrow.angle != 0.0) return arrow;

    SketchElement? target(SketchBinding? b) {
      final el = b == null ? null : byId[b.elementId];
      return el != null && isBindable(el) ? el : null;
    }

    final startShape = target(sb);
    var endShape = target(eb);
    if (startShape != null &&
        endShape != null &&
        sb!.elementId == eb!.elementId) {
      endShape = null;
    }
    final newSb = startShape == null ? null : sb;
    final newEb = endShape == null ? null : eb;

    final start = startShape == null
        ? arrow.start
        : boundaryPoint(
            startShape,
            endShape?.unrotatedBounds.center ?? arrow.end,
            gap: sb!.gap,
          );
    final end = endShape == null
        ? arrow.end
        : boundaryPoint(
            endShape,
            startShape?.unrotatedBounds.center ?? arrow.start,
            gap: eb!.gap,
          );

    if (start == arrow.start &&
        end == arrow.end &&
        newSb == sb &&
        newEb == eb) {
      return arrow;
    }
    return arrow.copyWith(
      start: start,
      end: end,
      startBinding: newSb,
      endBinding: newEb,
    );
  }
}
