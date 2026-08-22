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
    test('the tail is drawn within the rect, never hanging off it', () {
      // A tail outside the rect would make bounds wider than rect, and the
      // gesture handler seeds a resize from bounds — so every handle grab
      // would silently grow the note by the tail.
      final vertices =
          StickyBubbleGeometry.outlineVertices(rect, 12).toList();
      for (final v in vertices) {
        expect(rect.contains(v) || _onEdge(rect, v), isTrue,
            reason: '$v escapes $rect');
      }
      // …and it does reach the bottom edge, which is what makes it read as
      // a tail rather than a notch.
      expect(vertices.map((v) => v.dy), contains(rect.bottom));
    });

    test('the fill path never escapes the rect', () {
      final bounds = StickyBubbleGeometry.fillPath(rect, 12).getBounds();
      expect(bounds.left, greaterThanOrEqualTo(rect.left - 0.01));
      expect(bounds.top, greaterThanOrEqualTo(rect.top - 0.01));
      expect(bounds.right, lessThanOrEqualTo(rect.right + 0.01));
      expect(bounds.bottom, lessThanOrEqualTo(rect.bottom + 0.01));
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

        for (final v in StickyBubbleGeometry.outlineVertices(r, 12)) {
          expect(v.dx, greaterThanOrEqualTo(r.left - 0.01), reason: name);
          expect(v.dx, lessThanOrEqualTo(r.right + 0.01), reason: name);
          expect(v.dy, greaterThanOrEqualTo(r.top - 0.01), reason: name);
          expect(v.dy, lessThanOrEqualTo(r.bottom + 0.01), reason: name);
        }
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
  });

  test('the badge mark is a smaller copy of the same bubble', () {
    // Evocative of a messaging app without reproducing anyone's icon: the
    // mark is this app's own bubble silhouette, in miniature.
    final glyph = StickyBubbleGeometry.glyphRectOf(rect);
    final badge = StickyBubbleGeometry.collapsedBounds(rect);
    expect(badge.contains(glyph.topLeft), isTrue);
    expect(badge.contains(glyph.bottomRight), isTrue);

    final marks = StickyBubbleGeometry.glyphVertices(rect);
    final bubble = StickyBubbleGeometry.outlineVertices(glyph, 12);
    expect(marks.length, bubble.length);
    for (final v in marks) {
      expect(glyph.contains(v) || _onEdge(glyph, v), isTrue);
    }
  });
}

/// [Rect.contains] excludes the right and bottom edges, which is where a
/// bubble's own outline lives.
bool _onEdge(Rect rect, Offset p) =>
    p.dx >= rect.left - 0.01 &&
    p.dx <= rect.right + 0.01 &&
    p.dy >= rect.top - 0.01 &&
    p.dy <= rect.bottom + 0.01;
