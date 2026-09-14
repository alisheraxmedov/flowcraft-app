import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/core/rendering/sketch_painter.dart';
import 'package:flowcraft/core/rendering/sketch_render_cache.dart';
import 'package:flowcraft/models/flow_viewport.dart';
import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/models/sketch_style.dart';

const Color _hatchRed = Color(0xFFFF0000);
const Color _strokeBlue = Color(0xFF0000FF);

/// Hatch fill in pure red, outline in pure blue at roughness 0, so a red
/// pixel can only ever have come from the hatch.
const SketchStyle _hatched = SketchStyle(
  strokeColor: _strokeBlue,
  fillColor: _hatchRed,
  fillStyle: FillStyle.hachure,
  roughness: 0.0,
  strokeWidth: 2.0,
);

/// Paints [elements] at zoom 1 / no pan into a [size] picture and returns
/// the raw RGBA pixels — what actually lands on screen, clip included.
Future<ByteData> _rasterise(
  List<SketchElement> elements, {
  Size size = const Size(200, 200),
}) async {
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & size);
  canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFFFFFF));
  SketchPainter(
    elements: elements,
    selectedIds: const {},
    viewport: const FlowViewport(),
    paintGen: 0,
    cache: SketchRenderCache(),
    selectionColor: const Color(0xFF000000),
    canvasSize: size,
  ).paint(canvas, size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(size.width.toInt(), size.height.toInt());
  picture.dispose();
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return bytes!;
}

bool _isRed(ByteData px, int width, int x, int y) {
  final i = (y * width + x) * 4;
  // Red dominant: the hatch over white, or antialiased against it.
  return px.getUint8(i) > 200 &&
      px.getUint8(i + 1) < 128 &&
      px.getUint8(i + 2) < 128;
}

bool _isWhite(ByteData px, int width, int x, int y) {
  final i = (y * width + x) * 4;
  return px.getUint8(i) >= 250 &&
      px.getUint8(i + 1) >= 250 &&
      px.getUint8(i + 2) >= 250;
}

/// Any red tint at all — a hatch pixel at any antialiased coverage. The
/// blue outline (which legitimately bows a few px outside the shape) and
/// the white ground never read as red.
bool _hasRedTint(ByteData px, int width, int x, int y) {
  final i = (y * width + x) * 4;
  final r = px.getUint8(i);
  final g = px.getUint8(i + 1);
  final b = px.getUint8(i + 2);
  return r - (g > b ? g : b) > 40;
}

/// Asserts that, over a 2 px grid, no hatch pixel lies more than [margin]
/// outside [inside] and that at least some hatch was painted within it.
Future<void> _expectHatchStaysInside(
  SketchElement shape,
  bool Function(Offset p) inside, {
  double margin = 4.0,
}) async {
  const size = Size(200, 200);
  final px = await _rasterise([shape], size: size);
  var outsideHits = 0;
  var insideHits = 0;
  var outsideSamples = 0;
  for (var y = 0; y < 200; y += 2) {
    for (var x = 0; x < 200; x += 2) {
      final p = Offset(x.toDouble(), y.toDouble());
      if (inside(p)) {
        if (_isRed(px, 200, x, y)) insideHits++;
        continue;
      }
      // Only judge points clearly outside: the outline stroke and the
      // clip's antialiasing own the first few pixels past the edge.
      final clearlyOutside =
          !inside(p) &&
          !inside(p + Offset(margin, 0)) &&
          !inside(p - Offset(margin, 0)) &&
          !inside(p + Offset(0, margin)) &&
          !inside(p - Offset(0, margin)) &&
          !inside(p + Offset(margin, margin)) &&
          !inside(p - Offset(margin, margin)) &&
          !inside(p + Offset(margin, -margin)) &&
          !inside(p + Offset(-margin, margin));
      if (!clearlyOutside) continue;
      outsideSamples++;
      if (_hasRedTint(px, 200, x, y)) outsideHits++;
    }
  }
  expect(outsideSamples, greaterThan(100), reason: 'probe covers the corners');
  expect(insideHits, greaterThan(20), reason: 'the hatch was painted at all');
  expect(
    outsideHits,
    0,
    reason:
        '$outsideHits hatch pixels painted outside the ${shape.runtimeType}',
  );
}

void main() {
  // `Picture.toImage` needs a live engine binding.
  TestWidgetsFlutterBinding.ensureInitialized();

  group('labels', () {
    test('a 10px-wide labelled shape paints without throwing', () {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      final cache = SketchRenderCache();
      final shapes = <SketchElement>[
        SketchRectangle.create(
          id: 'r',
          rect: const Rect.fromLTWH(0, 0, 10, 40),
          text: 'Hi',
        ),
        SketchEllipse.create(
          id: 'e',
          rect: const Rect.fromLTWH(20, 0, 10, 40),
          text: 'Hi',
        ),
        SketchDiamond.create(
          id: 'd',
          rect: const Rect.fromLTWH(40, 0, 10, 40),
          text: 'Hi',
        ),
        SketchTriangle.create(
          id: 't',
          rect: const Rect.fromLTWH(60, 0, 10, 40),
          text: 'Hi',
        ),
        // Just above the inset: lays out at maxWidth 0, must not throw.
        SketchRectangle.create(
          id: 'r12',
          rect: const Rect.fromLTWH(80, 0, 12, 40),
          text: 'Hi',
        ),
      ];
      expect(
        () => SketchPainter(
          elements: shapes,
          selectedIds: const {},
          viewport: const FlowViewport(),
          paintGen: 0,
          cache: cache,
          selectionColor: const Color(0xFF000000),
          canvasSize: const Size(200, 200),
        ).paint(canvas, const Size(200, 200)),
        returnsNormally,
      );
      recorder.endRecording().dispose();
      cache.dispose();
    });

    test('a label is laid out once per element instance, not per frame', () {
      final cache = SketchRenderCache();
      final box = SketchRectangle.create(
        id: 'r',
        rect: const Rect.fromLTWH(0, 0, 120, 60),
        text: 'Once',
      );
      SketchPainter painter(int gen) => SketchPainter(
        elements: [box],
        selectedIds: const {},
        viewport: const FlowViewport(),
        paintGen: gen,
        cache: cache,
        selectionColor: const Color(0xFF000000),
        canvasSize: const Size(200, 200),
      );
      for (var frame = 0; frame < 3; frame++) {
        final recorder = ui.PictureRecorder();
        painter(frame).paint(Canvas(recorder), const Size(200, 200));
        recorder.endRecording().dispose();
      }
      expect(cache.textEntryCount, 1);
      cache.dispose();
    });
  });

  group('hachure stays inside the shape it fills', () {
    const rect = Rect.fromLTWH(20, 20, 160, 160);

    test('ellipse', () async {
      final shape = SketchEllipse.create(id: 'e', rect: rect, style: _hatched);
      await _expectHatchStaysInside(shape, (p) {
        final dx = (p.dx - rect.center.dx) / (rect.width / 2);
        final dy = (p.dy - rect.center.dy) / (rect.height / 2);
        return dx * dx + dy * dy <= 1.0;
      });
    });

    test('diamond', () async {
      final shape = SketchDiamond.create(id: 'd', rect: rect, style: _hatched);
      await _expectHatchStaysInside(shape, (p) {
        final dx = (p.dx - rect.center.dx).abs() / (rect.width / 2);
        final dy = (p.dy - rect.center.dy).abs() / (rect.height / 2);
        return dx + dy <= 1.0;
      });
    });

    test('triangle', () async {
      final shape = SketchTriangle.create(id: 't', rect: rect, style: _hatched);
      // Apex top-centre, base along the bottom edge.
      await _expectHatchStaysInside(shape, (p) {
        if (p.dy < rect.top || p.dy > rect.bottom) return false;
        final t = (p.dy - rect.top) / rect.height; // 0 at apex, 1 at base
        final halfWidth = t * rect.width / 2;
        return (p.dx - rect.center.dx).abs() <= halfWidth;
      });
    });

    test('cross-hatch on an ellipse', () async {
      final shape = SketchEllipse.create(
        id: 'x',
        rect: rect,
        style: _hatched.copyWith(fillStyle: FillStyle.crossHatch),
      );
      await _expectHatchStaysInside(shape, (p) {
        final dx = (p.dx - rect.center.dx) / (rect.width / 2);
        final dy = (p.dy - rect.center.dy) / (rect.height / 2);
        return dx * dx + dy * dy <= 1.0;
      });
    });

    test('a rectangle is still hatched edge to edge', () async {
      final shape = SketchRectangle.create(
        id: 'r',
        rect: rect,
        style: _hatched,
      );
      final px = await _rasterise([shape]);
      var hits = 0;
      for (var y = 22; y < 178; y += 2) {
        for (var x = 22; x < 178; x += 2) {
          if (_isRed(px, 200, x, y)) hits++;
        }
      }
      expect(hits, greaterThan(200));
    });
  });

  group('dashed strokes', () {
    test('a dotted line leaves gaps a solid line does not', () async {
      const size = Size(200, 40);
      SketchLine line(StrokeStyle s) => SketchLine.create(
        id: s.name,
        start: const Offset(10, 20),
        end: const Offset(190, 20),
        style: SketchStyle(
          strokeColor: _hatchRed,
          strokeStyle: s,
          roughness: 0.0,
          strokeWidth: 2.0,
          // `create` hands out a random seed; the rough line still bows
          // by a seed-dependent amount even at roughness 0, which moved the
          // gap count between runs. Pin it so the probe is deterministic.
          seed: 7,
        ),
      );
      final solid = await _rasterise([line(StrokeStyle.solid)], size: size);
      final dotted = await _rasterise([line(StrokeStyle.dotted)], size: size);
      // Columns along the line with no ink anywhere in a band around it
      // (the rough line bows a few px, so a single row would not do).
      int emptyColumns(ByteData px) {
        var n = 0;
        for (var x = 14; x < 186; x++) {
          var inked = false;
          for (var y = 12; y <= 28 && !inked; y++) {
            if (!_isWhite(px, 200, x, y)) inked = true;
          }
          if (!inked) n++;
        }
        return n;
      }

      expect(emptyColumns(solid), 0, reason: 'a solid line has no gaps');
      // (2 on, 4 off) with 2px round caps leaves ~2px of clear gap per
      // 6px period along ~170px: dozens of empty columns.
      expect(emptyColumns(dotted), greaterThan(20));
    });
  });

  group('sweep', () {
    test(
      'painters for removed elements are released on the next generation',
      () {
        final cache = SketchRenderCache();
        final texts = List.generate(
          SketchRenderCache.sweepSlack + 10,
          (i) => SketchText.create(
            id: 't$i',
            position: Offset(0, i * 20.0),
            text: 'line $i',
          ),
        );
        void frame(List<SketchElement> elements, int gen) {
          final recorder = ui.PictureRecorder();
          SketchPainter(
            elements: elements,
            selectedIds: const {},
            viewport: const FlowViewport(),
            paintGen: gen,
            cache: cache,
            selectionColor: const Color(0xFF000000),
            canvasSize: Size(400, texts.length * 20.0 + 40),
          ).paint(Canvas(recorder), const Size(400, 400));
          recorder.endRecording().dispose();
        }

        frame(texts, 1);
        expect(cache.textEntryCount, texts.length);
        frame(texts.sublist(0, 3), 2);
        expect(cache.textEntryCount, 3);
        cache.dispose();
      },
    );
  });
}
