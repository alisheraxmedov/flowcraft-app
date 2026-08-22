import 'package:flutter/painting.dart';

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

  /// Lays out [text] the way the painter draws it. The caller owns the
  /// returned painter.
  ///
  /// [color] affects painting only, never metrics — which is why [measure]
  /// can cache without it in the key.
  static TextPainter layout({
    required String text,
    required double fontSize,
    String? fontFamily,
    Color color = const Color(0xFF000000),
  }) {
    return TextPainter(
      text: TextSpan(
        text: text,
        style: TextStyle(
          color: color,
          fontSize: fontSize,
          fontFamily: fontFamily,
        ),
      ),
      textDirection: TextDirection.ltr,
    )..layout();
  }

  /// Laid-out size of [text], cached by (text, fontSize, fontFamily).
  static Size measure({
    required String text,
    required double fontSize,
    String? fontFamily,
  }) {
    final key = '$fontSize|${fontFamily ?? ''}|$text';
    final hit = _sizes[key];
    if (hit != null) return hit;

    final painter = layout(
      text: text,
      fontSize: fontSize,
      fontFamily: fontFamily,
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
