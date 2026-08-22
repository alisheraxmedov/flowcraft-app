import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/models/sketch_element.dart';

/// Regression coverage for [SketchText.bounds].
///
/// It used to approximate its width as `text.length * fontSize * 0.55` while
/// the painter drew real, `TextPainter`-measured glyphs at the same origin.
/// Any click on a glyph past the guess missed the element, which is how the
/// text tool ended up creating a second, empty text box on top of the first.
void main() {
  group('SketchText.bounds', () {
    Size measured(String text, double fontSize, {String? fontFamily}) {
      final painter = TextPainter(
        text: TextSpan(
          text: text,
          style: TextStyle(fontSize: fontSize, fontFamily: fontFamily),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      final size = painter.size;
      painter.dispose();
      return size;
    }

    test('matches what TextPainter actually lays out', () {
      final t = SketchText.create(
        position: const Offset(12, 34),
        text: 'Hello world',
        fontSize: 16,
      );
      expect(t.bounds.topLeft, const Offset(12, 34));
      expect(t.bounds.size, measured('Hello world', 16));
    });

    test('tracks fontSize and fontFamily', () {
      final big = SketchText.create(
        position: Offset.zero,
        text: 'Hello',
        fontSize: 32,
      );
      expect(big.bounds.size, measured('Hello', 32));

      final mono = SketchText.create(
        position: Offset.zero,
        text: 'Hello',
        fontSize: 16,
        fontFamily: 'JetBrains Mono',
      );
      expect(mono.bounds.size, measured('Hello', 16, fontFamily: 'JetBrains Mono'));
    });

    test('is wider than the approximation it replaced', () {
      final t = SketchText.create(
        position: Offset.zero,
        text: 'Hello',
        fontSize: 16,
      );
      // Old guess: max(fontSize, length * fontSize * 0.55) = 44px.
      expect(t.bounds.width, greaterThan(5 * 16 * 0.55));
    });

    test('shifts with the element', () {
      final t = SketchText.create(
        position: const Offset(5, 5),
        text: 'Hello',
        fontSize: 16,
      );
      final moved = t.translate(const Offset(10, 20));
      expect(moved.bounds, t.bounds.shift(const Offset(10, 20)));
    });
  });
}
