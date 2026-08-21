import 'package:flutter/material.dart';

import 'app_colors.dart';
import 'app_typography.dart';

/// Builds the app's [ThemeData] for the Material widgets that fall back to
/// framework defaults (dialogs, dropdowns, default text styles, etc).
///
/// The hand-styled chrome (top bar, tool rail, properties panel, MCP card,
/// canvas grid) reads [AppColors] directly rather than `Theme.of(context)`
/// — the source "Kinetic Blueprint" design is deliberately dark-first, so
/// that custom chrome keeps its exact tokens regardless of the light/dark
/// toggle. [dark] mirrors [AppColors] 1:1 for the parts of [ColorScheme]
/// that still have a non-deprecated home there; [light] derives a
/// consistent light counterpart via [ColorScheme.fromSeed] since the source
/// design has no light palette to draw from.
class AppTheme {
  AppTheme._();

  static ThemeData dark() {
    const colorScheme = ColorScheme.dark(
      brightness: Brightness.dark,
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      tertiary: AppColors.tertiary,
      onTertiary: AppColors.onTertiary,
      tertiaryContainer: AppColors.tertiaryContainer,
      onTertiaryContainer: AppColors.onTertiaryContainer,
      error: AppColors.error,
      onError: AppColors.onError,
      errorContainer: AppColors.errorContainer,
      onErrorContainer: AppColors.onErrorContainer,
      surface: AppColors.surface,
      onSurface: AppColors.onSurface,
      surfaceDim: AppColors.surfaceDim,
      surfaceBright: AppColors.surfaceBright,
      surfaceContainerLowest: AppColors.surfaceContainerLowest,
      surfaceContainerLow: AppColors.surfaceContainerLow,
      surfaceContainer: AppColors.surfaceContainer,
      surfaceContainerHigh: AppColors.surfaceContainerHigh,
      surfaceContainerHighest: AppColors.surfaceContainerHighest,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
      inverseSurface: AppColors.inverseSurface,
      onInverseSurface: AppColors.inverseOnSurface,
      inversePrimary: AppColors.inversePrimary,
      surfaceTint: AppColors.surfaceTint,
    );
    return _build(colorScheme);
  }

  static ThemeData light() {
    final colorScheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    );
    return _build(colorScheme);
  }

  static ThemeData _build(ColorScheme colorScheme) {
    final onSurface = colorScheme.onSurface;
    final textTheme = TextTheme(
      displayLarge: AppTypography.displayLg.copyWith(color: onSurface),
      headlineMedium: AppTypography.headlineMd.copyWith(color: onSurface),
      bodyLarge: AppTypography.bodyBase.copyWith(color: onSurface),
      bodyMedium: AppTypography.bodyBase.copyWith(color: onSurface),
      labelMedium: AppTypography.labelMono.copyWith(color: onSurface),
      labelSmall: AppTypography.caption.copyWith(color: onSurface),
    );

    return ThemeData(
      useMaterial3: true,
      colorScheme: colorScheme,
      textTheme: textTheme,
      scaffoldBackgroundColor: colorScheme.surface,
    );
  }
}
