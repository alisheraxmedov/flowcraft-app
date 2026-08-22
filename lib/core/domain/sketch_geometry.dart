import 'dart:math' as math;
import 'dart:ui';

/// One of the eight grab points on a selection box.
///
/// Ordered clockwise from the top-left, so iterating [values] gives the
/// painter a stable draw order and the hit test a stable tie-break — when
/// two handles sit exactly the same distance from the pointer, the earlier
/// one in this order wins.
enum ResizeHandle {
  topLeft,
  top,
  topRight,
  right,
  bottomRight,
  bottom,
  bottomLeft,
  left;

  /// Corners drive both axes, which is what an aspect-ratio lock needs. An
  /// edge handle moves a single edge, so there is no second axis to
  /// constrain and the lock is a no-op on it.
  bool get isCorner =>
      this == topLeft ||
      this == topRight ||
      this == bottomRight ||
      this == bottomLeft;

  bool get movesLeft => this == topLeft || this == left || this == bottomLeft;
  bool get movesRight =>
      this == topRight || this == right || this == bottomRight;
  bool get movesTop => this == topLeft || this == top || this == topRight;
  bool get movesBottom =>
      this == bottomLeft || this == bottom || this == bottomRight;
}

/// Pure geometric helpers used by hit-testing, gesture handling, and tests.
///
/// All functions are deterministic and free of Flutter framework deps.
class SketchGeometry {
  SketchGeometry._();

  /// Screen-space padding between an element's bounds and the selection box
  /// drawn around it.
  ///
  /// Shared by the painter and the gesture handler on purpose: the handles
  /// are placed on the *padded* box, so hit-testing against the unpadded
  /// bounds would grab a handle a few pixels from the one under the cursor.
  static const double selectionPadding = 4.0;

  /// Centre of [handle] on [rect]. Feed it a screen-space rect to get a
  /// screen-space handle position, which is how both callers use it —
  /// handles are a constant size on screen, not in canvas units.
  static Offset handlePosition(Rect rect, ResizeHandle handle) =>
      switch (handle) {
        ResizeHandle.topLeft => rect.topLeft,
        ResizeHandle.top => rect.topCenter,
        ResizeHandle.topRight => rect.topRight,
        ResizeHandle.right => rect.centerRight,
        ResizeHandle.bottomRight => rect.bottomRight,
        ResizeHandle.bottom => rect.bottomCenter,
        ResizeHandle.bottomLeft => rect.bottomLeft,
        ResizeHandle.left => rect.centerLeft,
      };

  /// [start] resized by dragging [handle] through [delta].
  ///
  /// The edge opposite the grabbed handle anchors and never moves, so a
  /// top-left drag grows the shape up and left while a bottom-right drag
  /// grows it down and right.
  ///
  /// Dragging a handle past its anchor **clamps** at [minSize] rather than
  /// flipping the rect. A flip hands the pointer a different handle
  /// mid-drag — the one it grabbed is now on the far side — so the shape
  /// oscillates around the crossing point; and for shapes that have an
  /// orientation (a triangle's apex, a sticky's top-left text inset) it
  /// silently mirrors content nobody asked to mirror.
  ///
  /// [preserveAspect] holds [start]'s width:height ratio and applies to
  /// corner handles only.
  static Rect resizeRect(
    Rect start,
    ResizeHandle handle,
    Offset delta, {
    double minSize = 10.0,
    bool preserveAspect = false,
  }) {
    var left = start.left;
    var top = start.top;
    var right = start.right;
    var bottom = start.bottom;
    if (handle.movesLeft) left += delta.dx;
    if (handle.movesRight) right += delta.dx;
    if (handle.movesTop) top += delta.dy;
    if (handle.movesBottom) bottom += delta.dy;

    var width = right - left;
    var height = bottom - top;
    // Only the axes this handle actually drives get the floor applied —
    // otherwise dragging the top edge of an already-thinner-than-minSize
    // shape would silently widen it.
    final movesX = handle.movesLeft || handle.movesRight;
    final movesY = handle.movesTop || handle.movesBottom;
    if (movesX) width = math.max(width, minSize);
    if (movesY) height = math.max(height, minSize);

    if (preserveAspect &&
        handle.isCorner &&
        start.width > 0 &&
        start.height > 0) {
      final ratio = start.height / start.width;
      // Follow whichever axis the pointer took further, so the shape grows
      // with the drag instead of being held back by the lagging axis.
      if (width * ratio >= height) {
        height = width * ratio;
      } else {
        width = height / ratio;
      }
      // The floor wins when it disagrees with the ratio: a shape below
      // minSize is unusable, a slightly-off ratio is not.
      width = math.max(width, minSize);
      height = math.max(height, minSize);
    }

    // Re-derive each moving edge from its anchor.
    if (handle.movesLeft) {
      left = right - width;
    } else {
      right = left + width;
    }
    if (handle.movesTop) {
      top = bottom - height;
    } else {
      bottom = top + height;
    }
    return Rect.fromLTRB(left, top, right, bottom);
  }

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

  /// True iff [a] and [b] touch, counting a shared edge as touching.
  ///
  /// [Rect.overlaps] requires the intersection to enclose area, so it calls
  /// rects that meet exactly along an edge disjoint. That is already the
  /// wrong answer for a rubber band, and it bites hardest on the bounds of
  /// an axis-aligned line or arrow, which are *nothing but* such an edge: a
  /// band drawn flush along the stroke misses it even though it visibly
  /// covers it.
  static bool rectsTouch(Rect a, Rect b) =>
      a.left <= b.right &&
      b.left <= a.right &&
      a.top <= b.bottom &&
      b.top <= a.bottom;

  /// True iff any part of the segment [a]–[b] lies inside [rect].
  ///
  /// Liang–Barsky slab clipping: narrow the parameter window `t ∈ [0,1]`
  /// against each edge in turn, and whatever survives is the part of the
  /// segment inside the rect. Preferred over four edge-crossing tests
  /// because it needs no special case for a segment running parallel to an
  /// edge — which is precisely the axis-aligned connector this exists for —
  /// nor for a degenerate rect or a zero-length segment, which it resolves
  /// to a plain inclusive point-in-rect test.
  static bool segmentIntersectsRect(Offset a, Offset b, Rect rect) {
    final dx = b.dx - a.dx;
    final dy = b.dy - a.dy;
    var tMin = 0.0;
    var tMax = 1.0;

    for (var edge = 0; edge < 4; edge++) {
      final p = switch (edge) {
        0 => -dx,
        1 => dx,
        2 => -dy,
        _ => dy,
      };
      final q = switch (edge) {
        0 => a.dx - rect.left,
        1 => rect.right - a.dx,
        2 => a.dy - rect.top,
        _ => rect.bottom - a.dy,
      };
      if (p == 0) {
        // Parallel to this edge: the whole segment is on one side of it, so
        // starting outside means it never gets in.
        if (q < 0) return false;
        continue;
      }
      final t = q / p;
      if (p < 0) {
        if (t > tMax) return false;
        if (t > tMin) tMin = t;
      } else {
        if (t < tMin) return false;
        if (t < tMax) tMax = t;
      }
    }
    return tMin <= tMax;
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
