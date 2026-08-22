import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/core/domain/sticky_bubble_geometry.dart';

/// [StickyBubbleGeometry] is the single source every consumer reads its
/// arithmetic from — the model's `bounds`, the render cache's paths, the
/// painter's label box and the inline editor's glyph box. These are the
/// invariants those consumers are entitled to assume.
void main() {
  const rect = Rect.fromLTWH(100, 40, 200, 90);

  group('bounds', () {
    test('an expanded note occupies its rect', () {
      expect(
        StickyBubbleGeometry.boundsOf(rect, collapsed: false),
        rect,
      );
    });

    test('a collapsed note occupies only its badge, anchored top-left', () {
      final bounds = StickyBubbleGeometry.boundsOf(rect, collapsed: true);
      expect(bounds.topLeft, rect.topLeft);
      expect(bounds.width, StickyBubbleGeometry.collapsedSize);
      expect(bounds.height, StickyBubbleGeometry.collapsedSize);
      // The whole point: the collapsed note is *smaller* than the bubble it
      // is hiding, so selection and hit-testing must not see the bubble.
      expect(bounds.right, lessThan(rect.right));
      expect(bounds.bottom, lessThan(rect.bottom));
    });
  });

  group('the bubble stays inside the element rect', () {
    test('the outline never escapes the rect, tail included', () {
      // A tail outside the rect would make bounds wider than rect, and the
      // gesture handler seeds a resize from bounds — so every handle grab
      // would silently grow the note by the tail.
      final inked = _inkedBounds(StickyBubbleGeometry.bubblePath(rect, 12));
      expect(inked.left, greaterThanOrEqualTo(rect.left - 0.01));
      expect(inked.top, greaterThanOrEqualTo(rect.top - 0.01));
      expect(inked.right, lessThanOrEqualTo(rect.right + 0.01));
      expect(inked.bottom, lessThanOrEqualTo(rect.bottom + 0.01));
      // …and it does reach the bottom-left corner, which is what makes it
      // read as a tail rather than a notch. Tolerance is the sampling
      // pitch of `_samples`, not a geometric allowance.
      expect(inked.bottom, closeTo(rect.bottom, 2.5));
      expect(inked.left, closeTo(rect.left, 2.5));
    });

    test('the tail scoops: its outer edge bows toward the body', () {
      // The difference between a curled messenger tail and a triangle
      // bolted on. Midway along the tail's outer edge, the path must sit
      // *above* the straight chord from base to tip.
      final body = StickyBubbleGeometry.bodyOf(rect);
      final samples = _samples(StickyBubbleGeometry.bubblePath(rect, 12));
      final midX = rect.left + (body.left + 12 + 16 - rect.left) / 2;
      // Points on the outer edge near midX, below the body.
      final onTail = samples.where(
        (p) => (p.dx - midX).abs() < 2.0 && p.dy > body.bottom - 0.5,
      );
      expect(onTail, isNotEmpty);
      final chordY = body.bottom +
          (rect.bottom - body.bottom) * (1 - (midX - rect.left) / (28));
      for (final p in onTail) {
        expect(p.dy, lessThan(chordY), reason: 'tail edge is not concave');
      }
    });

    test('the badge fill matches the collapsed bounds exactly', () {
      final drawn = StickyBubbleGeometry.badgeFillPath(rect).getBounds();
      final bounds = StickyBubbleGeometry.collapsedBounds(rect);
      expect(drawn.left, closeTo(bounds.left, 0.01));
      expect(drawn.top, closeTo(bounds.top, 0.01));
      expect(drawn.right, closeTo(bounds.right, 0.01));
      expect(drawn.bottom, closeTo(bounds.bottom, 0.01));
    });
  });

  group('degenerate sizes', () {
    // The resize floor is 10 canvas px per axis, so these are reachable by
    // dragging, not hypothetical.
    const tiny = Rect.fromLTWH(0, 0, 10, 10);
    const wide = Rect.fromLTWH(0, 0, 1200, 30);
    const tall = Rect.fromLTWH(0, 0, 30, 800);

    for (final (name, r) in <(String, Rect)>[
      ('tiny', tiny),
      ('very wide', wide),
      ('very tall', tall),
    ]) {
      test('a $name bubble keeps a positive body, text box and tail', () {
        final body = StickyBubbleGeometry.bodyOf(r);
        expect(body.width, greaterThan(0), reason: name);
        expect(body.height, greaterThan(0), reason: name);
        expect(body.bottom, lessThan(r.bottom), reason: name);

        final text = StickyBubbleGeometry.textBoxOf(r);
        expect(text.width, greaterThan(0), reason: name);
        expect(text.height, greaterThan(0), reason: name);

        // A large nominal radius must not invert a small body.
        final radius = StickyBubbleGeometry.radiusOf(r, 12);
        expect(radius, lessThanOrEqualTo(body.shortestSide / 2 + 0.01),
            reason: name);

        final inked = _inkedBounds(StickyBubbleGeometry.bubblePath(r, 12));
        expect(inked.left, greaterThanOrEqualTo(r.left - 0.01), reason: name);
        expect(inked.top, greaterThanOrEqualTo(r.top - 0.01), reason: name);
        expect(inked.right, lessThanOrEqualTo(r.right + 0.01), reason: name);
        expect(inked.bottom, lessThanOrEqualTo(r.bottom + 0.01), reason: name);
      });
    }
  });

  group('text box', () {
    test('sits inside the body, clear of the tail band', () {
      final text = StickyBubbleGeometry.textBoxOf(rect);
      final body = StickyBubbleGeometry.bodyOf(rect);
      expect(body.contains(text.topLeft), isTrue);
      expect(text.right, lessThanOrEqualTo(body.right));
      expect(text.bottom, lessThanOrEqualTo(body.bottom));
    });

    test('travels with the note', () {
      const delta = Offset(37, -12);
      expect(
        StickyBubbleGeometry.textBoxOf(rect.shift(delta)),
        StickyBubbleGeometry.textBoxOf(rect).shift(delta),
      );
    });

    test('heightFor is the inverse of textBoxOf at nominal size', () {
      // What `SketchSticky.fittedToText` relies on: a note grown to
      // `heightFor(h)` has a text box exactly `h` tall.
      const textHeight = 57.0;
      final grown = Rect.fromLTWH(
        0,
        0,
        180,
        StickyBubbleGeometry.heightFor(textHeight),
      );
      expect(
        StickyBubbleGeometry.textBoxOf(grown).height,
        closeTo(textHeight, 0.001),
      );
    });
  });

  test('the badge mark is a smaller copy of the same bubble', () {
    // Evocative of a messaging app without reproducing anyone's icon: the
    // mark is this app's own bubble silhouette, in miniature, and it stays
    // inside the badge with room to breathe.
    final glyph = StickyBubbleGeometry.glyphRectOf(rect);
    final badge = StickyBubbleGeometry.collapsedBounds(rect);
    expect(badge.deflate(4).contains(glyph.topLeft), isTrue);
    expect(badge.deflate(4).contains(glyph.bottomRight), isTrue);

    final inked = _inkedBounds(StickyBubbleGeometry.glyphPath(rect));
    expect(inked.left, greaterThanOrEqualTo(glyph.left - 0.01));
    expect(inked.top, greaterThanOrEqualTo(glyph.top - 0.01));
    expect(inked.right, lessThanOrEqualTo(glyph.right + 0.01));
    expect(inked.bottom, lessThanOrEqualTo(glyph.bottom + 0.01));
  });
}

/// Points along every contour of [path].
List<Offset> _samples(Path path) {
  final points = <Offset>[];
  for (final metric in path.computeMetrics()) {
    const samples = 256;
    for (var i = 0; i <= samples; i++) {
      final t = metric.getTangentForOffset(metric.length * i / samples);
      if (t != null) points.add(t.position);
    }
  }
  return points;
}

/// Bounds of the points a path actually passes through — not
/// [Path.getBounds], which reports the hull of the curves' control points.
Rect _inkedBounds(Path path) {
  final points = _samples(path);
  expect(points, isNotEmpty, reason: 'nothing was drawn');
  return points.skip(1).fold(
        Rect.fromPoints(points.first, points.first),
        (box, p) => box.expandToInclude(Rect.fromPoints(p, p)),
      );
}
