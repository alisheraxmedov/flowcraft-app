import 'dart:convert';
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
        if (!element.bounds.isFinite) continue;
        final rotated = element.angle != 0.0;
        if (rotated) {
          final c = element.bounds.center;
          out.write(
            '<g transform="rotate(${_n(element.angle * 180 / math.pi)} '
            '${_n(c.dx)} ${_n(c.dy)})">',
          );
        }
        await _element(out, cache, element, () => clipId++);
        if (rotated) out.write('</g>');
      }
    } finally {
      cache.dispose();
    }
    out.write('</svg>');
    return out.toString();
  }

  /// Mirrors `SketchPainter._paintElement`: fill, stroke, then extras.
  static Future<void> _element(
    StringBuffer out,
    SketchRenderCache cache,
    SketchElement element,
    int Function() nextClipId,
  ) async {
    final style = element.style;
    final badgeMark = element is SketchSticky && element.collapsed;
    final strokeColor = badgeMark ? element.inkColor : style.strokeColor;
    final strokeWidth = badgeMark
        ? StickyBubbleGeometry.glyphStrokeWidth
        : element is SketchFrame
        ? 1.0
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

    final strokeAttrs =
        'fill="none" stroke="${_hex(strokeColor)}" '
        'stroke-opacity="${_n(style.opacity)}" '
        'stroke-width="${_n(strokeWidth)}" stroke-linecap="round" '
        'stroke-linejoin="round"';
    if (element is SketchFrame) {
      final r = element.rect;
      out.write(
        '<rect x="${_n(r.left)}" y="${_n(r.top)}" width="${_n(r.width)}" '
        'height="${_n(r.height)}" $strokeAttrs/>',
      );
      if (element.name.isNotEmpty) {
        final h = TextMetrics.measure(text: element.name, fontSize: 13).height;
        _text(
          out,
          element.name,
          Offset(r.left, r.top - h - 4),
          fontSize: 13,
          color: style.strokeColor,
          opacity: style.opacity,
        );
      }
    } else {
      // Dashes are already separate contours in the cached path. Icons and
      // images have no outline to stroke.
      final d = _d(cache.strokePath(element), open: true);
      if (d.isNotEmpty) out.write('<path d="$d" $strokeAttrs/>');
    }

    if (element is SketchArrow) _heads(out, element);
    if (element is SketchIcon) await _icon(out, element);
    if (element is SketchImage) {
      final r = element.rect;
      out.write(
        '<image x="${_n(r.left)}" y="${_n(r.top)}" width="${_n(r.width)}" '
        'height="${_n(r.height)}" preserveAspectRatio="none" '
        'opacity="${_n(style.opacity)}" '
        'href="data:${_esc(element.mimeType)};base64,'
        '${base64Encode(element.bytes)}"/>',
      );
    }
    if (element is SketchEntity) _entity(out, element);
    if (element is SketchText) {
      _text(
        out,
        element.text,
        element.position,
        fontSize: element.fontSize,
        fontFamily: element.fontFamily,
        bold: element.bold,
        align: element.align,
        color: style.strokeColor,
        opacity: style.opacity,
      );
    }
    final label = switch (element) {
      SketchRectangle(:final text, :final fontSize) when text != null => (
        text,
        fontSize,
        element.fontFamily,
        element.bold,
      ),
      SketchEllipse(:final text, :final fontSize) when text != null => (
        text,
        fontSize,
        element.fontFamily,
        element.bold,
      ),
      SketchDiamond(:final text, :final fontSize) when text != null => (
        text,
        fontSize,
        element.fontFamily,
        element.bold,
      ),
      SketchTriangle(:final text, :final fontSize) when text != null => (
        text,
        fontSize,
        element.fontFamily,
        element.bold,
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
        fontFamily: label.$3,
        bold: label.$4,
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
        fontFamily: element.fontFamily,
        bold: element.bold,
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
    bool bold = false,
    TextAlign align = TextAlign.start,
    required Color color,
    required double opacity,
    double maxWidth = double.infinity,
    Rect? centerIn,
  }) {
    final tp = TextMetrics.layout(
      text: text,
      fontSize: fontSize,
      fontFamily: fontFamily,
      fontWeight: bold ? FontWeight.w700 : null,
      maxWidth: maxWidth,
      textAlign: centerIn == null ? align : TextAlign.center,
    );
    try {
      final top = centerIn == null
          ? origin.dy
          : centerIn.top + (centerIn.height - tp.height) / 2;
      final left = centerIn == null
          ? origin.dx
          : centerIn.left + (centerIn.width - tp.width) / 2;
      out.write(
        '<text ${_font(fontFamily, bold)} font-size="${_n(fontSize)}" '
        'fill="${_hex(color)}" fill-opacity="${_n(opacity)}" '
        'xml:space="preserve">',
      );
      // Anchor on the line's alignment edge so a viewer with a different
      // font width still aligns the lines the way the canvas does.
      final anchor = centerIn != null ? TextAlign.start : align;
      final lines = tp.computeLineMetrics();
      var offset = 0;
      for (final line in lines) {
        if (offset >= text.length) break;
        var end = tp.getLineBoundary(TextPosition(offset: offset)).end;
        if (end <= offset) end = offset + 1;
        final content = text.substring(offset, end).replaceAll('\n', '');
        offset = end;
        final x = switch (anchor) {
          TextAlign.center => left + line.left + line.width / 2,
          TextAlign.right || TextAlign.end => left + line.left + line.width,
          _ => left + line.left,
        };
        final anchorAttr = switch (anchor) {
          TextAlign.center => ' text-anchor="middle"',
          TextAlign.right || TextAlign.end => ' text-anchor="end"',
          _ => '',
        };
        out.write(
          '<tspan x="${_n(x)}" y="${_n(top + line.baseline)}"$anchorAttr>'
          '${_esc(content)}</tspan>',
        );
      }
      out.write('</text>');
    } finally {
      tp.dispose();
    }
  }

  /// `font-family` / `font-weight` attributes for [family] ('sans', 'mono',
  /// null or a literal face).
  static String _font(String? family, [bool bold = false]) {
    final face = TextMetrics.resolveFontFamily(family);
    final fallback = face == TextMetrics.resolveFontFamily('mono')
        ? 'monospace'
        : 'sans-serif';
    return 'font-family="${_esc(face)}, $fallback"'
        '${bold ? ' font-weight="bold"' : ''}';
  }

  /// Start and end glyphs of an arrow, from the first / last segment of its
  /// route. The filled triangle is a fill; cardinality glyphs are line work.
  static void _heads(StringBuffer out, SketchArrow a) {
    final pts = a.points;
    final style = a.style;
    void head(ArrowheadStyle h, Offset from, Offset to) {
      if (h == ArrowheadStyle.none) return;
      final d = _d(ArrowHead.pathFor(h, from, to, a.headLength), open: true);
      out.write(
        h == ArrowheadStyle.arrow
            ? '<path d="$d" fill="${_hex(style.strokeColor)}" '
                  'fill-opacity="${_n(style.opacity)}"/>'
            : '<path d="$d" fill="none" stroke="${_hex(style.strokeColor)}" '
                  'stroke-opacity="${_n(style.opacity)}" '
                  'stroke-width="${_n(style.strokeWidth)}" '
                  'stroke-linecap="round"/>',
      );
    }

    head(a.endHead, pts[pts.length - 2], pts.last);
    head(a.startHead, pts[1], pts.first);
  }

  /// Rasterises the glyph at 2x (the icon font isn't available to a viewer)
  /// and embeds it as a PNG at its painted size and place.
  static Future<void> _icon(StringBuffer out, SketchIcon icon) async {
    final side = math.min(icon.rect.width, icon.rect.height);
    if (side <= 0) return;
    final tp = SketchRenderCache.layoutIcon(
      icon.name,
      side * 2,
      icon.style.strokeColor,
    );
    final w = tp.width.ceil().clamp(1, 4096),
        h = tp.height.ceil().clamp(1, 4096);
    final recorder = PictureRecorder();
    tp.paint(Canvas(recorder), Offset.zero);
    final picture = recorder.endRecording();
    final image = await picture.toImage(w, h);
    final png = await image.toByteData(format: ImageByteFormat.png);
    image.dispose();
    picture.dispose();
    final pw = tp.width / 2, ph = tp.height / 2;
    tp.dispose();
    if (png == null) return;
    out.write(
      '<image x="${_n(icon.rect.center.dx - pw / 2)}" '
      'y="${_n(icon.rect.center.dy - ph / 2)}" width="${_n(pw)}" '
      'height="${_n(ph)}" opacity="${_n(icon.style.opacity)}" '
      'href="data:image/png;base64,'
      '${base64Encode(png.buffer.asUint8List())}"/>',
    );
  }

  /// Header and one `<text>` row per attribute, positioned from the same
  /// model numbers the painter uses (`rowHeight`/`headerHeight`).
  static void _entity(StringBuffer out, SketchEntity e) {
    const pad = SketchRenderCache.entityPad;
    final st = e.style;
    final attrs =
        'fill="${_hex(st.strokeColor)}" fill-opacity="${_n(st.opacity)}" '
        'dominant-baseline="central" font-size="${_n(e.fontSize)}"';
    out.write(
      '<text ${_font(null, true)} $attrs x="${_n(e.rect.left + pad)}" '
      'y="${_n(e.rect.top + e.headerHeight / 2)}">${_esc(e.name)}</text>',
    );
    final tagW = SketchRenderCache.entityTagWidth(e);
    for (var i = 0; i < e.attributes.length; i++) {
      final a = e.attributes[i];
      final y = _n(e.rect.top + e.headerHeight + (i + 0.5) * e.rowHeight);
      final tag = SketchRenderCache.entityTag(a);
      out.write('<text ${_font(null)} $attrs y="$y">');
      if (tag != null) {
        out.write(
          '<tspan x="${_n(e.rect.left + pad)}" ${_font('mono', true)} '
          'font-size="${_n(e.fontSize * 0.75)}">$tag</tspan>',
        );
      }
      out.write(
        '<tspan x="${_n(e.rect.left + pad + tagW)}">${_esc(a.name)}</tspan>',
      );
      if (a.type.isNotEmpty) {
        out.write(
          '<tspan x="${_n(e.rect.right - pad)}" text-anchor="end" '
          '${_font('mono')} font-size="${_n(e.fontSize * 0.85)}">'
          '${_esc(a.type)}</tspan>',
        );
      }
      out.write('</text>');
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
