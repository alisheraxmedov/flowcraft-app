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

  /// Whether [element] offers the eight resize handles.
  ///
  /// One predicate for both sides of the handle: `SketchPainter` asks it
  /// whether to *draw* them and `SketchGestureHandler` asks it whether to
  /// *grab* them. Two copies is how this repo previously shipped handles
  /// drawn 4px from where they could be caught — see
  /// [SketchGeometry.handlePosition], which exists for the same reason.
  ///
  /// A collapsed sticky note is excluded: its badge is a fixed size, so a
  /// handle there would either resize nothing visible or silently resize the
  /// bubble hiding behind it.
  static bool isResizable(SketchElement element) => switch (element) {
    SketchSticky s => !s.collapsed,
    SketchRectangle _ ||
    SketchEllipse _ ||
    SketchDiamond _ ||
    SketchTriangle _ => true,
    _ => false,
  };

  /// Returns true if [point] hits [element], using the element's geometry
  /// and the given [tolerance] for strokes / linear shapes.
  ///
  /// A filled shape is hit anywhere inside *or* on its stroke, within
  /// [tolerance]. The interior test alone made a click on the rough
  /// stroke's outer wobble — or anywhere in the zoom-scaled tolerance band
  /// — miss a filled shape while hitting the identical unfilled one, which
  /// at 0.25× zoom is a 32-canvas-px difference the user can see.
  ///
  /// Every path honours [SketchElement.angle]: the bounded-shape tests
  /// unrotate internally, and the linear, freedraw and text tests unrotate
  /// [point] into the element's own frame first.
  static bool hit(SketchElement element, Offset point, double tolerance) {
    switch (element) {
      case SketchRectangle r:
        final stroke = _hitStrokeRect(point, r.rect, r.angle, tolerance);
        if (r.style.fillStyle == FillStyle.none) return stroke;
        return stroke ||
            SketchGeometry.pointInRotatedRect(point, r.rect, r.angle);
      case SketchEllipse e:
        final stroke = _hitStrokeEllipse(point, e.rect, e.angle, tolerance);
        if (e.style.fillStyle == FillStyle.none) return stroke;
        return stroke || SketchGeometry.pointInEllipse(point, e.rect, e.angle);
      case SketchDiamond d:
        final stroke = _hitStrokeDiamond(point, d.rect, d.angle, tolerance);
        if (d.style.fillStyle == FillStyle.none) return stroke;
        return stroke || SketchGeometry.pointInDiamond(point, d.rect, d.angle);
      case SketchTriangle tri:
        final stroke = _hitStrokeTriangle(
          point,
          tri.rect,
          tri.angle,
          tolerance,
        );
        if (tri.style.fillStyle == FillStyle.none) return stroke;
        return stroke ||
            SketchGeometry.pointInTriangle(point, tri.rect, tri.angle);
      case SketchSticky s:
        // `unrotatedBounds`, not `rect`: a collapsed note draws as a small
        // badge, and hit-testing the bubble hiding behind it would claim
        // clicks over a rectangle of empty canvas. And not `bounds`: that is
        // the rotated box, which `pointInRotatedRect` would rotate again.
        return SketchGeometry.pointInRotatedRect(
          point,
          s.unrotatedBounds,
          s.angle,
        );
      case SketchLine l:
        final p = _toLocal(point, l);
        return SketchGeometry.distanceToSegment(p, l.start, l.end) <= tolerance;
      case SketchArrow a:
        final p = _toLocal(point, a);
        return SketchGeometry.distanceToSegment(p, a.start, a.end) <= tolerance;
      case SketchFreedraw f:
        final p = _toLocal(point, f);
        return SketchGeometry.pointNearPolyline(p, f.points, tolerance);
      case SketchText t:
        final p = _toLocal(point, t);
        return t.unrotatedBounds.inflate(tolerance).contains(p);
      case SketchFrame _:
      case SketchIcon _:
      case SketchImage _:
      case SketchEntity _:
        // Placeholder: plain rect hit; frame border-only hit lands in phase 2.
        return SketchGeometry.pointInRotatedRect(
          point,
          element.unrotatedBounds,
          element.angle,
        );
    }
  }

  /// [point] in [element]'s own frame — unrotated about the pivot the
  /// painter rotates about, which is the centre of its bounds.
  static Offset _toLocal(Offset point, SketchElement element) {
    if (element.angle == 0.0) return point;
    return SketchGeometry.toLocal(
      point,
      element.unrotatedBounds.center,
      element.angle,
    );
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

  /// All elements that [region] catches. Used for marquee selection
  /// (rubber-band).
  ///
  /// Bounds are the cheap first pass — and for everything but a line or
  /// arrow, the only pass. They are the wrong answer for a linear element:
  /// a diagonal one fills a thin sliver of its bounding box, so a band
  /// nowhere near the stroke selected it anyway. Linear elements therefore
  /// test their actual segment against [region].
  ///
  /// The bounds pass is [SketchGeometry.rectsTouch] rather than
  /// [Rect.overlaps] because a shared edge has to count: an axis-aligned
  /// connector's bounds *are* a single edge, so a band drawn flush along
  /// the stroke was reported as missing it.
  ///
  /// A [region] with no area catches nothing. A rubber band is an area;
  /// the 0×0 rect a click leaves behind is not one, and treating it as one
  /// — with the inclusive bounds test above — selected every element whose
  /// *bounding box* contained the click, including the unfilled shape whose
  /// empty interior [hit] had just, deliberately, reported as a miss.
  static List<SketchElement> intersecting(
    List<SketchElement> elements,
    Rect region,
  ) {
    if (region.isEmpty) return const <SketchElement>[];
    final hits = <SketchElement>[];
    for (final e in elements) {
      if (!SketchGeometry.rectsTouch(e.bounds, region)) continue;
      final caught = switch (e) {
        SketchLine l => _segmentCaught(l, l.start, l.end, region),
        SketchArrow a => _segmentCaught(a, a.start, a.end, region),
        _ => true,
      };
      if (caught) hits.add(e);
    }
    return hits;
  }

  /// Whether the stored segment [start]–[end] of [element], placed on the
  /// canvas under its rotation, crosses [region].
  static bool _segmentCaught(
    SketchElement element,
    Offset start,
    Offset end,
    Rect region,
  ) {
    final angle = element.angle;
    if (angle != 0.0) {
      final pivot = element.unrotatedBounds.center;
      start = SketchGeometry.rotateAbout(start, pivot, angle);
      end = SketchGeometry.rotateAbout(end, pivot, angle);
    }
    return SketchGeometry.segmentIntersectsRect(start, end, region);
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
      final hasText =
          e is SketchText ||
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
  ) => _hitStrokeShape(
    point,
    rect,
    angle,
    tolerance,
    SketchGeometry.pointInRotatedRect,
  );

  static bool _hitStrokeEllipse(
    Offset point,
    Rect rect,
    double angle,
    double tolerance,
  ) => _hitStrokeShape(
    point,
    rect,
    angle,
    tolerance,
    SketchGeometry.pointInEllipse,
  );

  static bool _hitStrokeDiamond(
    Offset point,
    Rect rect,
    double angle,
    double tolerance,
  ) => _hitStrokeShape(
    point,
    rect,
    angle,
    tolerance,
    SketchGeometry.pointInDiamond,
  );

  static bool _hitStrokeTriangle(
    Offset point,
    Rect rect,
    double angle,
    double tolerance,
  ) => _hitStrokeShape(
    point,
    rect,
    angle,
    tolerance,
    SketchGeometry.pointInTriangle,
  );
}
