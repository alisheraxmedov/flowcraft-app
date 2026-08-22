import 'dart:math' as math;
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/core/domain/sketch_geometry.dart';
import 'package:flowcraft/models/sketch_element.dart';

void main() {
  group('SketchGeometry.distanceToSegment', () {
    test('returns distance to closest projection inside segment', () {
      final d = SketchGeometry.distanceToSegment(
        const Offset(5, 5),
        const Offset(0, 0),
        const Offset(10, 0),
      );
      expect(d, closeTo(5.0, 1e-9));
    });

    test('returns endpoint distance when projection is outside segment', () {
      final d = SketchGeometry.distanceToSegment(
        const Offset(-5, 0),
        const Offset(0, 0),
        const Offset(10, 0),
      );
      expect(d, closeTo(5.0, 1e-9));
    });

    test('returns endpoint distance for zero-length segment', () {
      final d = SketchGeometry.distanceToSegment(
        const Offset(3, 4),
        const Offset(0, 0),
        const Offset(0, 0),
      );
      expect(d, closeTo(5.0, 1e-9));
    });
  });

  group('SketchGeometry.pointInRotatedRect', () {
    test('axis-aligned rect uses Rect.contains', () {
      final rect = const Rect.fromLTWH(0, 0, 10, 10);
      expect(SketchGeometry.pointInRotatedRect(const Offset(5, 5), rect, 0), isTrue);
      expect(
        SketchGeometry.pointInRotatedRect(const Offset(-1, 5), rect, 0),
        isFalse,
      );
    });
  });

  group('SketchGeometry.pointInEllipse', () {
    test('centre is inside', () {
      final rect = const Rect.fromLTWH(0, 0, 20, 10);
      expect(SketchGeometry.pointInEllipse(const Offset(10, 5), rect, 0), isTrue);
    });

    test('corner of bbox is outside', () {
      final rect = const Rect.fromLTWH(0, 0, 20, 10);
      expect(SketchGeometry.pointInEllipse(const Offset(0, 0), rect, 0), isFalse);
    });
  });

  group('SketchGeometry.pointInDiamond', () {
    final rect = const Rect.fromLTWH(0, 0, 10, 10);

    test('centre is inside', () {
      expect(SketchGeometry.pointInDiamond(const Offset(5, 5), rect, 0), isTrue);
    });

    test('top vertex is on the boundary (inclusive)', () {
      expect(SketchGeometry.pointInDiamond(const Offset(5, 0), rect, 0), isTrue);
    });

    test('corner of bbox is outside', () {
      expect(SketchGeometry.pointInDiamond(const Offset(0, 0), rect, 0), isFalse);
    });
  });

  group('SketchGeometry.pointInTriangle', () {
    // Apex at top-centre, base along the bottom edge. On a y-down canvas
    // that vertex order winds clockwise, so every interior cross product is
    // negative — and a predicate demanding `>= 0` was false everywhere, which
    // is how triangles shipped unclickable.
    const rect = Rect.fromLTWH(0, 0, 100, 100);

    test('centre is inside', () {
      expect(
        SketchGeometry.pointInTriangle(const Offset(50, 60), rect, 0),
        isTrue,
      );
    });

    test('bbox corners outside the triangle are outside', () {
      // Top corners of the bounding box are empty space beside the apex.
      expect(
        SketchGeometry.pointInTriangle(const Offset(0, 0), rect, 0),
        isFalse,
      );
      expect(
        SketchGeometry.pointInTriangle(const Offset(100, 0), rect, 0),
        isFalse,
      );
      // Well clear of the base.
      expect(
        SketchGeometry.pointInTriangle(const Offset(50, 110), rect, 0),
        isFalse,
      );
    });

    test('just inside each edge is inside, just outside is not', () {
      // Base: y = 100.
      expect(
        SketchGeometry.pointInTriangle(const Offset(50, 99), rect, 0),
        isTrue,
      );
      expect(
        SketchGeometry.pointInTriangle(const Offset(50, 101), rect, 0),
        isFalse,
      );
      // Left edge runs (50,0)→(0,100): at y=50 it passes x=25.
      expect(
        SketchGeometry.pointInTriangle(const Offset(26, 50), rect, 0),
        isTrue,
      );
      expect(
        SketchGeometry.pointInTriangle(const Offset(24, 50), rect, 0),
        isFalse,
      );
      // Right edge runs (50,0)→(100,100): at y=50 it passes x=75.
      expect(
        SketchGeometry.pointInTriangle(const Offset(74, 50), rect, 0),
        isTrue,
      );
      expect(
        SketchGeometry.pointInTriangle(const Offset(76, 50), rect, 0),
        isFalse,
      );
    });

    test('vertices and edges are on the boundary (inclusive)', () {
      expect(
        SketchGeometry.pointInTriangle(const Offset(50, 0), rect, 0),
        isTrue,
      );
      expect(
        SketchGeometry.pointInTriangle(const Offset(50, 100), rect, 0),
        isTrue,
      );
    });

    test('honours rotation about the centre', () {
      // Rotated a half turn the base runs along the top: the top-left bbox
      // corner, empty before, is now inside, and the bottom-left corner,
      // inside before, is now empty.
      expect(
        SketchGeometry.pointInTriangle(const Offset(5, 5), rect, 0),
        isFalse,
      );
      expect(
        SketchGeometry.pointInTriangle(const Offset(5, 5), rect, math.pi),
        isTrue,
      );
      expect(
        SketchGeometry.pointInTriangle(const Offset(5, 95), rect, 0),
        isTrue,
      );
      expect(
        SketchGeometry.pointInTriangle(const Offset(5, 95), rect, math.pi),
        isFalse,
      );
    });
  });

  group('SketchGeometry.toLocal / rotateAbout', () {
    const centre = Offset(100, 100);

    test('are inverses of each other', () {
      const p = Offset(130, 80);
      final world = SketchGeometry.rotateAbout(p, centre, 0.7);
      final back = SketchGeometry.toLocal(world, centre, 0.7);
      expect(back.dx, closeTo(p.dx, 1e-9));
      expect(back.dy, closeTo(p.dy, 1e-9));
    });

    test('a zero angle is the identity', () {
      const p = Offset(130, 80);
      expect(SketchGeometry.rotateAbout(p, centre, 0), p);
      expect(SketchGeometry.toLocal(p, centre, 0), p);
    });

    test('a quarter turn sends +x to +y on a y-down canvas', () {
      final r = SketchGeometry.rotateAbout(
          const Offset(110, 100), centre, math.pi / 2);
      expect(r.dx, closeTo(100, 1e-9));
      expect(r.dy, closeTo(110, 1e-9));
    });
  });

  group('SketchGeometry.endpointsOf', () {
    test('reports the stored endpoints of lines and arrows only', () {
      final line = SketchLine.create(
          start: const Offset(1, 2), end: const Offset(3, 4));
      final arrow = SketchArrow.create(
          start: const Offset(5, 6), end: const Offset(7, 8));
      expect(SketchGeometry.endpointsOf(line),
          (const Offset(1, 2), const Offset(3, 4)));
      expect(SketchGeometry.endpointsOf(arrow),
          (const Offset(5, 6), const Offset(7, 8)));
      expect(
        SketchGeometry.endpointsOf(
          SketchRectangle.create(rect: const Rect.fromLTWH(0, 0, 9, 9)),
        ),
        isNull,
      );
    });
  });

  group('SketchGeometry.rectsTouch', () {
    const region = Rect.fromLTRB(0, 0, 100, 100);

    test('a shared edge counts as touching', () {
      const flush = Rect.fromLTRB(100, 0, 150, 50);
      expect(flush.overlaps(region), isFalse, reason: 'Rect.overlaps says no');
      expect(SketchGeometry.rectsTouch(flush, region), isTrue);
    });

    test("an axis-aligned line's bounds are nothing but such an edge", () {
      // Which is why this matters: a band drawn flush along a horizontal
      // connector visibly covers it, but Rect.overlaps calls them disjoint.
      const wire = Rect.fromLTRB(100, 200, 300, 200);
      const band = Rect.fromLTRB(80, 200, 320, 260);
      expect(wire.overlaps(band), isFalse);
      expect(SketchGeometry.rectsTouch(wire, band), isTrue);
    });

    test('a zero-height rect strictly inside touches, as it always did', () {
      const flat = Rect.fromLTRB(10, 50, 90, 50);
      expect(flat.overlaps(region), isTrue);
      expect(SketchGeometry.rectsTouch(flat, region), isTrue);
    });

    test('a rect clear of the region does not touch it', () {
      expect(
        SketchGeometry.rectsTouch(
            const Rect.fromLTRB(101, 50, 150, 50), region),
        isFalse,
      );
    });
  });

  group('SketchGeometry.segmentIntersectsRect', () {
    const region = Rect.fromLTRB(100, 100, 200, 200);

    test('a segment crossing the rect intersects it', () {
      expect(
        SketchGeometry.segmentIntersectsRect(
            const Offset(0, 150), const Offset(300, 150), region),
        isTrue,
      );
    });

    test('a segment wholly inside intersects it', () {
      expect(
        SketchGeometry.segmentIntersectsRect(
            const Offset(120, 120), const Offset(180, 180), region),
        isTrue,
      );
    });

    test('a segment running parallel and clear of an edge does not', () {
      // The case four edge-crossing tests are fiddliest about.
      expect(
        SketchGeometry.segmentIntersectsRect(
            const Offset(0, 250), const Offset(300, 250), region),
        isFalse,
      );
    });

    test('a diagonal missing the rect does not, despite crossing its span',
        () {
      // Spans the rect's x range and its y range, but never both at once.
      expect(
        SketchGeometry.segmentIntersectsRect(
            const Offset(0, 0), const Offset(400, 400), region),
        isTrue,
        reason: 'this one really does pass through',
      );
      expect(
        SketchGeometry.segmentIntersectsRect(
            const Offset(0, 400), const Offset(90, 0), region),
        isFalse,
      );
    });

    test('a zero-length segment reduces to a point-in-rect test', () {
      expect(
        SketchGeometry.segmentIntersectsRect(
            const Offset(150, 150), const Offset(150, 150), region),
        isTrue,
      );
      expect(
        SketchGeometry.segmentIntersectsRect(
            const Offset(50, 50), const Offset(50, 50), region),
        isFalse,
      );
    });

    test('touching an edge counts', () {
      expect(
        SketchGeometry.segmentIntersectsRect(
            const Offset(0, 100), const Offset(300, 100), region),
        isTrue,
      );
    });
  });

  group('SketchGeometry.handlePosition', () {
    const rect = Rect.fromLTRB(10, 20, 110, 220);

    test('places all eight handles on the box', () {
      expect(SketchGeometry.handlePosition(rect, ResizeHandle.topLeft),
          const Offset(10, 20));
      expect(SketchGeometry.handlePosition(rect, ResizeHandle.top),
          const Offset(60, 20));
      expect(SketchGeometry.handlePosition(rect, ResizeHandle.topRight),
          const Offset(110, 20));
      expect(SketchGeometry.handlePosition(rect, ResizeHandle.right),
          const Offset(110, 120));
      expect(SketchGeometry.handlePosition(rect, ResizeHandle.bottomRight),
          const Offset(110, 220));
      expect(SketchGeometry.handlePosition(rect, ResizeHandle.bottom),
          const Offset(60, 220));
      expect(SketchGeometry.handlePosition(rect, ResizeHandle.bottomLeft),
          const Offset(10, 220));
      expect(SketchGeometry.handlePosition(rect, ResizeHandle.left),
          const Offset(10, 120));
    });
  });

  group('SketchGeometry.resizeRect', () {
    const start = Rect.fromLTRB(100, 100, 300, 200);

    test('a corner handle anchors the opposite corner', () {
      expect(
        SketchGeometry.resizeRect(
            start, ResizeHandle.topLeft, const Offset(-40, -30)),
        const Rect.fromLTRB(60, 70, 300, 200),
      );
      expect(
        SketchGeometry.resizeRect(
            start, ResizeHandle.bottomRight, const Offset(40, 30)),
        const Rect.fromLTRB(100, 100, 340, 230),
      );
      expect(
        SketchGeometry.resizeRect(
            start, ResizeHandle.topRight, const Offset(40, -30)),
        const Rect.fromLTRB(100, 70, 340, 200),
      );
      expect(
        SketchGeometry.resizeRect(
            start, ResizeHandle.bottomLeft, const Offset(-40, 30)),
        const Rect.fromLTRB(60, 100, 300, 230),
      );
    });

    test('an edge handle leaves the other axis alone', () {
      expect(
        SketchGeometry.resizeRect(
            start, ResizeHandle.left, const Offset(-40, 999)),
        const Rect.fromLTRB(60, 100, 300, 200),
      );
      expect(
        SketchGeometry.resizeRect(
            start, ResizeHandle.bottom, const Offset(999, 30)),
        const Rect.fromLTRB(100, 100, 300, 230),
      );
    });

    test('dragging past the anchor clamps at minSize instead of flipping', () {
      // 500px of leftward travel on a 200px-wide box.
      final r = SketchGeometry.resizeRect(
        start,
        ResizeHandle.right,
        const Offset(-500, 0),
        minSize: 10,
      );
      expect(r.left, 100, reason: 'the anchored edge must not move');
      expect(r.width, 10);
    });

    test('preserveAspect holds the original ratio on a corner', () {
      // 2:1, widened by 100 with no vertical pointer travel at all.
      final r = SketchGeometry.resizeRect(
        start,
        ResizeHandle.bottomRight,
        const Offset(100, 0),
        preserveAspect: true,
      );
      expect(r, const Rect.fromLTRB(100, 100, 400, 250));
      expect(r.width / r.height, closeTo(start.width / start.height, 1e-9));
    });

    test('preserveAspect follows whichever axis the pointer took further', () {
      final r = SketchGeometry.resizeRect(
        start,
        ResizeHandle.bottomRight,
        const Offset(0, 100),
        preserveAspect: true,
      );
      expect(r, const Rect.fromLTRB(100, 100, 500, 300));
    });

    test('preserveAspect is a no-op on an edge handle', () {
      // One axis of travel, so there is no second axis to constrain.
      expect(
        SketchGeometry.resizeRect(
          start,
          ResizeHandle.right,
          const Offset(100, 0),
          preserveAspect: true,
        ),
        const Rect.fromLTRB(100, 100, 400, 200),
      );
    });
  });
}
