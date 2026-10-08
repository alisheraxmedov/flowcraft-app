import 'package:flowcraft/core/theme/app_typography.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('chrome styles use Geist, scene constants unchanged', () {
    for (final s in [
      AppTypography.displayLg,
      AppTypography.headlineMd,
      AppTypography.bodyBase,
      AppTypography.bodySm,
      AppTypography.caption,
      AppTypography.uiLabel,
      AppTypography.uiTitle,
    ]) {
      expect(s.fontFamily, 'Geist');
    }
    for (final s in [
      AppTypography.labelMono,
      AppTypography.mono12,
      AppTypography.mono11,
    ]) {
      expect(s.fontFamily, 'Geist Mono');
    }
    expect(AppTypography.interFamily, 'Inter');
    expect(AppTypography.monoFamily, 'JetBrains Mono');
  });
}
