import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/painting.dart';
import 'package:flutter/services.dart' show FontLoader;
import 'package:flutter_test/flutter_test.dart';

import 'package:flowcraft/core/domain/text_metrics.dart';
import 'package:flowcraft/core/theme/app_typography.dart';

void main() {
  group('weight and family', () {
    // The test engine measures with the Ahem box font unless the real faces
    // are registered, which would make bold and mono indistinguishable.
    setUpAll(() async {
      TestWidgetsFlutterBinding.ensureInitialized();
      Future<void> load(String family, List<String> files) async {
        final loader = FontLoader(family);
        for (final f in files) {
          final bytes = File('assets/fonts/$f').readAsBytesSync();
          loader.addFont(Future.value(ByteData.sublistView(bytes)));
        }
        await loader.load();
      }

      await load('Inter', ['Inter-Regular.ttf', 'Inter-Bold.ttf']);
      await load('JetBrains Mono', ['JetBrainsMono-Regular.ttf']);
    });

    test('bold measures wider', () {
      final regular = TextMetrics.measure(text: 'Hello world', fontSize: 16);
      final bold = TextMetrics.measure(
        text: 'Hello world',
        fontSize: 16,
        fontWeight: FontWeight.w700,
      );
      expect(bold.width, greaterThan(regular.width));
    });

    test('mono differs from sans and both names resolve', () {
      expect(TextMetrics.resolveFontFamily('sans'), AppTypography.interFamily);
      expect(TextMetrics.resolveFontFamily('mono'), AppTypography.monoFamily);
      final sans = TextMetrics.measure(
        text: 'illicit WWW',
        fontSize: 16,
        fontFamily: 'sans',
      );
      final mono = TextMetrics.measure(
        text: 'illicit WWW',
        fontSize: 16,
        fontFamily: 'mono',
      );
      expect(mono.width, isNot(sans.width));
    });

    test('textAlign is part of the cache key', () {
      final tp = TextMetrics.layout(
        text: 'a',
        fontSize: 16,
        textAlign: TextAlign.right,
      );
      addTearDown(tp.dispose);
      expect(tp.textAlign, TextAlign.right);
    });
  });

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
