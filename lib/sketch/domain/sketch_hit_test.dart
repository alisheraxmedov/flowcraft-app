import 'dart:ui';

import 'package:flowcraft/sketch/domain/sketch_geometry.dart';
import 'package:flowcraft/sketch/models/sketch_element.dart';
import 'package:flowcraft/sketch/models/sketch_style.dart';

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
  /// sticky that carries a label) and whose interior bounds contain [point].
  ///
  /// Unlike [topMost], this hits the *interior* of text-bearing shapes so a
  /// user can tap the label (not just the stroke) to start editing.
  static SketchElement? topMostTextTarget(
    List<SketchElement> elements,
    Offset point,
  ) {
    for (var i = elements.length - 1; i >= 0; i--) {
      final e = elements[i];
      final hasText = e is SketchText ||
          e is SketchSticky ||
          (e is SketchRectangle && e.text != null) ||
          (e is SketchEllipse && e.text != null) ||
          (e is SketchDiamond && e.text != null) ||
          (e is SketchTriangle && e.text != null);
      if (hasText && e.bounds.contains(point)) return e;
    }
    return null;
  }

  // ─── internal ───────────────────────────────────────────────────────────

  static bool _hitStrokeRect(
    Offset point,
    Rect rect,
    double angle,
    double tolerance,
  ) {
    final inflated = SketchGeometry.inflate(rect, tolerance);
    final deflated = SketchGeometry.inflate(rect, -tolerance);
    final inOuter = SketchGeometry.pointInRotatedRect(point, inflated, angle);
    final inInner = deflated.width <= 0 || deflated.height <= 0
        ? false
        : SketchGeometry.pointInRotatedRect(point, deflated, angle);
    return inOuter && !inInner;
  }

  static bool _hitStrokeEllipse(
    Offset point,
    Rect rect,
    double angle,
    double tolerance,
  ) {
    final outer = SketchGeometry.inflate(rect, tolerance);
    final inner = SketchGeometry.inflate(rect, -tolerance);
    final hitOuter = SketchGeometry.pointInEllipse(point, outer, angle);
    final hitInner = inner.width <= 0 || inner.height <= 0
        ? false
        : SketchGeometry.pointInEllipse(point, inner, angle);
    return hitOuter && !hitInner;
  }

  static bool _hitStrokeDiamond(
    Offset point,
    Rect rect,
    double angle,
    double tolerance,
  ) {
    final outer = SketchGeometry.inflate(rect, tolerance);
    final inner = SketchGeometry.inflate(rect, -tolerance);
    final hitOuter = SketchGeometry.pointInDiamond(point, outer, angle);
    final hitInner = inner.width <= 0 || inner.height <= 0
        ? false
        : SketchGeometry.pointInDiamond(point, inner, angle);
    return hitOuter && !hitInner;
  }

  static bool _hitStrokeTriangle(
    Offset point,
    Rect rect,
    double angle,
    double tolerance,
  ) {
    final outer = SketchGeometry.inflate(rect, tolerance);
    final inner = SketchGeometry.inflate(rect, -tolerance);
    final hitOuter = SketchGeometry.pointInTriangle(point, outer, angle);
    final hitInner = inner.width <= 0 || inner.height <= 0
        ? false
        : SketchGeometry.pointInTriangle(point, inner, angle);
    return hitOuter && !hitInner;
  }
}
