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
