import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/core/interactions/sketch_drag_session.dart';
import 'package:flowcraft/core/rendering/sketch_preview_painter.dart';
import 'package:flowcraft/models/flow_viewport.dart';
import 'package:flowcraft/models/sketch_style.dart';
import 'package:flowcraft/models/sketch_tool.dart';

const Color _marquee = Color(0xFF00FF00);

/// Rasterises the preview for [session] on a white 200×200 canvas.
Future<ByteData> _rasterise(SketchDragSession session) async {
  const size = Size(200, 200);
  final recorder = ui.PictureRecorder();
  final canvas = Canvas(recorder, Offset.zero & size);
  canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFFFFFFFF));
  SketchPreviewPainter(
    session: session,
    revision: 1,
    viewport: const FlowViewport(),
    marqueeColor: _marquee,
  ).paint(canvas, size);
  final picture = recorder.endRecording();
  final image = await picture.toImage(200, 200);
  picture.dispose();
  final bytes = await image.toByteData(format: ui.ImageByteFormat.rawRgba);
  image.dispose();
  return bytes!;
}

/// Pixels on the canvas whose colour is dominated by [channel] (0 = r,
/// 1 = g, 2 = b).
int _countDominant(ByteData px, int channel) {
  var n = 0;
  for (var i = 0; i < px.lengthInBytes; i += 4) {
    final c = [px.getUint8(i), px.getUint8(i + 1), px.getUint8(i + 2)];
    final others = [
      for (var k = 0; k < 3; k++)
        if (k != channel) c[k],
    ];
    if (c[channel] > 150 && others.every((v) => v < 100)) n++;
  }
  return n;
}

SketchDragSession _rectSession(SketchStyle style) => SketchDragSession(
  kind: SketchSessionKind.createBounded,
  startCanvas: const Offset(20, 20),
  startScreen: const Offset(20, 20),
  style: style,
  tool: SketchTool.rectangle,
)..currentCanvas = const Offset(180, 180);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('the preview is painted in the session style', () {
    test('stroke colour comes from the style, not a fixed tint', () async {
      const red = SketchStyle(
        strokeColor: Color(0xFFFF0000),
        roughness: 0.0,
        strokeWidth: 3.0,
      );
      final px = await _rasterise(_rectSession(red));
      expect(
        _countDominant(px, 0),
        greaterThan(200),
        reason: 'the rubber-band rectangle is red',
      );
      expect(_countDominant(px, 2), 0, reason: 'nothing is painted blue');

      const blue = SketchStyle(
        strokeColor: Color(0xFF0000FF),
        roughness: 0.0,
        strokeWidth: 3.0,
      );
      final px2 = await _rasterise(_rectSession(blue));
      expect(_countDominant(px2, 2), greaterThan(200));
      expect(_countDominant(px2, 0), 0);
    });

    test('previewColorFor keeps the hue and dims by the preview alpha', () {
      const style = SketchStyle(strokeColor: Color(0xFF123456), opacity: 0.5);
      final c = SketchPreviewPainter.previewColorFor(style);
      expect(c.r, closeTo(0x12 / 255, 0.001));
      expect(c.g, closeTo(0x34 / 255, 0.001));
      expect(c.b, closeTo(0x56 / 255, 0.001));
      expect(c.a, closeTo(0.5 * SketchPreviewPainter.previewAlpha, 0.001));
    });

    test('a dotted style previews dotted', () async {
      const solid = SketchStyle(
        strokeColor: Color(0xFFFF0000),
        roughness: 0.0,
        strokeWidth: 2.0,
      );
      final solidInk = _countDominant(await _rasterise(_rectSession(solid)), 0);
      final dottedInk = _countDominant(
        await _rasterise(
          _rectSession(solid.copyWith(strokeStyle: StrokeStyle.dotted)),
        ),
        0,
      );
      expect(dottedInk, greaterThan(0));
      expect(dottedInk, lessThan(solidInk * 0.8));
    });

    test('the arrow head takes the style colour too', () async {
      final session = SketchDragSession(
        kind: SketchSessionKind.createBounded,
        startCanvas: const Offset(20, 100),
        startScreen: const Offset(20, 100),
        style: const SketchStyle(
          strokeColor: Color(0xFFFF0000),
          roughness: 0.0,
          strokeWidth: 2.0,
        ),
        tool: SketchTool.arrow,
      )..currentCanvas = const Offset(180, 100);
      final px = await _rasterise(session);
      // The filled head is a solid red patch near the tip, several pixels
      // tall — far more red than a 2px shaft alone would contribute there.
      var headRed = 0;
      for (var y = 90; y <= 110; y++) {
        for (var x = 160; x <= 180; x++) {
          final i = (y * 200 + x) * 4;
          if (px.getUint8(i) > 150 &&
              px.getUint8(i + 1) < 100 &&
              px.getUint8(i + 2) < 100) {
            headRed++;
          }
        }
      }
      expect(headRed, greaterThan(60));
      expect(_countDominant(px, 2), 0);
    });
  });

  test('shouldRepaint tracks revision, viewport and marquee colour only', () {
    final a = SketchPreviewPainter(
      session: null,
      revision: 1,
      viewport: const FlowViewport(),
      marqueeColor: _marquee,
    );
    final same = SketchPreviewPainter(
      session: null,
      revision: 1,
      viewport: const FlowViewport(),
      marqueeColor: _marquee,
    );
    final bumped = SketchPreviewPainter(
      session: null,
      revision: 2,
      viewport: const FlowViewport(),
      marqueeColor: _marquee,
    );
    expect(bumped.shouldRepaint(a), isTrue);
    expect(same.shouldRepaint(a), isFalse);
  });
}
