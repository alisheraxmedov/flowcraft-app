import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'package:flowcraft/canvas/viewport_transform.dart';
import 'package:flowcraft/core/models/flow_viewport.dart';
import 'package:flowcraft/sketch/interactions/sketch_drag_session.dart';
import 'package:flowcraft/sketch/models/sketch_style.dart';
import 'package:flowcraft/sketch/models/sketch_tool.dart';
import 'package:flowcraft/sketch/rendering/rough_generator.dart';

/// Paints the in-progress shape preview, freedraw stroke, or marquee
/// rectangle for the currently-active [SketchDragSession].
///
/// Kept separate from [SketchPainter] so the heavy element layer can stay
/// stable while the preview-only frame updates as the pointer moves.
class SketchPreviewPainter extends CustomPainter {
  SketchPreviewPainter({
    required this.session,
    required this.viewport,
    required this.marqueeColor,
    required this.previewColor,
  });

  final SketchDragSession? session;
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
        _paintArrowHead(canvas, s.startCanvas, s.currentCanvas, 10.0);
        break;
      default:
        break;
    }
  }

  void _paintArrowHead(Canvas canvas, Offset start, Offset end, double size) {
    final dx = end.dx - start.dx;
    final dy = end.dy - start.dy;
    final angle = math.atan2(dy, dx);
    final left = Offset(
      end.dx - size * math.cos(angle - 0.5),
      end.dy - size * math.sin(angle - 0.5),
    );
    final right = Offset(
      end.dx - size * math.cos(angle + 0.5),
      end.dy - size * math.sin(angle + 0.5),
    );
    final path = Path()
      ..moveTo(end.dx, end.dy)
      ..lineTo(left.dx, left.dy)
      ..moveTo(end.dx, end.dy)
      ..lineTo(right.dx, right.dy);
    canvas.drawPath(path, _strokePaint);
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
      !identical(session, old.session) ||
      viewport != old.viewport ||
      marqueeColor != old.marqueeColor ||
      previewColor != old.previewColor ||
      _sessionStateChanged(old);

  bool _sessionStateChanged(SketchPreviewPainter old) {
    final a = session;
    final b = old.session;
    if (a == null && b == null) return false;
    if (a == null || b == null) return true;
    return a.currentCanvas != b.currentCanvas ||
        a.startCanvas != b.startCanvas ||
        (a.freedrawPoints?.length ?? 0) !=
            (b.freedrawPoints?.length ?? 0);
  }
}
