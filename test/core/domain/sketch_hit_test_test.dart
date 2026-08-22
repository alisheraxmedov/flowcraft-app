import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/core/domain/sketch_hit_test.dart';
import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/models/sketch_style.dart';

void main() {
  group('SketchHitTest.hit', () {
    test('rectangle stroke is hit near border but not interior', () {
      final r = SketchRectangle.create(
        rect: const Rect.fromLTWH(0, 0, 100, 100),
      );
      expect(SketchHitTest.hit(r, const Offset(0, 50), 4.0), isTrue);
      expect(SketchHitTest.hit(r, const Offset(50, 50), 4.0), isFalse);
    });

    test('filled rectangle is hit everywhere inside', () {
      final r = SketchRectangle.create(
        rect: const Rect.fromLTWH(0, 0, 100, 100),
        style: const SketchStyle(
          fillStyle: FillStyle.solid,
          fillColor: Color(0xFF000000),
        ),
      );
      expect(SketchHitTest.hit(r, const Offset(50, 50), 4.0), isTrue);
    });

    test('ellipse interior + border behave as expected', () {
      final e = SketchEllipse.create(rect: const Rect.fromLTWH(0, 0, 100, 50));
      // Centre of the unfilled ellipse is empty → miss.
      expect(SketchHitTest.hit(e, const Offset(50, 25), 4.0), isFalse);
      // Near the rightmost border → hit.
      expect(SketchHitTest.hit(e, const Offset(99, 25), 4.0), isTrue);
    });

    test('line is hit only near its segment', () {
      final l = SketchLine.create(
        start: const Offset(0, 0),
        end: const Offset(100, 0),
      );
      expect(SketchHitTest.hit(l, const Offset(50, 0), 5.0), isTrue);
      expect(SketchHitTest.hit(l, const Offset(50, 20), 5.0), isFalse);
    });

    test('arrow uses segment hit semantics', () {
      final a = SketchArrow.create(
        start: const Offset(0, 0),
        end: const Offset(100, 100),
      );
      expect(SketchHitTest.hit(a, const Offset(50, 50), 4.0), isTrue);
      expect(SketchHitTest.hit(a, const Offset(0, 100), 4.0), isFalse);
    });

    test('freedraw is hit near any polyline segment', () {
      final f = SketchFreedraw.create(
        points: const [Offset(0, 0), Offset(50, 0), Offset(50, 50)],
      );
      expect(SketchHitTest.hit(f, const Offset(25, 0), 3.0), isTrue);
      expect(SketchHitTest.hit(f, const Offset(50, 25), 3.0), isTrue);
      expect(SketchHitTest.hit(f, const Offset(100, 100), 3.0), isFalse);
    });

    // Triangles were unhittable outright — `pointInTriangle` had its
    // winding sign inverted, and the stroke band is built from the same
    // predicate, so neither the filled nor the unfilled case could be
    // clicked, dragged, erased or given handles. Only a marquee reached one.
    group('triangle', () {
      const rect = Rect.fromLTWH(0, 0, 100, 100);

      test('filled is hit at its centre', () {
        final tri = SketchTriangle.create(
          rect: rect,
          style: const SketchStyle(
            fillStyle: FillStyle.solid,
            fillColor: Color(0xFF000000),
          ),
        );
        expect(SketchHitTest.hit(tri, const Offset(50, 60), 8.0), isTrue);
      });

      test('unfilled is hit 1px inside the base', () {
        final tri = SketchTriangle.create(rect: rect);
        expect(SketchHitTest.hit(tri, const Offset(50, 99), 8.0), isTrue);
      });

      test('unfilled is hit on the slanted edges', () {
        final tri = SketchTriangle.create(rect: rect);
        // Left edge passes (25, 50); right edge (75, 50).
        expect(SketchHitTest.hit(tri, const Offset(25, 50), 4.0), isTrue);
        expect(SketchHitTest.hit(tri, const Offset(75, 50), 4.0), isTrue);
      });

      test('unfilled misses at its centre', () {
        final tri = SketchTriangle.create(rect: rect);
        expect(SketchHitTest.hit(tri, const Offset(50, 60), 8.0), isFalse);
      });

      test('both miss the empty bbox corner beside the apex', () {
        final filled = SketchTriangle.create(
          rect: rect,
          style: const SketchStyle(
            fillStyle: FillStyle.solid,
            fillColor: Color(0xFF000000),
          ),
        );
        final hollow = SketchTriangle.create(rect: rect);
        expect(SketchHitTest.hit(filled, const Offset(2, 2), 1.0), isFalse);
        expect(SketchHitTest.hit(hollow, const Offset(2, 2), 1.0), isFalse);
      });
    });

    test(
      'filled rectangle is also hit just outside its edge within tolerance',
      () {
        // The rough stroke wobbles a few px outside `rect`, and at 0.25× zoom
        // the tolerance is 32 canvas px: the unfilled shape was hit there and
        // the identical filled one was not.
        final filled = SketchRectangle.create(
          rect: const Rect.fromLTWH(0, 0, 100, 100),
          style: const SketchStyle(
            fillStyle: FillStyle.solid,
            fillColor: Color(0xFF000000),
          ),
        );
        expect(SketchHitTest.hit(filled, const Offset(-3, 50), 4.0), isTrue);
        expect(SketchHitTest.hit(filled, const Offset(-6, 50), 4.0), isFalse);
      },
    );

    test('filled ellipse is hit just outside its rim within tolerance', () {
      final filled = SketchEllipse.create(
        rect: const Rect.fromLTWH(0, 0, 100, 50),
        style: const SketchStyle(
          fillStyle: FillStyle.solid,
          fillColor: Color(0xFF000000),
        ),
      );
      expect(SketchHitTest.hit(filled, const Offset(102, 25), 4.0), isTrue);
      expect(SketchHitTest.hit(filled, const Offset(50, 25), 4.0), isTrue);
      expect(SketchHitTest.hit(filled, const Offset(110, 25), 4.0), isFalse);
    });

    group('rotated elements', () {
      // `angle` is reserved — no tool sets it — but a file can carry it and
      // the painter honours it, so the hit test has to agree with what is
      // drawn. A quarter turn about the centre is the easiest to reason
      // about: a horizontal line becomes a vertical one.
      const quarter = math.pi / 2;

      test(
        'a rotated line is hit where it is drawn, not where it is stored',
        () {
          final line = SketchLine(
            id: 'l',
            style: const SketchStyle(),
            start: const Offset(0, 100),
            end: const Offset(200, 100),
            angle: quarter,
          );
          // Pivot is (100,100); the line now runs from (100,0) to (100,200).
          expect(SketchHitTest.hit(line, const Offset(100, 20), 4.0), isTrue);
          expect(SketchHitTest.hit(line, const Offset(20, 100), 4.0), isFalse);
        },
      );

      test('a rotated arrow follows the same rule', () {
        final arrow = SketchArrow(
          id: 'a',
          style: const SketchStyle(),
          start: const Offset(0, 100),
          end: const Offset(200, 100),
          angle: quarter,
        );
        expect(SketchHitTest.hit(arrow, const Offset(100, 180), 4.0), isTrue);
        expect(SketchHitTest.hit(arrow, const Offset(180, 100), 4.0), isFalse);
      });

      test('a rotated freedraw follows the same rule', () {
        final stroke = SketchFreedraw(
          id: 'f',
          style: const SketchStyle(),
          points: const [Offset(0, 100), Offset(100, 100), Offset(200, 100)],
          angle: quarter,
        );
        expect(SketchHitTest.hit(stroke, const Offset(100, 20), 4.0), isTrue);
        expect(SketchHitTest.hit(stroke, const Offset(20, 100), 4.0), isFalse);
      });

      test('a rotated text box follows the same rule', () {
        final text = SketchText(
          id: 't',
          style: const SketchStyle(),
          position: Offset.zero,
          text: 'Hello world, a reasonably long line',
          fontSize: 16,
          angle: quarter,
        );
        final box = text.unrotatedBounds;
        expect(
          box.width,
          greaterThan(box.height * 3),
          reason: 'wide enough that a quarter turn moves its far end',
        );
        final c = box.center;
        // The glyphs' far end now sits below the pivot, not to its right.
        final belowPivot = Offset(c.dx, c.dy + box.width / 2 - 4);
        final rightOfPivot = Offset(c.dx + box.width / 2 - 4, c.dy);
        expect(SketchHitTest.hit(text, belowPivot, 0.0), isTrue);
        expect(SketchHitTest.hit(text, rightOfPivot, 0.0), isFalse);
      });

      test('a rotated unfilled rectangle is hit on its drawn stroke', () {
        final box = SketchRectangle(
          id: 'r',
          style: const SketchStyle(),
          rect: const Rect.fromLTWH(0, 0, 200, 50),
          angle: quarter,
        );
        // 200×50 about (100,25) becomes 50×200: x in 75..125, y in -75..125.
        expect(SketchHitTest.hit(box, const Offset(100, -73), 4.0), isTrue);
        expect(SketchHitTest.hit(box, const Offset(2, 25), 4.0), isFalse);
      });
    });
  });

  group('SketchHitTest.topMost', () {
    test('returns the last-drawn element among multiple hits', () {
      final bottom = SketchRectangle.create(
        rect: const Rect.fromLTWH(0, 0, 100, 100),
        style: const SketchStyle(
          fillStyle: FillStyle.solid,
          fillColor: Color(0xFF000000),
        ),
      );
      final top = SketchEllipse.create(
        rect: const Rect.fromLTWH(0, 0, 100, 100),
        style: const SketchStyle(
          fillStyle: FillStyle.solid,
          fillColor: Color(0xFFFF0000),
        ),
      );
      final hit = SketchHitTest.topMost(
        [bottom, top],
        const Offset(50, 50),
        4.0,
      );
      expect(hit, same(top));
    });
  });

  group('SketchHitTest.topMostTextTarget', () {
    SketchText text({String? id}) => SketchText.create(
      id: id,
      position: Offset.zero,
      text: 'Hello',
      fontSize: 16,
    );

    test('hits a glyph the old approximate bounds would have missed', () {
      final t = text(id: 't');
      // `bounds` now measures the real glyphs; the guess it replaced
      // (length * fontSize * 0.55) claimed 44px of width, so this click —
      // on a letter the painter actually draws — used to miss and the text
      // tool spawned a second, empty text box instead of editing this one.
      expect(5 * 16 * 0.55, lessThan(70));
      expect(t.bounds.right, greaterThan(70));
      expect(
        SketchHitTest.topMostTextTarget([t], const Offset(70, 8)),
        same(t),
      );
    });

    test('tolerance gives slack just off a thin glyph', () {
      final t = text(id: 't');
      final justOutside = t.bounds.bottomRight + const Offset(4, 4);
      expect(SketchHitTest.topMostTextTarget([t], justOutside), same(t));
      expect(
        SketchHitTest.topMostTextTarget([t], justOutside, tolerance: 0.0),
        isNull,
      );
    });

    test('hits the interior of a labelled shape, not just its stroke', () {
      final labelled = SketchRectangle.create(
        id: 'labelled',
        rect: const Rect.fromLTWH(0, 0, 100, 100),
        text: 'Label',
      );
      expect(
        SketchHitTest.topMostTextTarget([labelled], const Offset(50, 50)),
        same(labelled),
      );
    });

    test('ignores shapes carrying no label', () {
      final bare = SketchRectangle.create(
        rect: const Rect.fromLTWH(0, 0, 100, 100),
      );
      expect(
        SketchHitTest.topMostTextTarget([bare], const Offset(50, 50)),
        isNull,
      );
    });

    test('returns the topmost of several overlapping text targets', () {
      final bottom = text(id: 'bottom');
      final top = text(id: 'top');
      expect(
        SketchHitTest.topMostTextTarget([bottom, top], const Offset(8, 8)),
        same(top),
      );
    });
  });

  group('SketchHitTest.intersecting', () {
    test('returns elements whose bounds overlap region', () {
      final inside = SketchRectangle.create(
        rect: const Rect.fromLTWH(5, 5, 10, 10),
      );
      final outside = SketchRectangle.create(
        rect: const Rect.fromLTWH(100, 100, 5, 5),
      );
      final hits = SketchHitTest.intersecting([
        inside,
        outside,
      ], const Rect.fromLTWH(0, 0, 50, 50));
      expect(hits, [inside]);
    });

    test('catches a horizontal line a band is drawn flush along', () {
      // Zero-height bounds are a single edge, and Rect.overlaps calls a
      // shared edge disjoint — so this band missed the stroke it covers.
      final wire = SketchLine.create(
        start: const Offset(100, 200),
        end: const Offset(300, 200),
      );
      const band = Rect.fromLTRB(80, 200, 320, 260);
      expect(wire.bounds.height, 0);
      expect(wire.bounds.overlaps(band), isFalse);
      expect(SketchHitTest.intersecting([wire], band), [wire]);
    });

    test('catches a vertical arrow a band is drawn flush along', () {
      final wire = SketchArrow.create(
        start: const Offset(200, 100),
        end: const Offset(200, 300),
      );
      // The shaft is a single edge; only the head's wings give the arrow's
      // bounds any width at all, and a band starting on the shaft covers
      // just half of them.
      const band = Rect.fromLTRB(200, 80, 260, 320);
      expect(
        wire.bounds.width,
        closeTo(2 * 12 * math.sin(0.5), 1e-9),
        reason: 'two wings of the 12px default head',
      );
      expect(wire.bounds.center.dx, 200);
      expect(SketchHitTest.intersecting([wire], band), [wire]);
    });

    test('a band beside an arrow that only grazes its head wings misses', () {
      // The wings widen `bounds`, but the marquee still tests the shaft.
      final wire = SketchArrow.create(
        start: const Offset(200, 100),
        end: const Offset(200, 300),
      );
      const band = Rect.fromLTRB(203, 280, 260, 320);
      expect(wire.bounds.overlaps(band), isTrue);
      expect(SketchHitTest.intersecting([wire], band), isEmpty);
    });

    test('a band straddling an axis-aligned line keeps working', () {
      final wire = SketchLine.create(
        start: const Offset(100, 200),
        end: const Offset(300, 200),
      );
      expect(
        SketchHitTest.intersecting([
          wire,
        ], const Rect.fromLTRB(80, 150, 320, 260)),
        [wire],
      );
    });

    test('skips a diagonal line whose bounding box the region only clips', () {
      final wire = SketchLine.create(
        start: Offset.zero,
        end: const Offset(200, 200),
      );
      // Inside the bounding box, but 100+ px from the stroke itself.
      const corner = Rect.fromLTRB(150, 10, 190, 50);
      expect(wire.bounds.overlaps(corner), isTrue);
      expect(SketchHitTest.intersecting([wire], corner), isEmpty);
    });

    test('still catches a diagonal line the region actually crosses', () {
      final wire = SketchLine.create(
        start: Offset.zero,
        end: const Offset(200, 200),
      );
      final hits = SketchHitTest.intersecting([
        wire,
      ], const Rect.fromLTRB(90, 90, 110, 110));
      expect(hits, [wire]);
    });

    test('a zero-size region catches nothing', () {
      // The 0×0 rect a plain click leaves behind. With the inclusive bounds
      // test it caught every element whose bounding box held the point —
      // the unfilled frame the hit test had just rejected included.
      final frame = SketchRectangle.create(
        rect: const Rect.fromLTWH(0, 0, 300, 300),
      );
      final blob = SketchEllipse.create(
        rect: const Rect.fromLTWH(0, 0, 300, 300),
      );
      final scribble = SketchFreedraw.create(
        points: const [Offset(0, 0), Offset(300, 300)],
      );
      const click = Rect.fromLTWH(150, 150, 0, 0);
      expect(frame.bounds.contains(click.topLeft), isTrue);
      expect(
        SketchHitTest.intersecting([frame, blob, scribble], click),
        isEmpty,
      );
    });

    test('a region with one zero dimension catches nothing either', () {
      final frame = SketchRectangle.create(
        rect: const Rect.fromLTWH(0, 0, 300, 300),
      );
      expect(
        SketchHitTest.intersecting([
          frame,
        ], const Rect.fromLTWH(10, 150, 200, 0)),
        isEmpty,
      );
    });

    test('a rotated line is caught where it is drawn', () {
      // Stored horizontal, drawn vertical through (100, 0)–(100, 200).
      final wire = SketchLine(
        id: 'l',
        style: const SketchStyle(),
        start: const Offset(0, 100),
        end: const Offset(200, 100),
        angle: math.pi / 2,
      );
      expect(wire.bounds.left, closeTo(100, 1e-9));
      expect(wire.bounds.top, closeTo(0, 1e-9));
      expect(
        SketchHitTest.intersecting([
          wire,
        ], const Rect.fromLTRB(90, 10, 110, 30)),
        [wire],
      );
      expect(
        SketchHitTest.intersecting([
          wire,
        ], const Rect.fromLTRB(10, 90, 30, 110)),
        isEmpty,
      );
    });
  });

  group('SketchHitTest.isResizable', () {
    // One predicate, read by the painter to decide whether to *draw* the
    // eight handles and by the gesture handler to decide whether to *grab*
    // them. A second copy is how handles end up drawn where nothing can be
    // caught.
    const rect = Rect.fromLTWH(0, 0, 100, 60);

    test('bounded shapes are', () {
      expect(
        SketchHitTest.isResizable(SketchRectangle.create(rect: rect)),
        isTrue,
      );
      expect(
        SketchHitTest.isResizable(SketchEllipse.create(rect: rect)),
        isTrue,
      );
      expect(
        SketchHitTest.isResizable(SketchDiamond.create(rect: rect)),
        isTrue,
      );
      expect(
        SketchHitTest.isResizable(SketchTriangle.create(rect: rect)),
        isTrue,
      );
    });

    test('an expanded sticky note is, a collapsed one is not', () {
      expect(
        SketchHitTest.isResizable(SketchSticky.create(rect: rect)),
        isTrue,
      );
      // The badge is a fixed size: a handle on it would either resize
      // nothing visible or silently resize the bubble behind it.
      expect(
        SketchHitTest.isResizable(
          SketchSticky.create(rect: rect, collapsed: true),
        ),
        isFalse,
      );
    });

    test('lines, arrows, freedraw and text are not', () {
      expect(
        SketchHitTest.isResizable(
          SketchLine.create(start: Offset.zero, end: const Offset(9, 9)),
        ),
        isFalse,
      );
      expect(
        SketchHitTest.isResizable(
          SketchArrow.create(start: Offset.zero, end: const Offset(9, 9)),
        ),
        isFalse,
      );
      expect(
        SketchHitTest.isResizable(
          SketchFreedraw.create(points: const [Offset.zero, Offset(9, 9)]),
        ),
        isFalse,
      );
      expect(
        SketchHitTest.isResizable(
          SketchText.create(position: Offset.zero, text: 'hi'),
        ),
        isFalse,
      );
    });
  });
}
