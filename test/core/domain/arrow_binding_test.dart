import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/core/domain/arrow_binding.dart';
import 'package:flowcraft/core/domain/sketch_geometry.dart';
import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/models/sketch_style.dart';

const _box = Rect.fromLTWH(0, 0, 200, 100); // centre (100, 50)

SketchRectangle _rect(String id, [Rect rect = _box]) =>
    SketchRectangle.create(id: id, rect: rect);

Map<String, SketchElement> _map(List<SketchElement> els) => {
  for (final e in els) e.id: e,
};

/// The point sits on the outline: just inside it is in, just outside is out.
void _expectOnOutline(
  SketchElement shape,
  Offset p,
  bool Function(Offset) inside,
) {
  final dir = (p - shape.unrotatedBounds.center);
  final unit = dir / dir.distance;
  expect(inside(p - unit * 0.01), isTrue, reason: 'just inside');
  expect(inside(p + unit * 0.01), isFalse, reason: 'just outside');
}

void main() {
  group('ArrowBinding.boundaryPoint', () {
    final toward = const Offset(500, 300);

    test('rectangle lands on the edge, not the corner', () {
      final r = _rect('r');
      final p = ArrowBinding.boundaryPoint(r, toward);
      _expectOnOutline(r, p, (q) => _box.contains(q));
      expect(p, isNot(const Offset(200, 100)));
    });

    test('ellipse lands on the true outline', () {
      final e = SketchEllipse.create(id: 'e', rect: _box);
      final p = ArrowBinding.boundaryPoint(e, toward);
      _expectOnOutline(e, p, (q) => SketchGeometry.pointInEllipse(q, _box, 0));
      expect(
        (p - _box.center).distance,
        lessThan(_box.size.bottomRight(Offset.zero).distance / 2),
      );
    });

    test('diamond lands on the true outline', () {
      final d = SketchDiamond.create(id: 'd', rect: _box);
      final p = ArrowBinding.boundaryPoint(d, toward);
      _expectOnOutline(d, p, (q) => SketchGeometry.pointInDiamond(q, _box, 0));
    });

    test('triangle lands on the true outline', () {
      final t = SketchTriangle.create(id: 't', rect: _box);
      final p = ArrowBinding.boundaryPoint(t, const Offset(100, 500));
      _expectOnOutline(t, p, (q) => SketchGeometry.pointInTriangle(q, _box, 0));
      expect(p.dy, closeTo(100, 0.01)); // base edge
    });

    test('gap moves the point outward along the ray', () {
      final r = _rect('r');
      final p = ArrowBinding.boundaryPoint(r, const Offset(500, 50), gap: 10);
      expect(p.dx, closeTo(210, 0.01));
      expect(p.dy, closeTo(50, 0.01));
    });

    test('an anchor inside the shape still exits the outline', () {
      final r = _rect('r');
      final p = ArrowBinding.boundaryPoint(r, const Offset(120, 50));
      expect(p.dx, closeTo(200, 0.01));
    });

    test('a rotated rectangle honours its angle', () {
      final r = SketchRectangle(
        id: 'r',
        style: const SketchStyle(),
        rect: _box,
        angle: math.pi / 2,
      );
      final p = ArrowBinding.boundaryPoint(r, const Offset(500, 50));
      expect(p.dx, closeTo(150, 0.01)); // half the *short* side now
    });

    test('toward == centre returns the centre', () {
      expect(ArrowBinding.boundaryPoint(_rect('r'), _box.center), _box.center);
    });
  });

  group('ArrowBinding.targetAt', () {
    test('picks the topmost bindable and skips the excluded id', () {
      final els = [_rect('under'), _rect('over')];
      expect(ArrowBinding.targetAt(els, const Offset(50, 50), 0)!.id, 'over');
      expect(
        ArrowBinding.targetAt(
          els,
          const Offset(50, 50),
          0,
          exclude: 'over',
        )!.id,
        'under',
      );
    });

    test('skips lines, text and arrows', () {
      final els = <SketchElement>[
        _rect('r'),
        SketchLine.create(
          id: 'l',
          start: Offset.zero,
          end: const Offset(100, 100),
        ),
        SketchArrow.create(
          id: 'a',
          start: Offset.zero,
          end: const Offset(100, 100),
        ),
        SketchText.create(id: 't', position: const Offset(10, 10), text: 'hi'),
      ];
      expect(ArrowBinding.targetAt(els, const Offset(50, 50), 0)!.id, 'r');
    });

    test('uses inflated bounds', () {
      final els = [_rect('r')];
      expect(ArrowBinding.targetAt(els, const Offset(-5, 50), 0), isNull);
      expect(ArrowBinding.targetAt(els, const Offset(-5, 50), 8)!.id, 'r');
    });
  });

  group('ArrowBinding.resolve', () {
    final a = _rect('a', const Rect.fromLTWH(0, 0, 100, 100));
    final b = _rect('b', const Rect.fromLTWH(300, 0, 100, 100));

    SketchArrow arrow({SketchBinding? s, SketchBinding? e}) =>
        SketchArrow.create(
          id: 'arr',
          start: const Offset(7, 7),
          end: const Offset(8, 8),
        ).copyWith(startBinding: s, endBinding: e);

    test('both-bound ends aim at the other shape centre', () {
      final r = ArrowBinding.resolve(
        arrow(
          s: const SketchBinding(elementId: 'a'),
          e: const SketchBinding(elementId: 'b'),
        ),
        _map([a, b]),
      );
      expect(r.start.dx, closeTo(100, 0.01));
      expect(r.start.dy, closeTo(50, 0.01));
      expect(r.end.dx, closeTo(300, 0.01));
      expect(r.end.dy, closeTo(50, 0.01));
    });

    test('drops a dangling binding and leaves the point', () {
      final r = ArrowBinding.resolve(
        arrow(s: const SketchBinding(elementId: 'gone')),
        _map([a]),
      );
      expect(r.startBinding, isNull);
      expect(r.start, const Offset(7, 7));
    });

    test('drops the end binding when both ends bind the same shape', () {
      final r = ArrowBinding.resolve(
        arrow(
          s: const SketchBinding(elementId: 'a'),
          e: const SketchBinding(elementId: 'a'),
        ),
        _map([a]),
      );
      expect(r.startBinding, isNotNull);
      expect(r.endBinding, isNull);
    });

    test('returns the identical instance when unchanged', () {
      final first = ArrowBinding.resolve(
        arrow(
          s: const SketchBinding(elementId: 'a'),
          e: const SketchBinding(elementId: 'b'),
        ),
        _map([a, b]),
      );
      expect(ArrowBinding.resolve(first, _map([a, b])), same(first));
      final plain = arrow();
      expect(ArrowBinding.resolve(plain, _map([a])), same(plain));
    });
  });

  group('phase 2 targets', () {
    test('elbowed end at side midpoint', () {
      final a = _rect('a');
      final b = _rect('b', const Rect.fromLTWH(400, 40, 200, 100));
      final arrow =
          SketchArrow.create(
            start: const Offset(1, 1),
            end: const Offset(2, 2),
            elbowed: true,
          ).copyWith(
            startBinding: const SketchBinding(elementId: 'a', gap: 4),
            endBinding: const SketchBinding(elementId: 'b'),
          );
      final r = ArrowBinding.resolve(arrow, _map([a, b]));
      expect(r.start, const Offset(204, 50));
      expect(r.end, const Offset(400, 90));
    });

    test('entity attribute anchor hits the row centre on the facing edge', () {
      final e = SketchEntity.create(
        rect: const Rect.fromLTWH(0, 0, 200, 0),
        name: 'User',
        attributes: const [
          EntityAttribute(name: 'id'),
          EntityAttribute(name: 'email'),
        ],
      );
      final b = _rect('b', const Rect.fromLTWH(400, 0, 100, 100));
      final arrow =
          SketchArrow.create(
            start: Offset.zero,
            end: const Offset(1, 1),
          ).copyWith(
            startBinding: SketchBinding(elementId: e.id, attribute: 'email'),
            endBinding: const SketchBinding(elementId: 'b'),
          );
      final r = ArrowBinding.resolve(arrow, _map([e, b]));
      expect(r.start, Offset(200, e.rowCenterY('email')!));
      final unknown = arrow.copyWith(
        startBinding: SketchBinding(elementId: e.id, attribute: 'nope'),
      );
      final u = ArrowBinding.resolve(unknown, _map([e, b]));
      expect(u.start.dx, closeTo(200, 0.01));
      expect(u.start.dy, isNot(e.rowCenterY('email')));
    });

    test('icon/image/entity bindable, frame not', () {
      const r = Rect.fromLTWH(0, 0, 10, 10);
      expect(
        ArrowBinding.isBindable(SketchIcon.create(rect: r, name: 'x')),
        isTrue,
      );
      expect(
        ArrowBinding.isBindable(
          SketchImage.create(
            rect: r,
            mimeType: 'image/png',
            bytes: Uint8List(1),
          ),
        ),
        isTrue,
      );
      expect(ArrowBinding.isBindable(SketchEntity.create(rect: r)), isTrue);
      expect(ArrowBinding.isBindable(SketchFrame.create(rect: r)), isFalse);
    });
  });
}
