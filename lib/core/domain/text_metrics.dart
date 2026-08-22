import 'package:flutter/painting.dart';

import 'package:flowcraft/core/theme/app_typography.dart';

/// The single place that decides how a [SketchText]'s glyphs are laid out.
///
/// `SketchText.bounds` and `SketchPainter._drawText` both go through
/// [layout], so the box the hit test and the viewport culling reason about
/// can never drift away from the glyphs that are actually painted. They used
/// to: `bounds` guessed `text.length * fontSize * 0.55`, so clicking a
/// visible glyph past that guess missed the element entirely and the text
/// tool created a second, empty text box on top of the first one.
///
/// [measure] caches, because `bounds` is read per element per frame by both
/// hit-testing and culling — an uncached `TextPainter.layout()` on that path
/// is a real per-frame cost, not a theoretical one.
class TextMetrics {
  TextMetrics._();

  /// Cap on cached measurements. A long editing session types a great many
  /// distinct strings, so the cache evicts oldest-first rather than growing
  /// for the lifetime of the process.
  static const int maxEntries = 512;

  static final Map<String, Size> _sizes = <String, Size>{};

  /// Face used when an element carries no [SketchText.fontFamily] — Inter,
  /// the bundled chrome face `AppTypography` documents as the canvas
  /// default and the properties panel reports for a `null` family. Left to
  /// `null`, the engine picked the OS face instead (SF / Segoe / DejaVu), so
  /// the same file measured — and therefore hit-tested — differently on
  /// each platform.
  static const String defaultFontFamily = AppTypography.interFamily;

  /// The face [layout] actually uses for [fontFamily]. Anything that lays
  /// canvas text out *next to* the painter (the inline editor) should
  /// resolve through this, or its glyphs reflow against the painted ones.
  static String resolveFontFamily(String? fontFamily) =>
      fontFamily ?? defaultFontFamily;

  /// Lays out [text] the way the painter draws it. The caller owns the
  /// returned painter.
  ///
  /// [color] affects painting only, never metrics — which is why [measure]
  /// can cache without it in the key. [maxWidth] is where a sticky note's
  /// label wraps; free text passes nothing and runs as long as it likes.
  static TextPainter layout({
    required String text,
    required double fontSize,
    String? fontFamily,
    Color color = const Color(0xFF000000),
    double maxWidth = double.infinity,
    TextAlign textAlign = TextAlign.start,
  }) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontFamily: resolveFontFamily(fontFamily),
        ),
      ),
      textAlign: textAlign,
      textDirection: TextDirection.ltr,
    )..layout(maxWidth: maxWidth);
  }

  /// Laid-out size of [text], cached by (text, fontSize, fontFamily,
  /// maxWidth).
  static Size measure({
    required String text,
    required double fontSize,
    String? fontFamily,
    double maxWidth = double.infinity,
  }) {
    final key = '$fontSize|${fontFamily ?? ''}|$maxWidth|$text';
    final hit = _sizes[key];
    if (hit != null) return hit;

    final painter = layout(
      text: text,
      fontSize: fontSize,
      fontFamily: fontFamily,
      maxWidth: maxWidth,
    );
    final size = painter.size;
    painter.dispose();

    _sizes[key] = size;
    if (_sizes.length > maxEntries) {
      // Dart maps preserve insertion order — drop the oldest entry.
      _sizes.remove(_sizes.keys.first);
    }
    return size;
  }
}
