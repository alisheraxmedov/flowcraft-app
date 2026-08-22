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
      final e = SketchEllipse.create(
        rect: const Rect.fromLTWH(0, 0, 100, 50),
      );
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
        points: const [
          Offset(0, 0),
          Offset(50, 0),
          Offset(50, 50),
        ],
      );
      expect(SketchHitTest.hit(f, const Offset(25, 0), 3.0), isTrue);
      expect(SketchHitTest.hit(f, const Offset(50, 25), 3.0), isTrue);
      expect(SketchHitTest.hit(f, const Offset(100, 100), 3.0), isFalse);
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
      final hit =
          SketchHitTest.topMost([bottom, top], const Offset(50, 50), 4.0);
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
      expect(SketchHitTest.topMostTextTarget([t], const Offset(70, 8)), same(t));
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
      final hits = SketchHitTest.intersecting(
        [inside, outside],
        const Rect.fromLTWH(0, 0, 50, 50),
      );
      expect(hits, [inside]);
    });
  });
}
