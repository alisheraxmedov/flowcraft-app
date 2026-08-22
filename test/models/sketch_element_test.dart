import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/core/domain/sticky_bubble_geometry.dart';
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

  group('SketchSticky.collapsed', () {
    const rect = Rect.fromLTWH(120, 60, 200, 90);

    SketchSticky note({bool collapsed = false}) => SketchSticky.create(
          id: 'note',
          rect: rect,
          text: 'remember this',
          collapsed: collapsed,
        );

    test('bounds are the badge when collapsed and the rect when not', () {
      expect(note().bounds, rect);
      expect(
        note(collapsed: true).bounds,
        StickyBubbleGeometry.collapsedBounds(rect),
      );
      // Anchored at the bubble's own origin, so toggling can't teleport a
      // note across the canvas.
      expect(note(collapsed: true).bounds.topLeft, rect.topLeft);
    });

    test('collapsing keeps the expanded geometry, so expanding restores it',
        () {
      final original = note();
      final roundTripped = original.copyWith(collapsed: true).copyWith(
            collapsed: false,
          );
      expect(roundTripped.rect, original.rect);
      expect(roundTripped.bounds, original.bounds);
      expect(roundTripped.text, original.text);
      expect(roundTripped.fontSize, original.fontSize);
      // Even while collapsed, the bubble's geometry is still on the element
      // — it is only `bounds` that shrinks.
      expect(original.copyWith(collapsed: true).rect, rect);
    });

    test('round-trips through JSON', () {
      final restored =
          SketchElement.fromJson(note(collapsed: true).toJson()) as SketchSticky;
      expect(restored.collapsed, isTrue);
      expect(restored.rect, rect);
      expect(restored.bounds, StickyBubbleGeometry.collapsedBounds(rect));
    });

    test('stays out of the JSON of an expanded note', () {
      // Adding the field must not change what an existing scene serialises
      // to — that is what keeps this a schema-version-1 payload.
      expect(note().toJson().containsKey('collapsed'), isFalse);
    });

    test('defaults to false in a payload written before it existed', () {
      // Verbatim sticky as builds before `collapsed` wrote it, down to the
      // 4px corner radius and 20pt label those builds defaulted to.
      final restored = SketchElement.fromJson(<String, dynamic>{
        'type': 'sticky',
        'id': 's1',
        'style': const SketchStyle().toJson(),
        'rect': {'l': 10.0, 't': 20.0, 'w': 160.0, 'h': 80.0},
        'angle': 0.0,
        'cornerRadius': 4.0,
        'text': 'old note',
        'fontSize': 20.0,
      }) as SketchSticky;
      expect(restored.collapsed, isFalse);
      expect(restored.bounds, const Rect.fromLTWH(10, 20, 160, 80));
      // The note keeps the numbers it was saved with, rather than being
      // silently restyled by this build's new defaults.
      expect(restored.cornerRadius, 4.0);
      expect(restored.fontSize, 20.0);
    });

    test('survives every transform', () {
      final collapsed = note(collapsed: true);
      expect(collapsed.translate(const Offset(9, 9)).collapsed, isTrue);
      expect(
        collapsed.copyWithStyle(const SketchStyle(strokeWidth: 4)).collapsed,
        isTrue,
      );
      expect(collapsed.withId('other').collapsed, isTrue);
      expect(collapsed.withGroupId('g').collapsed, isTrue);
      expect(collapsed.withGroupId('g').withGroupId(null).collapsed, isTrue);
    });

    test('a collapsed note moves as its badge, not as its bubble', () {
      const delta = Offset(15, -25);
      final moved = note(collapsed: true).translate(delta);
      expect(moved.bounds, note(collapsed: true).bounds.shift(delta));
      expect(moved.rect, rect.shift(delta));
    });
  });

  group('SketchSticky sizing', () {
    test('a press with no drag still yields a usable note', () {
      // A 0x0 drag rect used to be discarded by the commit path, so clicking
      // with the sticky tool created nothing at all.
      final settled = SketchSticky.rectFor(
        const Rect.fromLTWH(50, 50, 0, 0),
      );
      expect(settled.topLeft, const Offset(50, 50));
      expect(settled.size, SketchSticky.defaultSize);
    });

    test('a drag larger than the default is left alone', () {
      const drawn = Rect.fromLTWH(0, 0, 400, 300);
      expect(SketchSticky.rectFor(drawn), drawn);
    });

    test('each axis is floored independently', () {
      final settled = SketchSticky.rectFor(const Rect.fromLTWH(0, 0, 400, 5));
      expect(settled.width, 400);
      expect(settled.height, SketchSticky.defaultSize.height);
    });

    test('a note labels at the same size as every other element', () {
      // 20pt against everything else's 16 is most of what made notes feel
      // oversized: the note has to be dragged big enough to hold its label.
      expect(SketchSticky.defaultFontSize, 16.0);
      expect(
        SketchSticky.create(rect: const Rect.fromLTWH(0, 0, 10, 10)).fontSize,
        16.0,
      );
    });
  });

  group('SketchSticky.inkColor', () {
    SketchSticky painted(Color stroke, Color fill) => SketchSticky.create(
          rect: const Rect.fromLTWH(0, 0, 10, 10),
          style: SketchStyle(
            strokeColor: stroke,
            fillColor: fill,
            fillStyle: FillStyle.solid,
          ),
        );

    test('is legible on the default note, where stroke *is* the paper', () {
      // `create` sets stroke and fill from one colour, so glyphs drawn in
      // the stroke colour are invisible against the note carrying them.
      final ink = SketchSticky.create(
        rect: const Rect.fromLTWH(0, 0, 10, 10),
      ).inkColor;
      expect(ink, isNot(SketchSticky.defaultColor));
      expect(ink.computeLuminance(),
          lessThan(SketchSticky.defaultColor.computeLuminance()));
    });

    test('flips for a dark note', () {
      const dark = Color(0xFF20242C);
      expect(
        painted(dark, dark).inkColor.computeLuminance(),
        greaterThan(dark.computeLuminance()),
      );
    });

    test('honours a stroke colour the user made different from the fill', () {
      const ink = Color(0xFFAA0000);
      expect(painted(ink, SketchSticky.defaultColor).inkColor, ink);
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
