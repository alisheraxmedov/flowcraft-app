import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/painting.dart' show TextPainter, TextSpan;
import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/core/domain/sticky_bubble_geometry.dart';
import 'package:flowcraft/core/rendering/rough_generator.dart';
import 'package:flowcraft/core/rendering/sketch_render_cache.dart';
import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/models/sketch_style.dart';

/// The cache is what actually turns an element into the paths the painter
/// draws, so it is where "what is drawn" can be measured against "what
/// `bounds` claims". A disagreement between those two is the bug class this
/// repo has already paid for once, in `SketchText.bounds`.
const Rect _rect = Rect.fromLTWH(60, 20, 220, 110);

/// Full roughness on purpose: a sticky is the one closed shape that is
/// drawn clean whatever its style says, and these tests would pass by
/// accident at roughness 0.
SketchSticky _sticky({bool collapsed = false}) => SketchSticky.create(
  id: 'note',
  rect: _rect,
  text: 'remember this',
  style: SketchSticky.defaultStyle.copyWith(roughness: 2.0),
  collapsed: collapsed,
);

/// Bounds of the points a path actually passes through.
///
/// Not [Path.getBounds]: that reports the hull of the cubics' *control*
/// points, and `RoughGenerator` deliberately throws control points past the
/// segment's end (it is what produces the overshooting hand-drawn stroke).
/// Measuring those would claim the note paints 18px above itself when the
/// ink never leaves the box.
Rect _inkedBounds(Path path) {
  final points = <Offset>[];
  for (final metric in path.computeMetrics()) {
    const samples = 64;
    for (var i = 0; i <= samples; i++) {
      final tangent = metric.getTangentForOffset(metric.length * i / samples);
      if (tangent != null) points.add(tangent.position);
    }
  }
  expect(points, isNotEmpty, reason: 'nothing was drawn');
  return points
      .skip(1)
      .fold(
        Rect.fromPoints(points.first, points.first),
        (box, p) => box.expandToInclude(Rect.fromPoints(p, p)),
      );
}

void _expectWithin(Rect drawn, Rect allowed, {double slack = 0.0}) {
  final box = allowed.inflate(slack);
  expect(
    drawn.left,
    greaterThanOrEqualTo(box.left),
    reason: '$drawn escapes $box on the left',
  );
  expect(
    drawn.top,
    greaterThanOrEqualTo(box.top),
    reason: '$drawn escapes $box on the top',
  );
  expect(
    drawn.right,
    lessThanOrEqualTo(box.right),
    reason: '$drawn escapes $box on the right',
  );
  expect(
    drawn.bottom,
    lessThanOrEqualTo(box.bottom),
    reason: '$drawn escapes $box on the bottom',
  );
}

Future<Uint8List> _png([int size = 4]) async {
  final recorder = PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, size.toDouble(), size.toDouble()),
    Paint()..color = const Color(0xFFFF0000),
  );
  final src = await recorder.endRecording().toImage(size, size);
  final data = (await src.toByteData(format: ImageByteFormat.png))!;
  src.dispose();
  return data.buffer.asUint8List();
}

/// Waits for the next decode notification.
Future<void> _decoded(SketchRenderCache cache) {
  final c = Completer<void>();
  cache.addListener(() {
    if (!c.isCompleted) c.complete();
  });
  return c.future;
}

/// Inserts enough stale entries that the next [SketchRenderCache.sweep]
/// actually walks the maps.
void _pad(SketchRenderCache cache) {
  final pad = SketchText.create(position: Offset.zero, text: 'x');
  for (var i = 0; i <= SketchRenderCache.sweepSlack; i++) {
    cache.textPainter(
      pad.copyWith(text: '$i'),
      () => TextPainter(
        text: const TextSpan(text: 'x'),
        textDirection: TextDirection.ltr,
      )..layout(),
    );
  }
}

void main() {
  group('a sticky note paints inside the box it claims', () {
    test('expanded: the bubble fills its rect and nothing more', () {
      final cache = SketchRenderCache();
      final note = _sticky();
      expect(note.bounds, _rect);

      _expectWithin(cache.fillPath(note).getBounds(), note.bounds, slack: 0.01);
      _expectWithin(
        _inkedBounds(cache.strokePath(note)),
        note.bounds,
        slack: 0.01,
      );
    });

    test('the outline is the exact edge of the fill, at any roughness', () {
      // Rendered rough, the outline had square corners over a rounded fill
      // and poked past it at every corner — the "badly made" the user saw.
      final cache = SketchRenderCache();
      final note = _sticky();
      final fill = _inkedBounds(cache.fillPath(note));
      final stroke = _inkedBounds(cache.strokePath(note));
      expect(stroke.left, closeTo(fill.left, 0.01));
      expect(stroke.top, closeTo(fill.top, 0.01));
      expect(stroke.right, closeTo(fill.right, 0.01));
      expect(stroke.bottom, closeTo(fill.bottom, 0.01));
    });

    test('collapsed: the badge fills its bounds and nothing more', () {
      final cache = SketchRenderCache();
      final note = _sticky(collapsed: true);
      expect(note.bounds, StickyBubbleGeometry.collapsedBounds(_rect));

      final fill = cache.fillPath(note).getBounds();
      _expectWithin(fill, note.bounds, slack: 0.01);
      // The bubble hiding behind the badge must not be painted: if it were,
      // the drawn box would reach the expanded rect's right edge while
      // `bounds` stopped 36px in, which is exactly the desync to avoid.
      expect(fill.right, lessThan(_rect.right - 100));

      _expectWithin(
        _inkedBounds(cache.strokePath(note)),
        note.bounds,
        slack: 0.01,
      );
    });
  });

  group('cached paths track the collapsed flag', () {
    test('toggling collapse does not re-serve the previous silhouette', () {
      // Both states share an id, a seed and a rect, so a key that ignored
      // `collapsed` would hand the badge the bubble's path.
      final cache = SketchRenderCache();
      final expanded = cache.fillPath(_sticky()).getBounds();
      final collapsed = cache.fillPath(_sticky(collapsed: true)).getBounds();
      expect(collapsed, isNot(expanded));
      expect(
        collapsed.width,
        closeTo(StickyBubbleGeometry.collapsedSize, 0.01),
      );

      final expandedStroke = cache.strokePath(_sticky()).getBounds();
      final collapsedStroke = cache
          .strokePath(_sticky(collapsed: true))
          .getBounds();
      expect(collapsedStroke, isNot(expandedStroke));
    });

    test('the same note still hits the cache', () {
      final cache = SketchRenderCache();
      final note = _sticky();
      expect(identical(cache.fillPath(note), cache.fillPath(note)), isTrue);
      expect(identical(cache.strokePath(note), cache.strokePath(note)), isTrue);
    });
  });

  group('entries are keyed by element identity', () {
    final box = SketchRectangle.create(
      id: 'box',
      rect: const Rect.fromLTWH(0, 0, 100, 50),
      text: 'label',
    );

    test(
      'a translated element gets its own entry; the sweep drops the old',
      () {
        final cache = SketchRenderCache();
        final before = cache.strokePath(box);
        final moved = box.translate(const Offset(10, 10));
        final after = cache.strokePath(moved);
        expect(identical(before, after), isFalse);
        expect(after.getBounds().left, greaterThan(before.getBounds().left));

        // Both are live until the scene no longer holds the original. The
        // sweep is lazy up to `sweepSlack` stale entries, so it is exercised
        // here by pushing past that slack.
        final stale = List.generate(
          SketchRenderCache.sweepSlack + 1,
          (i) => box.translate(Offset(i.toDouble(), 0)),
        );
        for (final e in stale) {
          cache.strokePath(e);
        }
        cache.sweep([moved], generation: 1);
        expect(cache.strokeEntryCount, 1);
        expect(
          identical(cache.strokePath(moved), after),
          isTrue,
          reason: 'the live element must keep its entry across a sweep',
        );
      },
    );

    test('a restyled element gets a fresh dashed outline', () {
      final cache = SketchRenderCache();
      final solid = cache.strokePath(box);
      final dashed = cache.strokePath(
        box.copyWithStyle(box.style.copyWith(strokeStyle: StrokeStyle.dashed)),
      );
      expect(identical(solid, dashed), isFalse);
      expect(
        dashed.computeMetrics().length,
        greaterThan(solid.computeMetrics().length),
        reason: 'a dashed outline is many short sub-paths',
      );
    });

    test('the sweep only walks the maps when the generation changes', () {
      final cache = SketchRenderCache();
      for (var i = 0; i <= SketchRenderCache.sweepSlack; i++) {
        cache.strokePath(box.translate(Offset(i.toDouble(), 0)));
      }
      cache.sweep(const [], generation: 7);
      expect(cache.strokeEntryCount, 0);

      // Same generation again: nothing to do, and nothing is lost.
      cache.strokePath(box);
      cache.sweep(const [], generation: 7);
      expect(cache.strokeEntryCount, 1);
    });
  });

  group('text painters', () {
    final label = SketchText.create(
      id: 'txt',
      position: Offset.zero,
      text: 'hello',
    );

    test('the same instance returns the same painter', () {
      final cache = SketchRenderCache();
      var builds = 0;
      TextPainter build() {
        builds++;
        return TextPainter(
          text: const TextSpan(text: 'hello'),
          textDirection: TextDirection.ltr,
        )..layout();
      }

      final a = cache.textPainter(label, build);
      final b = cache.textPainter(label, build);
      expect(identical(a, b), isTrue);
      expect(builds, 1);
      cache.dispose();
    });

    test('a copyWith instance lays out afresh and the stale one is swept', () {
      final cache = SketchRenderCache();
      TextPainter build() => TextPainter(
        text: const TextSpan(text: 'hello'),
        textDirection: TextDirection.ltr,
      )..layout();
      final a = cache.textPainter(label, build);
      final edited = label.copyWith(text: 'hello!');
      final b = cache.textPainter(edited, build);
      expect(identical(a, b), isFalse);
      expect(cache.textEntryCount, 2);

      for (var i = 0; i < SketchRenderCache.sweepSlack; i++) {
        cache.textPainter(label.copyWith(text: '$i'), build);
      }
      cache.sweep([edited], generation: 1);
      expect(cache.textEntryCount, 1);
      expect(identical(cache.textPainter(edited, build), b), isTrue);
      cache.dispose();
    });
  });

  group('dashed strokes are built once', () {
    test('a dotted rectangle is one path of short dashes', () {
      final cache = SketchRenderCache();
      final dotted = SketchRectangle.create(
        id: 'dots',
        rect: const Rect.fromLTWH(0, 0, 100, 100),
        style: const SketchStyle(strokeStyle: StrokeStyle.dotted),
      );
      final path = cache.strokePath(dotted);
      final metrics = path.computeMetrics().toList();
      // Perimeter 400 × 2 passes on a (2 on, 4 off) pattern ≈ 133 dots.
      expect(metrics.length, greaterThan(100));
      for (final m in metrics) {
        // Dashes are cut along the rough outline's cubics, where the
        // metric's arc length is an approximation — allow a little slack.
        expect(m.length, lessThanOrEqualTo(2.5));
      }
      expect(identical(cache.strokePath(dotted), path), isTrue);
    });

    test('a collapsed note keeps its badge mark solid whatever the style', () {
      final cache = SketchRenderCache();
      final note = SketchSticky.create(
        id: 'n',
        rect: _rect,
        style: SketchSticky.defaultStyle.copyWith(
          strokeStyle: StrokeStyle.dotted,
        ),
        collapsed: true,
      );
      final glyph = StickyBubbleGeometry.glyphPath(note.rect);
      expect(
        cache.strokePath(note).computeMetrics().length,
        glyph.computeMetrics().length,
      );
    });
  });

  group('hatch fills', () {
    test('the outline path is the solid silhouette for every closed shape', () {
      final cache = SketchRenderCache();
      const rect = Rect.fromLTWH(10, 10, 100, 60);
      final ellipse = SketchEllipse.create(id: 'e', rect: rect);
      final diamond = SketchDiamond.create(id: 'd', rect: rect);
      final triangle = SketchTriangle.create(id: 't', rect: rect);
      for (final shape in [ellipse, diamond, triangle]) {
        expect(cache.outlinePath(shape).getBounds(), rect);
        expect(SketchRenderCache.hatchNeedsClip(shape), isTrue);
      }
      expect(
        SketchRenderCache.hatchNeedsClip(
          SketchRectangle.create(id: 'r', rect: rect),
        ),
        isFalse,
      );
      expect(
        cache
            .outlinePath(
              SketchLine.create(
                id: 'l',
                start: Offset.zero,
                end: const Offset(10, 10),
              ),
            )
            .getBounds(),
        Rect.zero,
      );
    });

    test('a shape too large to hatch falls back to a solid fill', () {
      final cache = SketchRenderCache();
      final huge = SketchEllipse.create(
        id: 'huge',
        rect: const Rect.fromLTWH(0, 0, 100000, 100000),
        style: const SketchStyle(
          fillStyle: FillStyle.hachure,
          fillColor: Color(0xFF000000),
        ),
      );
      expect(RoughGenerator.hachureFits(huge.bounds), isFalse);
      expect(SketchRenderCache.hatchFallsBackToSolid(huge), isTrue);
      expect(cache.fillPath(huge).getBounds(), huge.bounds);
      expect(
        cache.fillPath(huge).computeMetrics().length,
        1,
        reason: 'one closed oval, not thousands of hatch lines',
      );
    });
  });

  group('phase 2 element types', () {
    testWidgets('image decoded once, disposed on sweep', (tester) async {
      await tester.runAsync(() async {
        final recorder = PictureRecorder();
        Canvas(recorder).drawRect(
          const Rect.fromLTWH(0, 0, 4, 4),
          Paint()..color = const Color(0xFFFF0000),
        );
        final src = await recorder.endRecording().toImage(4, 4);
        final png = (await src.toByteData(format: ImageByteFormat.png))!;
        final image = SketchImage.create(
          rect: const Rect.fromLTWH(0, 0, 40, 40),
          mimeType: 'image/png',
          bytes: png.buffer.asUint8List(),
        );

        final cache = SketchRenderCache();
        final ready = Completer<void>();
        cache.addListener(() {
          if (!ready.isCompleted) ready.complete();
        });
        expect(cache.imageFor(image), isNull, reason: 'still decoding');
        expect(cache.imageFor(image), isNull);
        await ready.future;
        final decoded = cache.imageFor(image)!;
        expect(identical(cache.imageFor(image), decoded), isTrue);
        expect(cache.imageDecodeCount, 1);

        // Sweeping is lazy up to `sweepSlack` stale inserts.
        final pad = SketchText.create(position: Offset.zero, text: 'x');
        for (var i = 0; i < SketchRenderCache.sweepSlack; i++) {
          cache.textPainter(
            pad.copyWith(text: '$i'),
            () => TextPainter(
              text: const TextSpan(text: 'x'),
              textDirection: TextDirection.ltr,
            )..layout(),
          );
        }
        cache.sweep(const [], generation: 1);
        expect(decoded.debugDisposed, isTrue);
        cache.dispose();
      });
    });

    test('icon painter cached', () {
      final cache = SketchRenderCache();
      final icon = SketchIcon.create(
        rect: const Rect.fromLTWH(0, 0, 64, 48),
        name: 'database',
      );
      final a = cache.iconPainter(icon);
      expect(identical(cache.iconPainter(icon), a), isTrue);
      expect(cache.textEntryCount, 1);
      // Sized to the shorter side.
      expect(a.text!.style!.fontSize, 48);
      cache.dispose();
    });

    test('elbow stroke path has bends', () {
      const style = SketchStyle(roughness: 0.0);
      final cache = SketchRenderCache();
      final elbow = SketchArrow.create(
        start: Offset.zero,
        end: const Offset(100, 60),
        style: style,
        elbowed: true,
      );
      final straight = elbow.copyWith(elbowed: false);
      double length(Path p) =>
          p.computeMetrics().fold(0.0, (a, m) => a + m.length);
      // H-V-H: 50 + 60 + 50 along the axes, against the 116.6 diagonal
      // (the straight rough line is double-stroked, so compare per pass).
      expect(length(cache.strokePath(elbow)), closeTo(160, 0.5));
      expect(length(cache.strokePath(straight)), isNot(closeTo(160, 5)));
      cache.dispose();
    });

    test('entity labels are laid out once per instance', () {
      final cache = SketchRenderCache();
      final e = SketchEntity.create(
        rect: const Rect.fromLTWH(0, 0, 200, 0),
        name: 'user',
        attributes: const [
          EntityAttribute(name: 'id', type: 'int', primaryKey: true),
          EntityAttribute(name: 'name'),
        ],
      );
      final labels = cache.entityLabels(e);
      expect(identical(cache.entityLabels(e), labels), isTrue);
      expect(labels.rows, hasLength(2));
      expect(labels.rows[0].tag, isNotNull);
      expect(labels.rows[1].type, isNull);
      cache.dispose();
    });
  });

  group('decoded images are keyed by their bytes', () {
    testWidgets('moving an image reuses the decode (decode count stays 1 '
        'across translate/copyWith)', (tester) async {
      await tester.runAsync(() async {
        final image = SketchImage.create(
          rect: const Rect.fromLTWH(0, 0, 40, 40),
          mimeType: 'image/png',
          bytes: await _png(),
        );
        final cache = SketchRenderCache();
        final ready = _decoded(cache);
        expect(cache.imageFor(image), isNull);
        await ready;
        final decoded = cache.imageFor(image)!;

        final moved = image.translate(const Offset(5, 5));
        final resized = image.copyWith(rect: const Rect.fromLTWH(0, 0, 9, 9));
        expect(identical(moved, image), isFalse);
        expect(identical(cache.imageFor(moved), decoded), isTrue);
        expect(identical(cache.imageFor(resized), decoded), isTrue);
        expect(cache.imageDecodeCount, 1);
        cache.dispose();
      });
    });

    testWidgets('image bitmap disposed only when no live element shares its '
        'bytes', (tester) async {
      await tester.runAsync(() async {
        final image = SketchImage.create(
          rect: const Rect.fromLTWH(0, 0, 40, 40),
          mimeType: 'image/png',
          bytes: await _png(),
        );
        final cache = SketchRenderCache();
        final ready = _decoded(cache);
        cache.imageFor(image);
        await ready;
        final decoded = cache.imageFor(image)!;
        final moved = image.translate(const Offset(5, 5));

        _pad(cache);
        cache.sweep([moved], generation: 1); // Original gone, copy alive.
        expect(decoded.debugDisposed, isFalse);

        _pad(cache);
        cache.sweep(const [], generation: 2);
        expect(decoded.debugDisposed, isTrue);
        cache.dispose();
      });
    });

    testWidgets('oversized image stays a placeholder without decoding', (
      tester,
    ) async {
      await tester.runAsync(() async {
        // Real 1x1 PNG with IHDR patched to 60000x60000 (CRC redone).
        final png = Uint8List.fromList(await _png(1));
        final bd = ByteData.sublistView(png);
        bd.setUint32(16, 60000);
        bd.setUint32(20, 60000);
        var crc = 0xFFFFFFFF;
        for (var i = 12; i < 29; i++) {
          crc ^= png[i];
          for (var k = 0; k < 8; k++) {
            crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xEDB88320 : crc >> 1;
          }
        }
        bd.setUint32(29, crc ^ 0xFFFFFFFF);

        final image = SketchImage.create(
          rect: const Rect.fromLTWH(0, 0, 40, 40),
          mimeType: 'image/png',
          bytes: png,
        );
        final cache = SketchRenderCache();
        var notified = false;
        cache.addListener(() => notified = true);
        expect(cache.imageFor(image), isNull);
        await Future<void>.delayed(const Duration(milliseconds: 200));
        expect(cache.imageFor(image), isNull);
        expect(notified, isFalse);
        expect(cache.imageDecodeCount, 1, reason: 'no retry per paint');
        cache.dispose();
      });
    });
  });
}
