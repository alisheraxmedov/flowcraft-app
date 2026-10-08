import 'dart:math' as math;
import 'dart:ui';

import 'package:flowcraft/core/domain/sticky_bubble_geometry.dart';
import 'package:flowcraft/core/domain/text_metrics.dart';
import 'package:flowcraft/core/rendering/arrow_head.dart';
import 'package:flowcraft/core/rendering/sketch_painter.dart';
import 'package:flowcraft/core/rendering/sketch_render_cache.dart';
import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/models/sketch_style.dart';
import 'package:flowcraft/services/canvas_exporter.dart';

/// Renders the scene to an SVG document that keeps the hand-drawn look.
///
/// Rather than re-deriving shapes as SVG primitives (which would lose the
/// wobble), it asks [SketchRenderCache] for the very paths [SketchPainter]
/// draws and samples each contour into a polyline. The file therefore
/// matches the canvas and the PNG, and needs no SVG-side roughness.
class SvgExporter {
  SvgExporter._();

  /// Distance between sampled points, in canvas px. Fine enough that a
  /// polyline reads as a curve at 4x zoom, coarse enough to keep files small.
  static const double _step = 2.0;

  /// Renders [elements] over an optional opaque [background]; the viewBox is
  /// the content bounds inflated by [padding]. An empty scene still yields a
  /// valid (blank) document.
  static Future<String> render(
    List<SketchElement> elements, {
    Color? background,
    double padding = 32,
  }) async {
    final box = CanvasExporter.contentBounds(elements).inflate(padding);
    final cache = SketchRenderCache();
    final out = StringBuffer()
      ..write('<svg xmlns="http://www.w3.org/2000/svg" ')
      ..write('viewBox="${_n(box.left)} ${_n(box.top)} ')
      ..write('${_n(box.width)} ${_n(box.height)}" ')
      ..write('width="${_n(box.width)}" height="${_n(box.height)}">');
    try {
      if (background != null) {
        out.write(
          '<rect x="${_n(box.left)}" y="${_n(box.top)}" '
          'width="${_n(box.width)}" height="${_n(box.height)}" '
          'fill="${_hex(background)}"/>',
        );
      }
      var clipId = 0;
      for (final element in elements) {
        // A later task teaches the exporter the newer element types; until
        // then they are skipped rather than mis-drawn.
        if (!_isSupported(element) || !element.bounds.isFinite) continue;
        final rotated = element.angle != 0.0;
        if (rotated) {
          final c = element.bounds.center;
          out.write(
            '<g transform="rotate(${_n(element.angle * 180 / math.pi)} '
            '${_n(c.dx)} ${_n(c.dy)})">',
          );
        }
        _element(out, cache, element, () => clipId++);
        if (rotated) out.write('</g>');
      }
    } finally {
      cache.dispose();
    }
    out.write('</svg>');
    return out.toString();
  }

  static bool _isSupported(SketchElement e) =>
      e is SketchRectangle ||
      e is SketchEllipse ||
      e is SketchDiamond ||
      e is SketchTriangle ||
      e is SketchSticky ||
      e is SketchLine ||
      e is SketchArrow ||
      e is SketchFreedraw ||
      e is SketchText;

  /// Mirrors `SketchPainter._paintElement`: fill, stroke, then extras.
  static void _element(
    StringBuffer out,
    SketchRenderCache cache,
    SketchElement element,
    int Function() nextClipId,
  ) {
    final style = element.style;
    final badgeMark = element is SketchSticky && element.collapsed;
    final strokeColor = badgeMark ? element.inkColor : style.strokeColor;
    final strokeWidth = badgeMark
        ? StickyBubbleGeometry.glyphStrokeWidth
        : style.strokeWidth;

    final fill = style.fillColor;
    if (style.fillStyle != FillStyle.none && fill != null) {
      final solid =
          style.fillStyle == FillStyle.solid ||
          SketchRenderCache.hatchFallsBackToSolid(element);
      if (solid) {
        out.write(
          '<path d="${_d(cache.fillPath(element))}" fill="${_hex(fill)}" '
          'fill-opacity="${_n(style.opacity)}"/>',
        );
      } else {
        final hatch =
            '<path d="${_d(cache.fillPath(element), open: true)}" fill="none" '
            'stroke="${_hex(fill)}" stroke-opacity="${_n(style.opacity)}" '
            'stroke-width="${_n(math.max(1.0, style.strokeWidth * 0.5))}" '
            'stroke-linecap="round"/>';
        if (SketchRenderCache.hatchNeedsClip(element)) {
          final id = 'c${nextClipId()}';
          out.write(
            '<clipPath id="$id"><path d="${_d(cache.outlinePath(element))}"/>'
            '</clipPath><g clip-path="url(#$id)">$hatch</g>',
          );
        } else {
          out.write(hatch);
        }
      }
    }

    // Dashes are already separate contours in the cached path.
    out.write(
      '<path d="${_d(cache.strokePath(element), open: true)}" fill="none" '
      'stroke="${_hex(strokeColor)}" stroke-opacity="${_n(style.opacity)}" '
      'stroke-width="${_n(strokeWidth)}" stroke-linecap="round" '
      'stroke-linejoin="round"/>',
    );

    if (element is SketchArrow) {
      final head = ArrowHead.path(
        element.start,
        element.end,
        element.headLength,
      );
      out.write(
        '<path d="${_d(head)}" fill="${_hex(style.strokeColor)}" '
        'fill-opacity="${_n(style.opacity)}"/>',
      );
    }
    if (element is SketchText) {
      _text(
        out,
        element.text,
        element.position,
        fontSize: element.fontSize,
        fontFamily: element.fontFamily,
        color: style.strokeColor,
        opacity: style.opacity,
      );
    }
    final label = switch (element) {
      SketchRectangle(:final text, :final fontSize) when text != null => (
        text,
        fontSize,
      ),
      SketchEllipse(:final text, :final fontSize) when text != null => (
        text,
        fontSize,
      ),
      SketchDiamond(:final text, :final fontSize) when text != null => (
        text,
        fontSize,
      ),
      SketchTriangle(:final text, :final fontSize) when text != null => (
        text,
        fontSize,
      ),
      _ => null,
    };
    final bounds = element.bounds;
    if (label != null && bounds.width >= SketchPainter.labelInset) {
      _text(
        out,
        label.$1,
        bounds.topLeft,
        fontSize: label.$2,
        color: style.strokeColor,
        opacity: style.opacity,
        // Wrap and centre exactly as `SketchPainter._drawCenteredText`.
        centerIn: bounds,
        maxWidth: math.max(0.0, bounds.width - SketchPainter.labelInset),
      );
    }
    if (element is SketchSticky && !element.collapsed && element.text != null) {
      final box = StickyBubbleGeometry.textBoxOf(element.rect);
      // ponytail: no clip to the note body, so text of a note resized
      // smaller than its content overflows; add a clipPath if that shows up.
      _text(
        out,
        element.text!,
        box.topLeft,
        fontSize: element.fontSize,
        color: element.inkColor,
        opacity: style.opacity,
        maxWidth: box.width,
      );
    }
  }

  /// Emits one `<text>` with a `<tspan>` per painted line. Line breaks come
  /// from the same [TextMetrics.layout] the painter uses, so wrapping in the
  /// SVG equals wrapping on the canvas.
  static void _text(
    StringBuffer out,
    String text,
    Offset origin, {
    required double fontSize,
    String? fontFamily,
    required Color color,
    required double opacity,
    double maxWidth = double.infinity,
    Rect? centerIn,
  }) {
    final tp = TextMetrics.layout(
      text: text,
      fontSize: fontSize,
      fontFamily: fontFamily,
      maxWidth: maxWidth,
      textAlign: centerIn == null ? TextAlign.start : TextAlign.center,
    );
    try {
      final top = centerIn == null
          ? origin.dy
          : centerIn.top + (centerIn.height - tp.height) / 2;
      final left = centerIn == null
          ? origin.dx
          : centerIn.left + (centerIn.width - tp.width) / 2;
      out.write(
        '<text font-family="${_esc(TextMetrics.resolveFontFamily(fontFamily))}, '
        'sans-serif" font-size="${_n(fontSize)}" fill="${_hex(color)}" '
        'fill-opacity="${_n(opacity)}" xml:space="preserve">',
      );
      final lines = tp.computeLineMetrics();
      var offset = 0;
      for (final line in lines) {
        if (offset >= text.length) break;
        var end = tp.getLineBoundary(TextPosition(offset: offset)).end;
        if (end <= offset) end = offset + 1;
        final content = text.substring(offset, end).replaceAll('\n', '');
        offset = end;
        out.write(
          '<tspan x="${_n(left + line.left)}" y="${_n(top + line.baseline)}">'
          '${_esc(content)}</tspan>',
        );
      }
      out.write('</text>');
    } finally {
      tp.dispose();
    }
  }

  /// Samples [path] into `M…L…` contours. Closed contours get `Z` unless
  /// [open] (strokes and hatch lines should not be re-closed).
  static String _d(Path path, {bool open = false}) {
    final d = StringBuffer();
    for (final metric in path.computeMetrics()) {
      final n = math.max(1, (metric.length / _step).ceil());
      for (var i = 0; i <= n; i++) {
        final t = metric.getTangentForOffset(
          i == n ? metric.length : i * _step,
        );
        if (t == null) continue;
        d.write(
          '${i == 0 ? 'M' : 'L'}${_n(t.position.dx)} ${_n(t.position.dy)}',
        );
      }
      if (metric.isClosed && !open) d.write('Z');
    }
    return d.toString();
  }

  static String _n(double v) {
    if (!v.isFinite) return '0';
    final s = v.toStringAsFixed(2);
    return s.contains('.') ? s.replaceFirst(RegExp(r'\.?0+$'), '') : s;
  }

  static String _hex(Color c) {
    String h(double v) => (v * 255).round().toRadixString(16).padLeft(2, '0');
    return '#${h(c.r)}${h(c.g)}${h(c.b)}';
  }

  static String _esc(String s) => s
      .replaceAll('&', '&amp;')
      .replaceAll('<', '&lt;')
      .replaceAll('>', '&gt;')
      .replaceAll('"', '&quot;')
      .replaceAll("'", '&apos;');
}
