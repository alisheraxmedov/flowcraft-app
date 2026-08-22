import 'dart:math' as math;

import 'package:flutter/rendering.dart';

import 'package:flowcraft/core/canvas/viewport_transform.dart';
import 'package:flowcraft/core/domain/sketch_geometry.dart';
import 'package:flowcraft/core/domain/sketch_hit_test.dart';
import 'package:flowcraft/core/domain/sticky_bubble_geometry.dart';
import 'package:flowcraft/core/domain/text_metrics.dart';
import 'package:flowcraft/models/flow_viewport.dart';
import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/models/sketch_style.dart';
import 'package:flowcraft/core/rendering/arrow_head.dart';
import 'package:flowcraft/core/rendering/sketch_render_cache.dart';

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
    this.handleFillColor = _defaultHandleFill,
    this.editingElementId,
    this.scaleStrokeWithZoom = true,
    this.canvasSize,
  });

  /// Fill for resize / endpoint handles when the host doesn't supply one.
  ///
  /// A neutral chip under the themed [selectionColor] border, which is what
  /// carries the theme here; a host with a light-on-light surface passes
  /// [handleFillColor] from its own `colorScheme`.
  static const Color _defaultHandleFill = Color(0xFFFFFFFF);

  /// Screen-space side of a square resize handle.
  static const double _handleSize = 8.0;

  /// Screen-space radius of a round endpoint handle. Deliberately round
  /// where resize handles are square: on a diagonal line the two shapes end
  /// up close together, and a shared shape would leave the user guessing
  /// which one they are about to grab.
  static const double _endpointHandleRadius = 4.5;

  final List<SketchElement> elements;
  final Set<String> selectedIds;
  final FlowViewport viewport;
  final int paintGen;
  final SketchRenderCache cache;
  final Color selectionColor;
  final Color handleFillColor;

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
    // Before the empty check: a scene cleared to nothing is exactly when
    // every cached painter has gone stale.
    cache.sweep(elements, generation: paintGen);
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
    // A collapsed sticky's only stroke work is its badge mark, which is a
    // glyph: it takes the note's ink rather than its outline colour so it
    // reads against the paper, and a fixed weight rather than the style's
    // stroke width so it stays an icon. Every other element strokes as it
    // always did.
    final badgeMark = element is SketchSticky && element.collapsed;
    final strokeSource = badgeMark ? element.inkColor : style.strokeColor;
    final color = strokeSource.withValues(alpha: style.opacity);
    final strokeWidth =
        badgeMark ? StickyBubbleGeometry.glyphStrokeWidth : style.strokeWidth;

    // ─── fill (under stroke) ─────────────────────────────────────────────
    if (style.fillStyle != FillStyle.none && style.fillColor != null) {
      switch (style.fillStyle) {
        case FillStyle.solid:
          _fillPaint.color = style.fillColor!.withValues(alpha: style.opacity);
          canvas.drawPath(cache.fillPath(element), _fillPaint);
          break;
        case FillStyle.hachure:
        case FillStyle.crossHatch:
          if (SketchRenderCache.hatchFallsBackToSolid(element)) {
            // Too large to hatch — the cache handed back the silhouette.
            _fillPaint.color =
                style.fillColor!.withValues(alpha: style.opacity);
            canvas.drawPath(cache.fillPath(element), _fillPaint);
            break;
          }
          _hachurePaint
            ..color = style.fillColor!.withValues(alpha: style.opacity)
            ..strokeWidth = _scaleStroke(math.max(1.0, style.strokeWidth * 0.5));
          // The hatch is generated over the bounding rect; clipping it to
          // the outline is what keeps a hatched circle's corners empty.
          final clipped = SketchRenderCache.hatchNeedsClip(element);
          if (clipped) {
            canvas.save();
            canvas.clipPath(cache.outlinePath(element));
          }
          canvas.drawPath(cache.fillPath(element), _hachurePaint);
          if (clipped) canvas.restore();
          break;
        case FillStyle.none:
          break;
      }
    }

    // ─── stroke ─────────────────────────────────────────────────────────
    _strokePaint
      ..color = color
      ..strokeWidth = _scaleStroke(strokeWidth);

    // Already dashed/dotted by the cache when the style asks for it, so a
    // patterned outline is one draw call like a solid one.
    canvas.drawPath(cache.strokePath(element), _strokePaint);

    // ─── per-type extras ─────────────────────────────────────────────────
    final editing = element.id == editingElementId;
    if (!editing && element is SketchArrow) {
      _drawArrowHead(canvas, element);
    }
    if (!editing && element is SketchText) {
      _drawText(canvas, element);
    }
    // Rectangle/ellipse/diamond/triangle all carry the same optional
    // centred label — they don't share a *public* base type to switch on
    // (their common base is package-private to sketch_element.dart), so
    // this switch expression is the one place that collapses the 4
    // otherwise-identical branches into a single call.
    final centeredLabel = switch (element) {
      SketchRectangle(:final text, :final fontSize) when text != null =>
        (text, fontSize),
      SketchEllipse(:final text, :final fontSize) when text != null =>
        (text, fontSize),
      SketchDiamond(:final text, :final fontSize) when text != null =>
        (text, fontSize),
      SketchTriangle(:final text, :final fontSize) when text != null =>
        (text, fontSize),
      _ => null,
    };
    if (!editing && centeredLabel != null) {
      _drawCenteredText(canvas, element, centeredLabel.$1, centeredLabel.$2);
    }
    // A collapsed note shows its badge mark instead of its label; the text
    // is still there, it is just not what is on screen.
    if (!editing &&
        element is SketchSticky &&
        !element.collapsed &&
        element.text != null) {
      _drawStickyLabel(canvas, element);
    }
  }

  /// Horizontal inset a centred shape label wraps inside of, per side ×2.
  static const double _labelInset = 12.0;

  /// Draws a shape's centred label, laid out once per element instance.
  ///
  /// Every input — text, size, colour, opacity, the width it wraps to — is
  /// a field of [element], so the cache's identity key covers it all; a
  /// restyle or resize is a new instance and lays out afresh. Laying out
  /// here every frame was the single largest per-frame cost on a labelled
  /// board (16 µs per label per pan step).
  void _drawCenteredText(
    Canvas canvas,
    SketchElement element,
    String text,
    double fontSize,
  ) {
    final bounds = element.bounds;
    // The resize floor is 10 px, narrower than the inset — below it there
    // is no room to wrap into, and a negative `maxWidth` trips
    // `TextPainter.layout`'s clamp assertion in debug, every frame, until
    // the shape is widened again.
    if (bounds.width < _labelInset) return;
    final tp = cache.textPainter(
      element,
      () => TextMetrics.layout(
        text: text,
        fontSize: fontSize,
        color: element.style.strokeColor
            .withValues(alpha: element.style.opacity),
        maxWidth: math.max(0.0, bounds.width - _labelInset),
        textAlign: TextAlign.center,
      ),
    );
    final dx = bounds.left + (bounds.width - tp.width) / 2;
    final dy = bounds.top + (bounds.height - tp.height) / 2;
    tp.paint(canvas, Offset(dx, dy));
  }

  /// Lays out a note's label inside the bubble's text box.
  ///
  /// The box comes from [StickyBubbleGeometry.textBoxOf] rather than from an
  /// inset computed here, because `SketchTextEditor` positions the *editable*
  /// glyphs from the same call. Two copies of that arithmetic is exactly how
  /// the label used to jump the instant editing started.
  void _drawStickyLabel(Canvas canvas, SketchSticky sticky) {
    final box = StickyBubbleGeometry.textBoxOf(sticky.rect);
    // Same layout `SketchSticky.labelSize` measures with, so the height the
    // note grows to on commit is the height these glyphs actually take.
    // Cached per note instance; the cache owns the painter.
    final tp = cache.textPainter(
      sticky,
      () => TextMetrics.layout(
        text: sticky.text!,
        fontSize: sticky.fontSize,
        color: sticky.inkColor.withValues(alpha: sticky.style.opacity),
        maxWidth: box.width,
      ),
    );
    // A committed note grows to fit its text, so this clip rarely cuts
    // anything — it is for the note a user has since resized *smaller*
    // than its text, where glyphs running out through the tail and past
    // the bottom edge read as a broken element. Clipped to the body rather
    // than the text box so a descender on the last line isn't sliced off
    // by the inset.
    canvas.save();
    canvas.clipRect(StickyBubbleGeometry.bodyOf(sticky.rect));
    tp.paint(canvas, box.topLeft);
    canvas.restore();
  }

  void _drawArrowHead(Canvas canvas, SketchArrow arrow) {
    // Scale the head with the stroke so thick arrows keep proportion.
    final size = math.max(arrow.arrowSize, arrow.style.strokeWidth * 6.0);
    final path = ArrowHead.path(arrow.start, arrow.end, size);
    _fillPaint.color =
        arrow.style.strokeColor.withValues(alpha: arrow.style.opacity);
    canvas.drawPath(path, _fillPaint);
  }

  void _drawText(Canvas canvas, SketchText text) {
    // Same layout path as `SketchText.bounds` — that shared call is what
    // keeps the painted glyphs and the hit-test box from drifting apart.
    // Cached per element instance; the cache owns the painter.
    final tp = cache.textPainter(
      text,
      () => TextMetrics.layout(
        text: text.text,
        fontSize: text.fontSize,
        fontFamily: text.fontFamily,
        color: text.style.strokeColor.withValues(alpha: text.style.opacity),
      ),
    );
    tp.paint(canvas, text.position);
  }

  void _paintSelectionOverlays(Canvas canvas, Size size) {
    if (selectedIds.isEmpty) return;
    _selectionPaint.color = selectionColor;
    _handleFillPaint.color = handleFillColor;
    _handleBorderPaint.color = selectionColor;

    for (final element in elements) {
      if (!selectedIds.contains(element.id)) continue;
      final canvasRect = element.bounds;
      final tl = ViewportTransform.canvasToScreen(canvasRect.topLeft, viewport);
      final br = ViewportTransform.canvasToScreen(canvasRect.bottomRight, viewport);
      // Padded by the same shared constant the gesture handler hit-tests
      // against, so the handle under the cursor is the handle that is drawn.
      final screenRect = Rect.fromLTRB(tl.dx, tl.dy, br.dx, br.dy)
          .inflate(SketchGeometry.selectionPadding);
      canvas.drawRRect(
        RRect.fromRectAndRadius(screenRect, const Radius.circular(2)),
        _selectionPaint,
      );

      // Handles are placed and sized in screen-space, so they stay a
      // constant, grabbable size however far the canvas is zoomed.
      if (SketchHitTest.isResizable(element)) {
        for (final handle in ResizeHandle.values) {
          _drawResizeHandle(
            canvas,
            SketchGeometry.handlePosition(screenRect, handle),
          );
        }
      }

      // A line / arrow is defined by its two endpoints, not by the corners
      // of the box around it — which for a diagonal are the same two points
      // and for an axis-aligned one are not.
      final ends = _endpointsOf(element);
      if (ends != null) {
        _drawEndpointHandle(
          canvas,
          ViewportTransform.canvasToScreen(ends.$1, viewport),
        );
        _drawEndpointHandle(
          canvas,
          ViewportTransform.canvasToScreen(ends.$2, viewport),
        );
      }
    }
  }

  void _drawResizeHandle(Canvas canvas, Offset centre) {
    final rect = Rect.fromCenter(
      center: centre,
      width: _handleSize,
      height: _handleSize,
    );
    canvas.drawRect(rect, _handleFillPaint);
    canvas.drawRect(rect, _handleBorderPaint);
  }

  void _drawEndpointHandle(Canvas canvas, Offset centre) {
    canvas.drawCircle(centre, _endpointHandleRadius, _handleFillPaint);
    canvas.drawCircle(centre, _endpointHandleRadius, _handleBorderPaint);
  }

  static (Offset, Offset)? _endpointsOf(SketchElement e) => switch (e) {
        SketchLine l => (l.start, l.end),
        SketchArrow a => (a.start, a.end),
        _ => null,
      };

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
        handleFillColor != old.handleFillColor ||
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
