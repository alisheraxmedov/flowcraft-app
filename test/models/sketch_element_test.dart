import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/models/sketch_style.dart';

/// Regression coverage for [SketchText.bounds].
///
/// It used to approximate its width as `text.length * fontSize * 0.55` while
/// the painter drew real, `TextPainter`-measured glyphs at the same origin.
/// Any click on a glyph past the guess missed the element, which is how the
/// text tool ended up creating a second, empty text box on top of the first.
void main() {
  group('SketchText.bounds', () {
    Size measured(String text, double fontSize, {String? fontFamily}) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontSize: fontSize, fontFamily: fontFamily),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final size = painter.size;
      painter.dispose();
      return size;
    }

    test('matches what TextPainter actually lays out', () {
      final t = SketchText.create(
        position: const Offset(12, 34),
        text: 'Hello world',
        fontSize: 16,
      );
      expect(t.bounds.topLeft, const Offset(12, 34));
      expect(t.bounds.size, measured('Hello world', 16));
    });

    test('tracks fontSize and fontFamily', () {
      final big = SketchText.create(
        position: Offset.zero,
        text: 'Hello',
        fontSize: 32,
      );
      expect(big.bounds.size, measured('Hello', 32));

      final mono = SketchText.create(
        position: Offset.zero,
        text: 'Hello',
        fontSize: 16,
        fontFamily: 'JetBrains Mono',
      );
      expect(mono.bounds.size, measured('Hello', 16, fontFamily: 'JetBrains Mono'));
    });

    test('is wider than the approximation it replaced', () {
      final t = SketchText.create(
        position: Offset.zero,
        text: 'Hello',
        fontSize: 16,
      );
      // Old guess: max(fontSize, length * fontSize * 0.55) = 44px.
      expect(t.bounds.width, greaterThan(5 * 16 * 0.55));
    });

    test('shifts with the element', () {
      final t = SketchText.create(
        position: const Offset(5, 5),
        text: 'Hello',
        fontSize: 16,
      );
      final moved = t.translate(const Offset(10, 20));
      expect(moved.bounds, t.bounds.shift(const Offset(10, 20)));
    });
  });

  group('SketchElement.groupId', () {
    test('round-trips through JSON for every subtype', () {
      for (final el in _oneOfEachSubtype()) {
        final grouped = el.withGroupId('group-1');
        final restored = SketchElement.fromJson(grouped.toJson());
        expect(restored.runtimeType, el.runtimeType);
        expect(restored.id, el.id, reason: '${el.runtimeType}');
        expect(restored.groupId, 'group-1', reason: '${el.runtimeType}');
      }
    });

    test('survives every transform, for every subtype', () {
      for (final el in _oneOfEachSubtype()) {
        final grouped = el.withGroupId('group-1');
        final reason = '${el.runtimeType}';

        // A group that dissolves the moment it is dragged or restyled is
        // worse than no grouping at all. `copyWithStyle` is each subtype's
        // own `copyWith` underneath, so this covers those too.
        expect(grouped.translate(const Offset(3, 4)).groupId, 'group-1',
            reason: reason);
        expect(
          grouped.copyWithStyle(const SketchStyle(strokeWidth: 4)).groupId,
          'group-1',
          reason: reason,
        );

        final recopied = grouped.withId('fresh');
        expect(recopied.id, 'fresh', reason: reason);
        expect(recopied.groupId, 'group-1', reason: reason);
      }
    });

    test('withGroupId(null) ungroups, for every subtype', () {
      for (final el in _oneOfEachSubtype()) {
        final ungrouped = el.withGroupId('group-1').withGroupId(null);
        expect(ungrouped.groupId, isNull, reason: '${el.runtimeType}');
        expect(
          SketchElement.fromJson(ungrouped.toJson()).groupId,
          isNull,
          reason: '${el.runtimeType}',
        );
      }
    });

    test('stays out of the JSON of an ungrouped element', () {
      // Adding the field must not change what a scene without groups
      // serialises to — that is what keeps it a version-1 payload.
      for (final el in _oneOfEachSubtype()) {
        expect(el.toJson().containsKey('groupId'), isFalse,
            reason: '${el.runtimeType}');
      }
    });

    test('defaults to null in a payload written before it existed', () {
      // Verbatim v1 rectangle, as builds before groupId wrote it.
      final restored = SketchElement.fromJson(<String, dynamic>{
        'type': 'rectangle',
        'id': 'r1',
        'style': const SketchStyle().toJson(),
        'rect': {'l': 0.0, 't': 0.0, 'w': 10.0, 'h': 10.0},
        'cornerRadius': 0.0,
        'angle': 0.0,
        'fontSize': 16.0,
      });
      expect(restored.id, 'r1');
      expect(restored.groupId, isNull);
    });

    test('ignores keys it does not know', () {
      // The other half of "adding a field stays version-1-compatible in
      // both directions": a payload from a build that knows more fields
      // than this one still loads, because unknown keys are skipped.
      final restored = SketchElement.fromJson(<String, dynamic>{
        ...SketchRectangle.create(
          id: 'r1',
          rect: const Rect.fromLTWH(0, 0, 10, 10),
        ).toJson(),
        'someFieldFromTheFuture': {'nested': true},
      });
      expect(restored.id, 'r1');
    });
  });

  group('SketchArrow bindings (reserved)', () {
    const binding = SketchBinding(elementId: 'shape-1', focus: 0.25, gap: 4);

    SketchArrow arrow() => SketchArrow.create(
          id: 'a1',
          start: Offset.zero,
          end: const Offset(30, 30),
        );

    test('default to null and stay out of the JSON', () {
      final json = arrow().toJson();
      expect(arrow().startBinding, isNull);
      expect(arrow().endBinding, isNull);
      expect(json.containsKey('startBinding'), isFalse);
      expect(json.containsKey('endBinding'), isFalse);
    });

    test('round-trip through JSON', () {
      final bound = arrow().copyWith(
        startBinding: binding,
        endBinding: const SketchBinding(elementId: 'shape-2'),
      );
      final restored = SketchElement.fromJson(bound.toJson()) as SketchArrow;
      expect(restored.startBinding, binding);
      expect(restored.endBinding, const SketchBinding(elementId: 'shape-2'));
    });

    test('survive translate and restyle', () {
      final bound = arrow().copyWith(startBinding: binding);
      expect(bound.translate(const Offset(5, 5)).startBinding, binding);
      expect(
        bound.copyWithStyle(const SketchStyle(strokeWidth: 3)).startBinding,
        binding,
      );
    });

    test('can be cleared', () {
      final bound = arrow().copyWith(startBinding: binding);
      expect(bound.copyWith(startBinding: null).startBinding, isNull);
    });
  });
}

/// One instance of every [SketchElement] subtype, so a per-subtype rule can
/// be asserted for all of them instead of whichever one the test author
/// happened to pick.
List<SketchElement> _oneOfEachSubtype() {
  const rect = Rect.fromLTWH(4, 8, 40, 20);
  return <SketchElement>[
    SketchRectangle.create(id: 'rectangle', rect: rect, text: 'label'),
    SketchEllipse.create(id: 'ellipse', rect: rect),
    SketchDiamond.create(id: 'diamond', rect: rect),
    SketchTriangle.create(id: 'triangle', rect: rect),
    SketchSticky.create(id: 'sticky', rect: rect, text: 'note'),
    SketchLine.create(
      id: 'line',
      start: Offset.zero,
      end: const Offset(10, 10),
    ),
    SketchArrow.create(
      id: 'arrow',
      start: Offset.zero,
      end: const Offset(10, 10),
    ),
    SketchFreedraw.create(
      id: 'freedraw',
      points: const [Offset(0, 0), Offset(5, 5)],
    ),
    SketchText.create(id: 'text', position: Offset.zero, text: 'hello'),
  ];
}
