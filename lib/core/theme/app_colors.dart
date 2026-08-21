import 'package:flutter/painting.dart' show Color;

/// "Kinetic Blueprint" design-system color tokens.
///
/// This is the single source of truth for chrome colors (top bar, tool
/// rail, panels, cards, canvas grid). Values are lifted verbatim from the
/// finalized design spec — do not hand-pick alternatives.
///
/// Deliberately dark-first (the source mockups force dark mode): these
/// constants back both [AppColors]-driven custom chrome widgets (which
/// always render the Kinetic Blueprint look) and `AppTheme.dark()`'s
/// [ColorScheme], while `AppTheme.light()` derives a seed-based light
/// counterpart for standard Material widgets and the app's light/dark
/// toggle — see `app_theme.dart`.
///
/// Not touched by this token set: the sketch canvas's own hand-drawn
/// ("rough.js"-style) rendering and the user-facing stroke/fill palettes
/// in the toolbar — those are the app's core drawing identity, not chrome.
class AppColors {
  AppColors._();

  static const Color surface = Color(0xFF0B1326);
  static const Color surfaceDim = Color(0xFF0B1326);
  static const Color surfaceBright = Color(0xFF31394D);
  static const Color surfaceContainerLowest = Color(0xFF060E20);
  static const Color surfaceContainerLow = Color(0xFF131B2E);
  static const Color surfaceContainer = Color(0xFF171F33);
  static const Color surfaceContainerHigh = Color(0xFF222A3D);
  static const Color surfaceContainerHighest = Color(0xFF2D3449);
  static const Color onSurface = Color(0xFFDAE2FD);
  static const Color onSurfaceVariant = Color(0xFFC2C6D6);
  static const Color inverseSurface = Color(0xFFDAE2FD);
  static const Color inverseOnSurface = Color(0xFF283044);
  static const Color outline = Color(0xFF8C909F);
  static const Color outlineVariant = Color(0xFF424754);
  static const Color surfaceTint = Color(0xFFADC6FF);
  static const Color primary = Color(0xFFADC6FF);
  static const Color onPrimary = Color(0xFF002E6A);
  static const Color primaryContainer = Color(0xFF4D8EFF);
  static const Color onPrimaryContainer = Color(0xFF00285D);
  static const Color inversePrimary = Color(0xFF005AC2);
  static const Color secondary = Color(0xFFC0C1FF);
  static const Color onSecondary = Color(0xFF1000A9);
  static const Color secondaryContainer = Color(0xFF3131C0);
  static const Color onSecondaryContainer = Color(0xFFB0B2FF);
  static const Color tertiary = Color(0xFFFFB786);
  static const Color onTertiary = Color(0xFF502400);
  static const Color tertiaryContainer = Color(0xFFDF7412);
  static const Color onTertiaryContainer = Color(0xFF461F00);
  static const Color error = Color(0xFFFFB4AB);
  static const Color onError = Color(0xFF690005);
  static const Color errorContainer = Color(0xFF93000A);
  static const Color onErrorContainer = Color(0xFFFFDAD6);
  static const Color background = Color(0xFF0B1326);
  static const Color onBackground = Color(0xFFDAE2FD);
  static const Color surfaceVariant = Color(0xFF2D3449);
}
