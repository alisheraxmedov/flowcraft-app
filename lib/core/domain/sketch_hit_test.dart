import 'dart:ui';

import 'package:flowcraft/core/domain/sketch_geometry.dart';
import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/models/sketch_style.dart';

/// Pure hit-test functions for sketch elements.
///
/// All coordinates are canvas-space. Tolerance is in canvas-space pixels
/// — callers should scale by viewport zoom when converting from screen
/// pixels.
class SketchHitTest {
  SketchHitTest._();

  /// Returns true if [point] hits [element], using the element's geometry
  /// and the given [tolerance] for strokes / linear shapes.
  static bool hit(SketchElement element, Offset point, double tolerance) {
    switch (element) {
      case SketchRectangle r:
        if (r.style.fillStyle != FillStyle.none) {
          return SketchGeometry.pointInRotatedRect(point, r.rect, r.angle);
        }
        return _hitStrokeRect(point, r.rect, r.angle, tolerance);
      case SketchEllipse e:
        if (e.style.fillStyle != FillStyle.none) {
          return SketchGeometry.pointInEllipse(point, e.rect, e.angle);
        }
        return _hitStrokeEllipse(point, e.rect, e.angle, tolerance);
      case SketchDiamond d:
        if (d.style.fillStyle != FillStyle.none) {
          return SketchGeometry.pointInDiamond(point, d.rect, d.angle);
        }
        return _hitStrokeDiamond(point, d.rect, d.angle, tolerance);
      case SketchTriangle tri:
        if (tri.style.fillStyle != FillStyle.none) {
          return SketchGeometry.pointInTriangle(point, tri.rect, tri.angle);
        }
        return _hitStrokeTriangle(point, tri.rect, tri.angle, tolerance);
      case SketchSticky s:
        return SketchGeometry.pointInRotatedRect(point, s.rect, s.angle);
      case SketchLine l:
        return SketchGeometry.distanceToSegment(point, l.start, l.end) <=
            tolerance;
      case SketchArrow a:
        return SketchGeometry.distanceToSegment(point, a.start, a.end) <=
            tolerance;
      case SketchFreedraw f:
        return SketchGeometry.pointNearPolyline(point, f.points, tolerance);
      case SketchText t:
        return t.bounds.inflate(tolerance).contains(point);
    }
  }

  /// First element in [elements] (iterated in reverse — topmost first)
  /// that contains [point], or `null` if none.
  static SketchElement? topMost(
    List<SketchElement> elements,
    Offset point,
    double tolerance,
  ) {
    for (var i = elements.length - 1; i >= 0; i--) {
      if (hit(elements[i], point, tolerance)) return elements[i];
    }
    return null;
  }

  /// All elements whose bounds intersect [region]. Used for marquee
  /// selection (rubber-band).
  static List<SketchElement> intersecting(
    List<SketchElement> elements,
    Rect region,
  ) {
    return [
      for (final e in elements)
        if (e.bounds.overlaps(region)) e,
    ];
  }

  /// Topmost element whose text can be edited (a [SketchText], or a shape /
  /// sticky that carries a label) and whose interior bounds, inflated by
  /// [tolerance], contain [point].
  ///
  /// Unlike [topMost], this hits the *interior* of text-bearing shapes so a
  /// user can tap the label (not just the stroke) to start editing. The
  /// tolerance matters most for a bare [SketchText]: its bounds hug the
  /// glyphs exactly, so without slack a tap a hair off a thin letter misses
  /// and the text tool creates a second text box instead of editing this one.
  static SketchElement? topMostTextTarget(
    List<SketchElement> elements,
    Offset point, {
    double tolerance = 8.0,
  }) {
    for (var i = elements.length - 1; i >= 0; i--) {
      final e = elements[i];
      final hasText = e is SketchText ||
          e is SketchSticky ||
          (e is SketchRectangle && e.text != null) ||
          (e is SketchEllipse && e.text != null) ||
          (e is SketchDiamond && e.text != null) ||
          (e is SketchTriangle && e.text != null);
      if (hasText && e.bounds.inflate(tolerance).contains(point)) return e;
    }
    return null;
  }

  // ─── internal ───────────────────────────────────────────────────────────

  /// Shared "stroke annulus" test: [point] hits the *outline* of a shape
  /// when it falls inside the outline inflated by [tolerance] but outside
  /// the outline deflated by [tolerance]. [containsTest] supplies the
  /// shape-specific interior test (one of `SketchGeometry.pointInX`).
  static bool _hitStrokeShape(
    Offset point,
    Rect rect,
    double angle,
    double tolerance,
    bool Function(Offset point, Rect rect, double angle) containsTest,
  ) {
    final outer = SketchGeometry.inflate(rect, tolerance);
    final inner = SketchGeometry.inflate(rect, -tolerance);
    final hitOuter = containsTest(point, outer, angle);
    final hitInner = inner.width <= 0 || inner.height <= 0
        ? false
        : containsTest(point, inner, angle);
    return hitOuter && !hitInner;
  }

  static bool _hitStrokeRect(
    Offset point,
    Rect rect,
    double angle,
    double tolerance,
  ) =>
      _hitStrokeShape(
          point, rect, angle, tolerance, SketchGeometry.pointInRotatedRect);

  static bool _hitStrokeEllipse(
    Offset point,
    Rect rect,
    double angle,
    double tolerance,
  ) =>
      _hitStrokeShape(
          point, rect, angle, tolerance, SketchGeometry.pointInEllipse);

  static bool _hitStrokeDiamond(
    Offset point,
    Rect rect,
    double angle,
    double tolerance,
  ) =>
      _hitStrokeShape(
          point, rect, angle, tolerance, SketchGeometry.pointInDiamond);

  static bool _hitStrokeTriangle(
    Offset point,
    Rect rect,
    double angle,
    double tolerance,
  ) =>
      _hitStrokeShape(
          point, rect, angle, tolerance, SketchGeometry.pointInTriangle);
}
