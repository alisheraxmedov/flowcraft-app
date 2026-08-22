import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/core/interactions/sketch_snapping.dart';

void main() {
  group('SketchSnapper grid', () {
    const snapper = SketchSnapper(threshold: 6, gridSpacing: 24);

    test('pulls a value inside the threshold onto the nearest line', () {
      final result = snapper.resolve(
        moving: const Rect.fromLTWH(117, 117, 48, 48),
        xs: const <double>[117],
        ys: const <double>[117],
        candidates: const <Rect>[],
      );
      expect(result.delta, const Offset(3, 3));
    });

    test('leaves a value outside the threshold alone', () {
      final result = snapper.resolve(
        moving: const Rect.fromLTWH(110, 110, 48, 48),
        xs: const <double>[110],
        ys: const <double>[110],
        candidates: const <Rect>[],
      );
      expect(result.delta, Offset.zero);
    });

    test('draws no guide — the dots on screen are the explanation', () {
      final result = snapper.resolve(
        moving: const Rect.fromLTWH(117, 117, 48, 48),
        xs: const <double>[117],
        ys: const <double>[117],
        candidates: const <Rect>[],
      );
      expect(result.guides, isEmpty);
    });

    test('gridXs may differ from xs, so a move can pin only its origin', () {
      // The trailing edge is 1px off a grid line and would win outright if
      // the grid saw it; only the (13px-off) left edge is offered, so
      // nothing snaps.
      final result = snapper.resolve(
        moving: const Rect.fromLTRB(107, 107, 145, 145),
        xs: const <double>[107, 145],
        ys: const <double>[107, 145],
        candidates: const <Rect>[],
        gridXs: const <double>[107],
        gridYs: const <double>[107],
      );
      expect(result.delta, Offset.zero);
    });

    test('bows out once the magnet reaches half the spacing', () {
      // At 0.25x zoom a 6px screen magnet is 24 canvas px, which is the
      // whole grid pitch: every position would be "on grid", so grid
      // snapping stops being a magnet and turns itself off.
      const zoomedOut = SketchSnapper(threshold: 24, gridSpacing: 24);
      final result = zoomedOut.resolve(
        moving: const Rect.fromLTWH(110, 110, 48, 48),
        xs: const <double>[110],
        ys: const <double>[110],
        candidates: const <Rect>[],
      );
      expect(result.delta, Offset.zero);
    });

    test('a null spacing disables the grid without touching alignment', () {
      const noGrid = SketchSnapper(threshold: 6);
      final result = noGrid.resolve(
        moving: const Rect.fromLTWH(117, 117, 48, 48),
        xs: const <double>[117],
        ys: const <double>[117],
        candidates: const <Rect>[Rect.fromLTWH(120, 300, 40, 40)],
      );
      expect(result.delta, const Offset(3, 0));
    });
  });

  group('SketchSnapper alignment', () {
    const snapper = SketchSnapper(threshold: 6);
    const target = Rect.fromLTRB(400, 100, 500, 200);

    test('lines an edge up with another element and explains it', () {
      final moving = const Rect.fromLTRB(404, 300, 464, 360);
      final result = snapper.resolve(
        moving: moving,
        xs: <double>[moving.left, moving.center.dx, moving.right],
        ys: <double>[moving.top, moving.center.dy, moving.bottom],
        candidates: const <Rect>[target],
      );
      expect(result.delta, const Offset(-4, 0));
      expect(result.guides, hasLength(1));
      final guide = result.guides.single;
      expect(guide.vertical, isTrue);
      expect(guide.position, 400);
      // Spans both boxes, so the pairing needs no further decoration.
      expect(guide.from, 100);
      expect(guide.to, 360);
    });

    test('centres count as targets, not just edges', () {
      // Moving centre at 454 against the target's centre at 450.
      final moving = const Rect.fromLTRB(444, 300, 464, 320);
      final result = snapper.resolve(
        moving: moving,
        xs: <double>[moving.left, moving.center.dx, moving.right],
        ys: const <double>[],
        candidates: const <Rect>[target],
      );
      expect(result.delta, const Offset(-4, 0));
      expect(result.guides.single.position, 450);
    });

    test('beats the grid on the axis it wins', () {
      const withGrid = SketchSnapper(threshold: 6, gridSpacing: 24);
      // 404 is 4 from the element edge at 400 and 3 from the grid line at
      // 408. The nearer grid line still loses: only an alignment can be
      // drawn as a guide, so it takes the axis outright.
      final result = withGrid.resolve(
        moving: const Rect.fromLTRB(404, 300, 464, 360),
        xs: const <double>[404],
        ys: const <double>[],
        candidates: const <Rect>[target],
      );
      expect(result.delta, const Offset(-4, 0));
      expect(result.guides, hasLength(1));
    });

    test('ignores elements beyond the search radius', () {
      const nearSighted = SketchSnapper(threshold: 6, searchRadius: 50);
      final result = nearSighted.resolve(
        moving: const Rect.fromLTRB(404, 300, 464, 360),
        xs: const <double>[404],
        ys: const <double>[],
        candidates: const <Rect>[target],
      );
      expect(result.delta, Offset.zero);
    });

    test('finds candidates around a zero-area moving box', () {
      // An endpoint drag's "box" is a single point, which Rect.overlaps
      // reports as touching nothing at all.
      final result = snapper.resolve(
        moving: Rect.fromCenter(
          center: const Offset(404, 300),
          width: 0,
          height: 0,
        ),
        xs: const <double>[404],
        ys: const <double>[300],
        candidates: const <Rect>[target],
      );
      expect(result.delta, const Offset(-4, 0));
    });
  });
}
