import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'package:flowcraft/canvas/viewport_transform.dart';
import 'package:flowcraft/core/models/flow_viewport.dart';
import 'package:flowcraft/sketch/models/sketch_element.dart';
import 'package:flowcraft/sketch/models/sketch_style.dart';
import 'package:flowcraft/sketch/rendering/sketch_render_cache.dart';

/// Paints all sketch elements on the canvas in a single pass.
///
/// Elements are stored in canvas-space; the painter applies the viewport
/// transform via [Canvas.translate]+[Canvas.scale] so geometry can be
/// fed in unchanged. Stroke widths intentionally scale with zoom to
/// match Excalidraw's behaviour — set [scaleStrokeWithZoom] to false
/// for screen-space stroke widths instead.
class SketchPainter extends CustomPainter {
  SketchPainter({
    required this.elements,
    required this.selectedIds,
    required this.viewport,
    required this.paintGen,
    required this.cache,
    required this.selectionColor,
    this.editingElementId,
    this.scaleStrokeWithZoom = true,
    this.canvasSize,
  });

  final List<SketchElement> elements;
  final Set<String> selectedIds;
  final FlowViewport viewport;
  final int paintGen;
  final SketchRenderCache cache;
  final Color selectionColor;

  /// Element currently being edited in the inline text editor. Its text is
  /// skipped here so it doesn't double up under the editor overlay.
  final String? editingElementId;

  final bool scaleStrokeWithZoom;
  final Size? canvasSize;

  // Reusable paints — mutated per element to avoid per-call allocation.
  static final Paint _strokePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round
    ..strokeJoin = StrokeJoin.round;
  static final Paint _fillPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _hachurePaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeCap = StrokeCap.round;
  static final Paint _selectionPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;
  static final Paint _handleFillPaint = Paint()..style = PaintingStyle.fill;
  static final Paint _handleBorderPaint = Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = 1.0;

  @override
  void paint(Canvas canvas, Size size) {
    if (elements.isEmpty) return;

    final effectiveSize = canvasSize ?? size;
    final viewportRect = _viewportCanvasRect(effectiveSize);

    canvas.save();
    canvas.translate(viewport.offset.dx, viewport.offset.dy);
    canvas.scale(viewport.zoom);

    for (final element in elements) {
      if (!element.bounds.overlaps(viewportRect)) continue;

      final rotated = element.angle != 0.0;
      if (rotated) {
        final c = element.bounds.center;
        canvas.save();
        canvas.translate(c.dx, c.dy);
        canvas.rotate(element.angle);
        canvas.translate(-c.dx, -c.dy);
      }

      _paintElement(canvas, element);

      if (rotated) canvas.restore();
    }

    canvas.restore();

    // Selection overlays are drawn in screen-space for crisp 1px borders
    // regardless of zoom.
    _paintSelectionOverlays(canvas, effectiveSize);
  }

  void _paintElement(Canvas canvas, SketchElement element) {
    final style = element.style;
    final color = style.strokeColor.withValues(alpha: style.opacity);

    // ─── fill (under stroke) ─────────────────────────────────────────────
    if (style.fillStyle != FillStyle.none && style.fillColor != null) {
      switch (style.fillStyle) {
        case FillStyle.solid:
          _fillPaint.color = style.fillColor!.withValues(alpha: style.opacity);
          canvas.drawPath(cache.fillPath(element), _fillPaint);
          break;
        case FillStyle.hachure:
        case FillStyle.crossHatch:
          _hachurePaint
            ..color = style.fillColor!.withValues(alpha: style.opacity)
            ..strokeWidth = _scaleStroke(math.max(1.0, style.strokeWidth * 0.5));
          canvas.drawPath(cache.fillPath(element), _hachurePaint);
          break;
        case FillStyle.none:
          break;
      }
    }

    // ─── stroke ─────────────────────────────────────────────────────────
    _strokePaint
      ..color = color
      ..strokeWidth = _scaleStroke(style.strokeWidth);

    final pattern = style.strokeStyle.pattern;
    final path = cache.strokePath(element);

    if (pattern.isEmpty) {
      canvas.drawPath(path, _strokePaint);
    } else {
      _drawDashedPath(canvas, path, _strokePaint, pattern);
    }

    // ─── per-type extras ─────────────────────────────────────────────────
    final editing = element.id == editingElementId;
    if (!editing && element is SketchArrow) {
      _drawArrowHead(canvas, element);
    }
    if (!editing && element is SketchText) {
      _drawText(canvas, element);
    }
    if (!editing && element is SketchRectangle && element.text != null) {
      _drawCenteredText(canvas, element.bounds, element.text!,
          element.fontSize, style.strokeColor, style.opacity);
    }
    if (!editing && element is SketchEllipse && element.text != null) {
      _drawCenteredText(canvas, element.bounds, element.text!,
          element.fontSize, style.strokeColor, style.opacity);
    }
    if (!editing && element is SketchDiamond && element.text != null) {
      _drawCenteredText(canvas, element.bounds, element.text!,
          element.fontSize, style.strokeColor, style.opacity);
    }
    if (!editing && element is SketchTriangle && element.text != null) {
      _drawCenteredText(canvas, element.bounds, element.text!,
          element.fontSize, style.strokeColor, style.opacity);
    }
    if (!editing && element is SketchSticky && element.text != null) {
      _drawTopLeftText(canvas, element.bounds, element.text!,
          element.fontSize, style.strokeColor, style.opacity);
    }
  }

  void _drawCenteredText(
    Canvas canvas,
    Rect bounds,
    String text,
    double fontSize,
    Color color,
    double opacity,
  ) {
    final span = TextSpan(
      text: text,
      style: TextStyle(
        color: color.withValues(alpha: opacity),
        fontSize: fontSize,
      ),
    );
    final tp = TextPainter(
      text: span,
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: bounds.width - 12);
    final dx = bounds.left + (bounds.width - tp.width) / 2;
    final dy = bounds.top + (bounds.height - tp.height) / 2;
    tp.paint(canvas, Offset(dx, dy));
  }

  void _drawTopLeftText(
    Canvas canvas,
    Rect bounds,
    String text,
    double fontSize,
    Color color,
    double opacity,
  ) {
    final span = TextSpan(
      text: text,
      style: TextStyle(
        color: color.withValues(alpha: opacity),
        fontSize: fontSize,
      ),
    );
    final tp = TextPainter(
      text: span,
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
      maxLines: null,
    )..layout(maxWidth: (bounds.width - 16).clamp(0.0, double.infinity));
    tp.paint(canvas, Offset(bounds.left + 8, bounds.top + 8));
  }

  void _drawArrowHead(Canvas canvas, SketchArrow arrow) {
    final dx = arrow.end.dx - arrow.start.dx;
    final dy = arrow.end.dy - arrow.start.dy;
    final angle = math.atan2(dy, dx);
    // Scale the head with the stroke so thick arrows keep proportion.
    final size = math.max(arrow.arrowSize, arrow.style.strokeWidth * 6.0);
    final tip = arrow.end;

    final left = Offset(
      tip.dx - size * math.cos(angle - 0.5),
      tip.dy - size * math.sin(angle - 0.5),
    );
    final right = Offset(
      tip.dx - size * math.cos(angle + 0.5),
      tip.dy - size * math.sin(angle + 0.5),
    );

    final path = Path()
      ..moveTo(tip.dx, tip.dy)
      ..lineTo(left.dx, left.dy)
      ..lineTo(right.dx, right.dy)
      ..close();
    _fillPaint.color =
        arrow.style.strokeColor.withValues(alpha: arrow.style.opacity);
    canvas.drawPath(path, _fillPaint);
  }

  void _drawText(Canvas canvas, SketchText text) {
    final span = TextSpan(
      text: text.text,
      style: TextStyle(
        color: text.style.strokeColor.withValues(alpha: text.style.opacity),
        fontSize: text.fontSize,
        fontFamily: text.fontFamily,
      ),
    );
    final tp = TextPainter(
      text: span,
      textDirection: TextDirection.ltr,
    )..layout();
    tp.paint(canvas, text.position);
  }

  void _drawDashedPath(
    Canvas canvas,
    Path path,
    Paint paint,
    List<double> pattern,
  ) {
    if (pattern.length < 2) {
      canvas.drawPath(path, paint);
      return;
    }
    for (final metric in path.computeMetrics()) {
      double dist = 0;
      var idx = 0;
      while (dist < metric.length) {
        final len = pattern[idx % pattern.length];
        final end = (dist + len).clamp(0.0, metric.length);
        if (idx.isEven) {
          canvas.drawPath(metric.extractPath(dist, end), paint);
        }
        dist = end;
        idx++;
      }
    }
  }

  void _paintSelectionOverlays(Canvas canvas, Size size) {
    if (selectedIds.isEmpty) return;
    _selectionPaint.color = selectionColor;

    for (final element in elements) {
      if (!selectedIds.contains(element.id)) continue;
      final canvasRect = element.bounds;
      final tl = ViewportTransform.canvasToScreen(canvasRect.topLeft, viewport);
      final br = ViewportTransform.canvasToScreen(canvasRect.bottomRight, viewport);
      final screenRect = Rect.fromLTRB(tl.dx, tl.dy, br.dx, br.dy)
          .inflate(4.0);
      canvas.drawRRect(
        RRect.fromRectAndRadius(screenRect, const Radius.circular(2)),
        _selectionPaint,
      );

      // Resize handle (bottom-right corner) for bounded shapes.
      if (_isResizable(element)) {
        final handleRect = Rect.fromCenter(
          center: screenRect.bottomRight,
          width: 8.0,
          height: 8.0,
        );
        _handleFillPaint.color = const Color(0xFFFFFFFF);
        canvas.drawRect(handleRect, _handleFillPaint);
        _handleBorderPaint.color = selectionColor;
        canvas.drawRect(handleRect, _handleBorderPaint);
      }
    }
  }

  static bool _isResizable(SketchElement e) =>
      e is SketchRectangle ||
      e is SketchEllipse ||
      e is SketchDiamond ||
      e is SketchTriangle ||
      e is SketchSticky;

  double _scaleStroke(double base) =>
      scaleStrokeWithZoom ? base : base / viewport.zoom;

  Rect _viewportCanvasRect(Size size) {
    final topLeft = ViewportTransform.screenToCanvas(Offset.zero, viewport);
    final bottomRight =
        ViewportTransform.screenToCanvas(Offset(size.width, size.height), viewport);
    return Rect.fromLTRB(
      topLeft.dx,
      topLeft.dy,
      bottomRight.dx,
      bottomRight.dy,
    ).inflate(80.0); // safety margin for partial overlaps
  }

  @override
  bool shouldRepaint(SketchPainter old) {
    return paintGen != old.paintGen ||
        viewport != old.viewport ||
        editingElementId != old.editingElementId ||
        !_setEquals(selectedIds, old.selectedIds) ||
        selectionColor != old.selectionColor ||
        scaleStrokeWithZoom != old.scaleStrokeWithZoom;
  }

  static bool _setEquals(Set<String> a, Set<String> b) {
    if (identical(a, b)) return true;
    if (a.length != b.length) return false;
    for (final id in a) {
      if (!b.contains(id)) return false;
    }
    return true;
  }
}
