import 'package:flowcraft/core/theme/app_theme.dart';
import 'package:flowcraft/core/theme/fc_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('light tokens match the mockup', () {
    final t = AppTheme.light().extension<FcTokens>()!;
    expect(t.bg, const Color(0xFFEEF0F4));
    expect(t.accent, const Color(0xFF0A66D6));
    expect(t.text, const Color(0xFF1C1C1E));
  });

  test('dark tokens match the mockup', () {
    final t = AppTheme.dark().extension<FcTokens>()!;
    expect(t.bg, const Color(0xFF121214));
    expect(t.accent, const Color(0xFF5AA2FF));
    expect(t.text, const Color(0xFFF5F5F7));
  });

  test('ColorScheme is built from tokens; text theme is Geist', () {
    for (final (theme, tokens) in [
      (AppTheme.light(), FcTokens.light),
      (AppTheme.dark(), FcTokens.dark),
    ]) {
      expect(theme.colorScheme.primary, tokens.accent);
      expect(theme.colorScheme.surface, tokens.bg);
      expect(theme.textTheme.bodyMedium!.fontFamily, 'Geist');
    }
  });
}
