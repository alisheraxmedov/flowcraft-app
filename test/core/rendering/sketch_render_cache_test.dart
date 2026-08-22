import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/core/domain/sticky_bubble_geometry.dart';
import 'package:flowcraft/core/rendering/sketch_render_cache.dart';
import 'package:flowcraft/models/sketch_element.dart';

/// The cache is what actually turns an element into the paths the painter
/// draws, so it is where "what is drawn" can be measured against "what
/// `bounds` claims". A disagreement between those two is the bug class this
/// repo has already paid for once, in `SketchText.bounds`.
const Rect _rect = Rect.fromLTWH(60, 20, 220, 110);

/// Full roughness on purpose: a sticky is the one closed shape that is
/// drawn clean whatever its style says, and these tests would pass by
/// accident at roughness 0.
SketchSticky _sticky({bool collapsed = false}) => SketchSticky.create(
      id: 'note',
      rect: _rect,
      text: 'remember this',
      style: SketchSticky.defaultStyle.copyWith(roughness: 2.0),
      collapsed: collapsed,
    );

/// Bounds of the points a path actually passes through.
///
/// Not [Path.getBounds]: that reports the hull of the cubics' *control*
/// points, and `RoughGenerator` deliberately throws control points past the
/// segment's end (it is what produces the overshooting hand-drawn stroke).
/// Measuring those would claim the note paints 18px above itself when the
/// ink never leaves the box.
Rect _inkedBounds(Path path) {
  final points = <Offset>[];
  for (final metric in path.computeMetrics()) {
    const samples = 64;
    for (var i = 0; i <= samples; i++) {
      final tangent = metric.getTangentForOffset(metric.length * i / samples);
      if (tangent != null) points.add(tangent.position);
    }
  }
  expect(points, isNotEmpty, reason: 'nothing was drawn');
  return points.skip(1).fold(
        Rect.fromPoints(points.first, points.first),
        (box, p) => box.expandToInclude(Rect.fromPoints(p, p)),
      );
}

void _expectWithin(Rect drawn, Rect allowed, {double slack = 0.0}) {
  final box = allowed.inflate(slack);
  expect(drawn.left, greaterThanOrEqualTo(box.left),
      reason: '$drawn escapes $box on the left');
  expect(drawn.top, greaterThanOrEqualTo(box.top),
      reason: '$drawn escapes $box on the top');
  expect(drawn.right, lessThanOrEqualTo(box.right),
      reason: '$drawn escapes $box on the right');
  expect(drawn.bottom, lessThanOrEqualTo(box.bottom),
      reason: '$drawn escapes $box on the bottom');
}

void main() {
  group('a sticky note paints inside the box it claims', () {
    test('expanded: the bubble fills its rect and nothing more', () {
      final cache = SketchRenderCache();
      final note = _sticky();
      expect(note.bounds, _rect);

      _expectWithin(cache.fillPath(note).getBounds(), note.bounds, slack: 0.01);
      _expectWithin(_inkedBounds(cache.strokePath(note)), note.bounds,
          slack: 0.01);
    });

    test('the outline is the exact edge of the fill, at any roughness', () {
      // Rendered rough, the outline had square corners over a rounded fill
      // and poked past it at every corner — the "badly made" the user saw.
      final cache = SketchRenderCache();
      final note = _sticky();
      final fill = _inkedBounds(cache.fillPath(note));
      final stroke = _inkedBounds(cache.strokePath(note));
      expect(stroke.left, closeTo(fill.left, 0.01));
      expect(stroke.top, closeTo(fill.top, 0.01));
      expect(stroke.right, closeTo(fill.right, 0.01));
      expect(stroke.bottom, closeTo(fill.bottom, 0.01));
    });

    test('collapsed: the badge fills its bounds and nothing more', () {
      final cache = SketchRenderCache();
      final note = _sticky(collapsed: true);
      expect(note.bounds, StickyBubbleGeometry.collapsedBounds(_rect));

      final fill = cache.fillPath(note).getBounds();
      _expectWithin(fill, note.bounds, slack: 0.01);
      // The bubble hiding behind the badge must not be painted: if it were,
      // the drawn box would reach the expanded rect's right edge while
      // `bounds` stopped 36px in, which is exactly the desync to avoid.
      expect(fill.right, lessThan(_rect.right - 100));

      _expectWithin(_inkedBounds(cache.strokePath(note)), note.bounds,
          slack: 0.01);
    });
  });

  group('cached paths track the collapsed flag', () {
    test('toggling collapse does not re-serve the previous silhouette', () {
      // Both states share an id, a seed and a rect, so a key that ignored
      // `collapsed` would hand the badge the bubble's path.
      final cache = SketchRenderCache();
      final expanded = cache.fillPath(_sticky()).getBounds();
      final collapsed = cache.fillPath(_sticky(collapsed: true)).getBounds();
      expect(collapsed, isNot(expanded));
      expect(collapsed.width, closeTo(StickyBubbleGeometry.collapsedSize, 0.01));

      final expandedStroke = cache.strokePath(_sticky()).getBounds();
      final collapsedStroke =
          cache.strokePath(_sticky(collapsed: true)).getBounds();
      expect(collapsedStroke, isNot(expandedStroke));
    });

    test('the same note still hits the cache', () {
      final cache = SketchRenderCache();
      final note = _sticky();
      expect(identical(cache.fillPath(note), cache.fillPath(note)), isTrue);
      expect(identical(cache.strokePath(note), cache.strokePath(note)), isTrue);
    });
  });
}
