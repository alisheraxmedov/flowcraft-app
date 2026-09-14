import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/core/domain/text_metrics.dart';
import 'package:flowcraft/core/theme/app_typography.dart';

void main() {
  group('font family', () {
    test('a null family resolves to the documented canvas default (Inter)', () {
      expect(TextMetrics.defaultFontFamily, AppTypography.interFamily);
      expect(TextMetrics.resolveFontFamily(null), AppTypography.interFamily);
      expect(TextMetrics.resolveFontFamily('JetBrains Mono'), 'JetBrains Mono');
    });

    test('layout puts the resolved family on the span', () {
      final tp = TextMetrics.layout(text: 'hi', fontSize: 16);
      addTearDown(tp.dispose);
      expect(
        (tp.text as TextSpan).style?.fontFamily,
        AppTypography.interFamily,
      );

      final mono = TextMetrics.layout(
        text: 'hi',
        fontSize: 16,
        fontFamily: 'JetBrains Mono',
      );
      addTearDown(mono.dispose);
      expect((mono.text as TextSpan).style?.fontFamily, 'JetBrains Mono');
    });
  });

  group('measure and layout agree', () {
    test('the cached size is the painted size', () {
      final tp = TextMetrics.layout(text: 'agree', fontSize: 20);
      addTearDown(tp.dispose);
      expect(TextMetrics.measure(text: 'agree', fontSize: 20), tp.size);
      // Second read is the cached one; must be the same answer.
      expect(TextMetrics.measure(text: 'agree', fontSize: 20), tp.size);
    });

    test('maxWidth wraps in both', () {
      final wrapped = TextMetrics.layout(
        text: 'wrap wrap wrap wrap wrap wrap',
        fontSize: 16,
        maxWidth: 60,
      );
      addTearDown(wrapped.dispose);
      expect(
        TextMetrics.measure(
          text: 'wrap wrap wrap wrap wrap wrap',
          fontSize: 16,
          maxWidth: 60,
        ),
        wrapped.size,
      );
      expect(wrapped.width, lessThanOrEqualTo(60));
      expect(wrapped.height, greaterThan(16));
    });

    test('textAlign does not change the measured size', () {
      final start = TextMetrics.layout(text: 'centre', fontSize: 16);
      final centre = TextMetrics.layout(
        text: 'centre',
        fontSize: 16,
        textAlign: TextAlign.center,
      );
      addTearDown(start.dispose);
      addTearDown(centre.dispose);
      expect(centre.size, start.size);
      expect(centre.textAlign, TextAlign.center);
    });
  });
}
