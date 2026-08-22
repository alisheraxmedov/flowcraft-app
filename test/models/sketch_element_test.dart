import 'dart:convert';
import 'dart:math' as math;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/core/domain/sticky_bubble_geometry.dart';
import 'package:flowcraft/core/rendering/arrow_head.dart';
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

    test('is computed once per instance', () {
      // Read per element per frame by culling, and again per pointer event
      // by hit-testing; measuring through the global string-keyed cache on
      // every read fell off a cliff once a board held more distinct strings
      // than that cache could. The same Rect object coming back is the
      // proof that nothing is re-measured.
      final t = SketchText.create(
        position: Offset.zero,
        text: 'Measured exactly once',
        fontSize: 16,
      );
      expect(identical(t.bounds, t.bounds), isTrue);
      expect(identical(t.unrotatedBounds, t.bounds), isTrue,
          reason: 'unrotated: the very instance, not a copy');
      // A new instance is a new measurement — that is what makes the cache
      // safe: nothing an element is measured from can change under it.
      final retyped = t.copyWith(text: 'Different');
      expect(identical(retyped.bounds, t.bounds), isFalse);
      expect(retyped.bounds.width, isNot(t.bounds.width));
    });

    test('copyWith(fontFamily: null) clears it', () {
      // Every other nullable field used the sentinel; this one used `??`,
      // so a family once set could never go back to the platform default.
      final mono = SketchText.create(
        position: Offset.zero,
        text: 'Hello',
        fontFamily: 'JetBrains Mono',
      );
      expect(mono.copyWith(fontFamily: null).fontFamily, isNull);
      expect(mono.copyWith().fontFamily, 'JetBrains Mono');
      expect(mono.copyWith(text: 'x').fontFamily, 'JetBrains Mono');
      expect(mono.copyWith(fontFamily: 'Inter').fontFamily, 'Inter');
    });
  });

  group('SketchSticky.labelSize', () {
    test('is measured once per instance', () {
      final note = SketchSticky.create(
        rect: const Rect.fromLTWH(0, 0, 180, 72),
        text: 'a label to lay out',
      );
      expect(identical(note.labelSize, note.labelSize), isTrue);
      expect(note.labelSize.width, greaterThan(0));
      // Zero for a note with no text, without touching the cache.
      expect(
        SketchSticky.create(rect: const Rect.fromLTWH(0, 0, 180, 72))
            .labelSize,
        Size.zero,
      );
    });
  });

  group('SketchArrow.bounds', () {
    test('contain the head', () {
      // An axis-aligned arrow's segment box is zero pixels tall, but the
      // head's wings stick out sideways by headLength·sin(0.5) — ~5.75px at
      // the default size, ~23px at the UI's thickest stroke. The selection
      // box never enclosed them and export padding only just did.
      final arrow = SketchArrow.create(
        start: const Offset(0, 100),
        end: const Offset(200, 100),
        style: const SketchStyle(strokeWidth: 8),
      );
      final size = arrow.headLength;
      expect(size, 48.0, reason: 'max(arrowSize 10, 8 × 6)');
      final wing = size * math.sin(0.5);

      expect(arrow.bounds.left, 0);
      expect(arrow.bounds.right, 200);
      expect(arrow.bounds.top, closeTo(100 - wing, 1e-9));
      expect(arrow.bounds.bottom, closeTo(100 + wing, 1e-9));
    });

    test('match the painted head path', () {
      // The formula is mirrored from ArrowHead.path; this is the check that
      // the mirror stays true.
      final arrow = SketchArrow.create(
        start: const Offset(10, 20),
        end: const Offset(-60, 130),
        arrowSize: 30,
      );
      final head =
          ArrowHead.path(arrow.start, arrow.end, arrow.headLength).getBounds();
      final segment = Rect.fromPoints(arrow.start, arrow.end);
      final expected = segment.expandToInclude(head);
      expect(arrow.bounds.left, closeTo(expected.left, 1e-6));
      expect(arrow.bounds.top, closeTo(expected.top, 1e-6));
      expect(arrow.bounds.right, closeTo(expected.right, 1e-6));
      expect(arrow.bounds.bottom, closeTo(expected.bottom, 1e-6));
    });

    test('a zero-length arrow is just its point', () {
      final dot = SketchArrow.create(
        start: const Offset(5, 5),
        end: const Offset(5, 5),
      );
      expect(dot.bounds, const Rect.fromLTWH(5, 5, 0, 0));
    });
  });

  group('SketchElement.bounds under rotation', () {
    test('is the box of the rotated shape, sharing its centre', () {
      // A 200×50 box a quarter-turn on is a 50×200 box about the same
      // centre. This is what culling, marquee and the selection box see, so
      // it has to be what the painter draws — and the painter rotates about
      // `bounds.center`, which is why the centre must not move.
      const rect = Rect.fromLTWH(0, 0, 200, 50);
      final box = SketchRectangle(
        id: 'r',
        style: const SketchStyle(),
        rect: rect,
        angle: math.pi / 2,
      );
      expect(box.unrotatedBounds, rect);
      expect(box.bounds.center.dx, closeTo(rect.center.dx, 1e-9));
      expect(box.bounds.center.dy, closeTo(rect.center.dy, 1e-9));
      expect(box.bounds.width, closeTo(50, 1e-9));
      expect(box.bounds.height, closeTo(200, 1e-9));
    });

    test('is the unrotated box, same instance, at angle zero', () {
      final box = SketchRectangle.create(rect: const Rect.fromLTWH(0, 0, 9, 9));
      expect(identical(box.bounds, box.unrotatedBounds), isTrue);
    });

    test('grows a square by √2 at 45°', () {
      final box = SketchDiamond(
        id: 'd',
        style: const SketchStyle(),
        rect: const Rect.fromLTWH(0, 0, 100, 100),
        angle: math.pi / 4,
      );
      expect(box.bounds.width, closeTo(100 * math.sqrt2, 1e-9));
      expect(box.bounds.height, closeTo(100 * math.sqrt2, 1e-9));
    });

    test('round-trips the angle through JSON', () {
      final box = SketchEllipse(
        id: 'e',
        style: const SketchStyle(),
        rect: const Rect.fromLTWH(0, 0, 100, 40),
        angle: 0.3,
      );
      expect(SketchElement.fromJson(box.toJson()).angle, 0.3);
    });
  });

  group('SketchElement.fromJson geometry validation', () {
    // `jsonDecode('1e999')` is `double.infinity`. An element with an infinite
    // edge is invisible, unhittable — and unserialisable, so every autosave
    // after it loads throws and the whole project silently stops saving.
    // Refusing it here is what lets the tolerant loader drop and report the
    // one element instead.
    final huge = jsonDecode('1e999') as double;

    test('a rect coordinate of 1e999 throws FormatException', () {
      expect(huge.isInfinite, isTrue);
      final json = _plain(SketchRectangle.create(
        id: 'r',
        rect: const Rect.fromLTWH(0, 0, 10, 10),
      ));
      (json['rect'] as Map<String, dynamic>)['l'] = huge;
      expect(() => SketchElement.fromJson(json), throwsFormatException);
    });

    test('a negative-infinite width throws FormatException', () {
      final json = _plain(SketchEllipse.create(
        id: 'e',
        rect: const Rect.fromLTWH(0, 0, 10, 10),
      ));
      (json['rect'] as Map<String, dynamic>)['w'] = -huge;
      expect(() => SketchElement.fromJson(json), throwsFormatException);
    });

    test('an infinite line endpoint throws FormatException', () {
      final json = _plain(SketchLine.create(
        id: 'l',
        start: Offset.zero,
        end: const Offset(10, 10),
      ));
      (json['end'] as Map<String, dynamic>)['dy'] = huge;
      expect(() => SketchElement.fromJson(json), throwsFormatException);
    });

    test('a NaN text position throws FormatException', () {
      final json = _plain(SketchText.create(
        id: 't',
        position: Offset.zero,
        text: 'hi',
      ));
      (json['position'] as Map<String, dynamic>)['dx'] = double.nan;
      expect(() => SketchElement.fromJson(json), throwsFormatException);
    });

    test('one bad freedraw point throws FormatException for the stroke', () {
      final json = _plain(SketchFreedraw.create(
        id: 'f',
        points: const [Offset(0, 0), Offset(5, 5), Offset(10, 0)],
      ));
      ((json['points'] as List)[1] as Map<String, dynamic>)['dx'] = huge;
      expect(() => SketchElement.fromJson(json), throwsFormatException);
    });

    test('an empty freedraw throws FormatException, not an assertion', () {
      final json = _plain(SketchFreedraw.create(
        id: 'f',
        points: const [Offset(0, 0), Offset(5, 5)],
      ));
      json['points'] = <dynamic>[];
      expect(() => SketchElement.fromJson(json), throwsFormatException);
    });

    test('a non-numeric coordinate throws FormatException', () {
      final json = _plain(SketchRectangle.create(
        id: 'r',
        rect: const Rect.fromLTWH(0, 0, 10, 10),
      ));
      (json['rect'] as Map<String, dynamic>)['t'] = 'ten';
      expect(() => SketchElement.fromJson(json), throwsFormatException);
    });

    test('finite geometry still loads exactly', () {
      for (final el in _oneOfEachSubtype()) {
        final restored = SketchElement.fromJson(el.toJson());
        expect(restored.bounds, el.bounds, reason: '${el.runtimeType}');
      }
    });
  });

  group('SketchElement.fromJson style-number clamping', () {
    // Style numbers are clamped rather than refused: a font size of 1e6 is
    // a file worth rescuing, a coordinate of 1e999 is not.
    Map<String, dynamic> rectJson() => _plain(SketchRectangle.create(
          id: 'r',
          rect: const Rect.fromLTWH(0, 0, 10, 10),
          text: 'label',
        ));

    test('fontSize is clamped to 1..512 on every text-bearing element', () {
      final json = rectJson()..['fontSize'] = 1e6;
      expect((SketchElement.fromJson(json) as SketchRectangle).fontSize, 512);

      final tiny = rectJson()..['fontSize'] = -4;
      expect((SketchElement.fromJson(tiny) as SketchRectangle).fontSize, 1);

      final sticky = _plain(SketchSticky.create(
        id: 's',
        rect: const Rect.fromLTWH(0, 0, 180, 72),
        text: 'note',
      ))..['fontSize'] = 0;
      expect((SketchElement.fromJson(sticky) as SketchSticky).fontSize, 1);

      final text = _plain(SketchText.create(
        id: 't',
        position: Offset.zero,
        text: 'hi',
      ))..['fontSize'] = 9999;
      expect((SketchElement.fromJson(text) as SketchText).fontSize, 512);
    });

    test('a non-finite fontSize takes the default', () {
      final json = rectJson()..['fontSize'] = double.nan;
      expect((SketchElement.fromJson(json) as SketchRectangle).fontSize, 16);
    });

    test('arrowSize is clamped to a sane range', () {
      Map<String, dynamic> arrowJson(Object? size) => _plain(SketchArrow.create(
            id: 'a',
            start: Offset.zero,
            end: const Offset(10, 10),
          ))..['arrowSize'] = size;
      expect(
          (SketchElement.fromJson(arrowJson(-5)) as SketchArrow).arrowSize, 0);
      expect(
        (SketchElement.fromJson(arrowJson(1e9)) as SketchArrow).arrowSize,
        512,
      );
      expect(
        (SketchElement.fromJson(arrowJson(double.infinity)) as SketchArrow)
            .arrowSize,
        10,
      );
    });

    test('a negative cornerRadius is floored at zero', () {
      final json = rectJson()..['cornerRadius'] = -12;
      expect(
        (SketchElement.fromJson(json) as SketchRectangle).cornerRadius,
        0,
      );
    });

    test('a NaN angle takes zero rather than poisoning bounds', () {
      final json = rectJson()..['angle'] = double.nan;
      final restored = SketchElement.fromJson(json);
      expect(restored.angle, 0);
      expect(restored.bounds.isFinite, isTrue);
    });

    test('a wrongly typed style number is still an error', () {
      final json = rectJson()..['fontSize'] = 'big';
      expect(() => SketchElement.fromJson(json), throwsFormatException);
    });
  });

  group('SketchStyle.seed on creation', () {
    test('create gives each element a seed of its own', () {
      // Every element used to ship with seed 1, so two same-sized shapes
      // wobbled identically. A file's seeds are never touched — see below.
      final seeds = <int>{
        for (var i = 0; i < 8; i++)
          SketchRectangle.create(rect: const Rect.fromLTWH(0, 0, 9, 9))
              .style
              .seed,
      };
      expect(seeds.length, greaterThan(1));
      expect(seeds.contains(SketchStyle.defaultSeed), isFalse);
    });

    test('applies to every subtype', () {
      for (final el in _oneOfEachSubtype()) {
        expect(el.style.seed, isNot(SketchStyle.defaultSeed),
            reason: '${el.runtimeType}');
        expect(el.style.seed, inInclusiveRange(1, 0x7FFFFFFE),
            reason: '${el.runtimeType}: inside the Park–Miller range');
      }
    });

    test('an explicit seed is kept', () {
      final el = SketchEllipse.create(
        rect: const Rect.fromLTWH(0, 0, 9, 9),
        style: const SketchStyle(seed: 42),
      );
      expect(el.style.seed, 42);
    });

    test('only the seed changes; the rest of the style is the caller\'s', () {
      const style = SketchStyle(strokeWidth: 5, roughness: 0.2);
      final el = SketchLine.create(
        start: Offset.zero,
        end: const Offset(1, 1),
        style: style,
      );
      expect(el.style.copyWith(seed: style.seed), style);
    });

    test('fromJson keeps the file\'s seed, so a scene renders as saved', () {
      final json = _plain(SketchRectangle.create(
        id: 'r',
        rect: const Rect.fromLTWH(0, 0, 9, 9),
      ));
      (json['style'] as Map<String, dynamic>)['seed'] = 1;
      expect(SketchElement.fromJson(json).style.seed, 1);
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
    SketchSticky painted(Color stroke, Color? fill) => SketchSticky.create(
          rect: const Rect.fromLTWH(0, 0, 10, 10),
          style: SketchStyle(
            strokeColor: stroke,
            fillColor: fill,
            fillStyle: fill == null ? FillStyle.none : FillStyle.solid,
          ),
        );

    test('is dark on the default paper, not the outline colour', () {
      // The stroke is the bubble's *edge* — a darker shade of the paper —
      // and glyphs in it would be muddy amber on amber.
      final note = SketchSticky.create(rect: const Rect.fromLTWH(0, 0, 10, 10));
      expect(note.inkColor, isNot(note.style.strokeColor));
      expect(note.inkColor, isNot(note.style.fillColor));
      expect(note.inkColor.computeLuminance(), lessThan(0.1));
    });

    test('stays legible on a note saved before the outline existed', () {
      // Those files have stroke == fill == pale yellow; glyphs drawn in the
      // stroke colour were invisible.
      const paper = Color(0xFFFFEC99);
      final ink = painted(paper, paper).inkColor;
      expect(ink, isNot(paper));
      expect(ink.computeLuminance(), lessThan(paper.computeLuminance()));
    });

    test('flips for a dark paper, whatever the outline is', () {
      const dark = Color(0xFF20242C);
      expect(
        painted(const Color(0xFFAA0000), dark).inkColor.computeLuminance(),
        greaterThan(dark.computeLuminance()),
      );
    });

    test('follows the fill the user picks from the palette', () {
      // Repainting the paper must not leave yesterday's ink on it.
      final note = SketchSticky.create(rect: const Rect.fromLTWH(0, 0, 10, 10));
      final repainted = note.copyWithStyle(
        note.style.withFillColor(const Color(0xFF1B2A4A)),
      );
      expect(repainted.inkColor.computeLuminance(), greaterThan(0.5));
    });

    test('an unfilled note takes its outline colour, like any shape label',
        () {
      const ink = Color(0xFFAA0000);
      expect(painted(ink, null).inkColor, ink);
    });
  });

  group('SketchSticky.fittedToText', () {
    const rect = Rect.fromLTWH(0, 0, 180, 72);
    const paragraph =
        'A note long enough that it has to wrap onto several lines, which '
        'the default height was never meant to hold.';

    test('grows a note whose text overflows, to exactly what it needs', () {
      final note = SketchSticky.create(rect: rect, text: paragraph);
      final grown = note.fittedToText();
      expect(grown.rect.height, greaterThan(rect.height));
      expect(grown.rect.width, rect.width, reason: 'width is left alone');
      expect(grown.rect.topLeft, rect.topLeft, reason: 'origin is kept');
      // The text box of the grown note holds the laid-out text exactly —
      // the bubble takes the height of its message.
      expect(
        StickyBubbleGeometry.textBoxOf(grown.rect).height,
        closeTo(grown.labelSize.height, 0.01),
      );
    });

    test('leaves a note whose text already fits exactly as it is', () {
      final note = SketchSticky.create(rect: rect, text: 'short');
      expect(identical(note.fittedToText(), note), isTrue);
    });

    test('never shrinks a note the user made tall', () {
      const tall = Rect.fromLTWH(0, 0, 180, 400);
      final note = SketchSticky.create(rect: tall, text: 'short');
      expect(note.fittedToText().rect, tall);
    });

    test('is a no-op on a collapsed note or one with no text', () {
      expect(
        SketchSticky.create(rect: rect, text: paragraph, collapsed: true)
            .fittedToText()
            .rect,
        rect,
      );
      expect(SketchSticky.create(rect: rect).fittedToText().rect, rect);
    });

    test('refuses to grow a sliver into a tower', () {
      // One glyph per line into a 10px-wide note would be hundreds of px
      // tall; clipping is the lesser evil there.
      const sliver = Rect.fromLTWH(0, 0, 10, 10);
      final note = SketchSticky.create(rect: sliver, text: paragraph);
      expect(note.fittedToText().rect, sliver);
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

/// [el]'s JSON as a file would hand it back: plain `Map<String, dynamic>`
/// all the way down, so a test can poke hostile values into any slot.
Map<String, dynamic> _plain(SketchElement el) =>
    jsonDecode(jsonEncode(el.toJson())) as Map<String, dynamic>;

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
