import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'package:flowcraft/core/canvas/viewport_transform.dart';
import 'package:flowcraft/core/domain/sticky_bubble_geometry.dart';
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
///
/// The preview is painted in the session's own [SketchStyle] — the stroke
/// colour, width and dash pattern the element will be committed with. It
/// used to take a fixed `previewColor` that nothing ever overrode, so every
/// rubber-band shape was near-black whatever colour the user had picked,
/// and invisible against a dark canvas.
class SketchPreviewPainter extends CustomPainter {
  SketchPreviewPainter({
    required this.session,
    required this.revision,
    required this.viewport,
    required this.marqueeColor,
  });

  /// Opacity the in-progress stroke is drawn at, on top of the style's own,
  /// so the preview reads as "not yet committed".
  static const double previewAlpha = 0.85;

  final SketchDragSession? session;
  final int revision;
  final FlowViewport viewport;
  final Color marqueeColor;

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

  /// The colour a preview for [style] is stroked in.
  static Color previewColorFor(SketchStyle style) =>
      style.strokeColor.withValues(alpha: style.opacity * previewAlpha);

  @override
  void paint(Canvas canvas, Size size) {
    final s = session;
    if (s == null) return;

    canvas.save();
    canvas.translate(viewport.offset.dx, viewport.offset.dy);
    canvas.scale(viewport.zoom);

    final style = s.style;
    _strokePaint
      ..color = previewColorFor(style)
      ..strokeWidth = style.strokeWidth;

    switch (s.kind) {
      case SketchSessionKind.createBounded:
        _paintBoundedPreview(canvas, s, style);
        break;
      case SketchSessionKind.createFreedraw:
        final points = s.freedrawPoints;
        if (points != null && points.length > 1) {
          _drawStroke(
            canvas,
            RoughGenerator.polyline(points, roughness: 0.0, seed: style.seed),
            style,
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
        _drawStroke(
          canvas,
          RoughGenerator.rectangle(
            rect,
            roughness: style.roughness,
            seed: style.seed,
            doubleStroke: false,
          ),
          style,
        );
        break;
      case SketchTool.ellipse:
        _drawStroke(
          canvas,
          RoughGenerator.ellipse(
            rect,
            roughness: style.roughness,
            seed: style.seed,
            doubleStroke: false,
          ),
          style,
        );
        break;
      case SketchTool.diamond:
        _drawStroke(
          canvas,
          RoughGenerator.diamond(
            rect,
            roughness: style.roughness,
            seed: style.seed,
            doubleStroke: false,
          ),
          style,
        );
        break;
      case SketchTool.triangle:
        _drawStroke(
          canvas,
          RoughGenerator.triangle(
            rect,
            roughness: style.roughness,
            seed: style.seed,
            doubleStroke: false,
          ),
          style,
        );
        break;
      case SketchTool.sticky:
        _paintStickyPreview(canvas, rect);
        break;
      case SketchTool.line:
        _drawStroke(
          canvas,
          RoughGenerator.line(
            s.startCanvas,
            s.currentCanvas,
            roughness: style.roughness,
            seed: style.seed,
            doubleStroke: false,
          ),
          style,
        );
        break;
      case SketchTool.arrow:
        _drawStroke(
          canvas,
          RoughGenerator.line(
            s.startCanvas,
            s.currentCanvas,
            roughness: style.roughness,
            seed: style.seed,
            doubleStroke: false,
          ),
          style,
        );
        _paintArrowHead(canvas, s.startCanvas, s.currentCanvas, style);
        break;
      default:
        break;
    }
  }

  /// Strokes [path] in [style]'s colour, width and dash pattern — the
  /// same three things `SketchRenderCache` bakes into the committed
  /// element's outline, so the preview and the result match.
  void _drawStroke(Canvas canvas, Path path, SketchStyle style) {
    _strokePaint
      ..color = previewColorFor(style)
      ..strokeWidth = style.strokeWidth;
    canvas.drawPath(
      RoughGenerator.dash(path, style.strokeStyle.pattern),
      _strokePaint,
    );
  }

  /// Previews the note as the bubble it will become, not as the rectangle it
  /// is being dragged out as — including the floor the commit applies, so a
  /// press with no drag shows the note it is about to leave behind.
  void _paintStickyPreview(Canvas canvas, Rect rect) {
    final settled = SketchSticky.rectFor(rect);
    final bubble = StickyBubbleGeometry.bubblePath(
      settled,
      SketchSticky.defaultCornerRadius,
    );
    // The note's own default colours rather than the preview tint: the
    // preview is the note, a frame early.
    _marqueeFill.color = SketchSticky.defaultColor.withValues(alpha: 0.9);
    canvas.drawPath(bubble, _marqueeFill);
    _strokePaint
      ..color = SketchSticky.defaultEdgeColor.withValues(alpha: 0.9)
      ..strokeWidth = SketchSticky.defaultStrokeWidth;
    canvas.drawPath(bubble, _strokePaint);
  }

  void _paintArrowHead(
    Canvas canvas,
    Offset start,
    Offset end,
    SketchStyle style,
  ) {
    final size = math.max(10.0, style.strokeWidth * 6.0);
    final path = ArrowHead.path(start, end, size);
    _marqueeFill.color = previewColorFor(style);
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
      marqueeColor != old.marqueeColor;
}
