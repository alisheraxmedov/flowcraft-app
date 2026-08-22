import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'package:flowcraft/core/canvas/viewport_transform.dart';
import 'package:flowcraft/models/flow_viewport.dart';
import 'package:flowcraft/core/interactions/sketch_drag_session.dart';
import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/models/sketch_style.dart';
import 'package:flowcraft/models/sketch_tool.dart';
import 'package:flowcraft/core/rendering/arrow_head.dart';
import 'package:flowcraft/core/rendering/rough_generator.dart';

/// Paints the in-progress shape preview, freedraw stroke, or marquee
/// rectangle for the currently-active [SketchDragSession].
///
/// Kept separate from [SketchPainter] so the heavy element layer can stay
/// stable while the preview-only frame updates as the pointer moves.
class SketchPreviewPainter extends CustomPainter {
  SketchPreviewPainter({
    required this.session,
    required this.revision,
    required this.viewport,
    required this.marqueeColor,
    required this.previewColor,
  });

  final SketchDragSession? session;
  final int revision;
  final FlowViewport viewport;
  final Color marqueeColor;
  final Color previewColor;

  static final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static final Paint _marqueeStroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  static final Paint _marqueeFill = Paint()..style = PaintingStyle.fill;
  static final Paint _guideStroke = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    final s = session;
    if (s == null) return;

    canvas.save();
    canvas.translate(viewport.offset.dx, viewport.offset.dy);
    canvas.scale(viewport.zoom);

    final style = s.style;
    _strokePaint
      ..color = previewColor.withValues(alpha: 0.85)
      ..strokeWidth = style.strokeWidth;

    switch (s.kind) {
      case SketchSessionKind.createBounded:
        _paintBoundedPreview(canvas, s, style);
        break;
      case SketchSessionKind.createFreedraw:
        final points = s.freedrawPoints;
        if (points != null && points.length > 1) {
          canvas.drawPath(
            RoughGenerator.polyline(points, roughness: 0.0, seed: style.seed),
            _strokePaint,
          );
        }
        break;
      default:
        break;
    }

    canvas.restore();

    if (s.kind == SketchSessionKind.marquee) {
      _paintMarquee(canvas, s);
    }
    _paintGuides(canvas, s);
  }

  /// Draws the alignment guides the active snap produced, in screen-space
  /// so the line stays hairline-thin at any zoom.
  void _paintGuides(Canvas canvas, SketchDragSession s) {
    if (s.guides.isEmpty) return;
    _guideStroke.color = marqueeColor;
    for (final guide in s.guides) {
      final a = guide.vertical
          ? Offset(guide.position, guide.from)
          : Offset(guide.from, guide.position);
      final b = guide.vertical
          ? Offset(guide.position, guide.to)
          : Offset(guide.to, guide.position);
      canvas.drawLine(
        ViewportTransform.canvasToScreen(a, viewport),
        ViewportTransform.canvasToScreen(b, viewport),
        _guideStroke,
      );
    }
  }

  void _paintBoundedPreview(
    Canvas canvas,
    SketchDragSession s,
    SketchStyle style,
  ) {
    final tool = s.tool;
    if (tool == null) return;
    final rect = s.currentRect;

    switch (tool) {
      case SketchTool.rectangle:
        canvas.drawPath(
          RoughGenerator.rectangle(
            rect,
            roughness: style.roughness,
            seed: style.seed,
            doubleStroke: false,
          ),
          _strokePaint,
        );
        break;
      case SketchTool.ellipse:
        canvas.drawPath(
          RoughGenerator.ellipse(
            rect,
            roughness: style.roughness,
            seed: style.seed,
            doubleStroke: false,
          ),
          _strokePaint,
        );
        break;
      case SketchTool.diamond:
        canvas.drawPath(
          RoughGenerator.diamond(
            rect,
            roughness: style.roughness,
            seed: style.seed,
            doubleStroke: false,
          ),
          _strokePaint,
        );
        break;
      case SketchTool.triangle:
        canvas.drawPath(
          RoughGenerator.triangle(
            rect,
            roughness: style.roughness,
            seed: style.seed,
            doubleStroke: false,
          ),
          _strokePaint,
        );
        break;
      case SketchTool.sticky:
        _paintStickyPreview(canvas, rect);
        break;
      case SketchTool.line:
        canvas.drawPath(
          RoughGenerator.line(
            s.startCanvas,
            s.currentCanvas,
            roughness: style.roughness,
            seed: style.seed,
            doubleStroke: false,
          ),
          _strokePaint,
        );
        break;
      case SketchTool.arrow:
        canvas.drawPath(
          RoughGenerator.line(
            s.startCanvas,
            s.currentCanvas,
            roughness: style.roughness,
            seed: style.seed,
            doubleStroke: false,
          ),
          _strokePaint,
        );
        _paintArrowHead(canvas, s.startCanvas, s.currentCanvas, style.strokeWidth);
        break;
      default:
        break;
    }
  }

  void _paintStickyPreview(Canvas canvas, Rect rect) {
    final rr = RRect.fromRectAndRadius(rect, const Radius.circular(4));
    _marqueeFill.color = SketchSticky.defaultColor.withValues(alpha: 0.9);
    canvas.drawRRect(rr, _marqueeFill);
    _strokePaint
      ..color = previewColor.withValues(alpha: 0.5)
      ..strokeWidth = 1.0;
    canvas.drawRRect(rr, _strokePaint);
  }

  void _paintArrowHead(Canvas canvas, Offset start, Offset end, double strokeWidth) {
    final size = math.max(10.0, strokeWidth * 6.0);
    final path = ArrowHead.path(start, end, size);
    _marqueeFill.color = previewColor.withValues(alpha: 0.85);
    canvas.drawPath(path, _marqueeFill);
  }

  void _paintMarquee(Canvas canvas, SketchDragSession s) {
    final tl = ViewportTransform.canvasToScreen(s.currentRect.topLeft, viewport);
    final br = ViewportTransform.canvasToScreen(s.currentRect.bottomRight, viewport);
    final rect = Rect.fromLTRB(tl.dx, tl.dy, br.dx, br.dy);
    _marqueeStroke.color = marqueeColor;
    _marqueeFill.color = marqueeColor.withValues(alpha: 0.12);
    canvas.drawRect(rect, _marqueeFill);
    canvas.drawRect(rect, _marqueeStroke);
  }

  @override
  bool shouldRepaint(SketchPreviewPainter old) =>
      revision != old.revision ||
      viewport != old.viewport ||
      marqueeColor != old.marqueeColor ||
      previewColor != old.previewColor;
}
