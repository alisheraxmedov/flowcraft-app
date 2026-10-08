import 'package:flutter/material.dart';

import 'app_radius.dart';
import 'app_typography.dart';
import 'fc_tokens.dart';

/// Builds the app's [ThemeData] from the Glass Canvas [FcTokens].
///
/// Custom chrome reads `context.fc` directly; Material widgets (dialogs,
/// menus, sliders, inputs...) get the same palette through a hand-built
/// [ColorScheme] plus the component themes below. Menus and dialogs use
/// opaque *blended* glass (glassStrong over bg) rather than a real
/// BackdropFilter: `MenuAnchor` and `Dialog` can't host a backdrop blur
/// cleanly, and only the small floating islands pay for one.
class AppTheme {
  AppTheme._();

  static ThemeData light() => _build(FcTokens.light, Brightness.light);

  static ThemeData dark() => _build(FcTokens.dark, Brightness.dark);

  static ThemeData _build(FcTokens t, Brightness brightness) {
    Color blend(Color c) => Color.alphaBlend(c, t.bg);
    final surface2 = blend(t.surface2);
    final scheme = ColorScheme(
      brightness: brightness,
      primary: t.accent,
      onPrimary: t.onAccent,
      primaryContainer: blend(t.accentTint),
      onPrimaryContainer: t.accentText,
      secondary: t.accent,
      onSecondary: t.onAccent,
      secondaryContainer: blend(t.accentTint),
      onSecondaryContainer: t.accentText,
      tertiary: t.ok,
      onTertiary: t.onAccent,
      error: t.danger,
      onError: t.onDanger,
      errorContainer: blend(t.dangerTint),
      onErrorContainer: t.danger,
      surface: t.bg,
      onSurface: t.text,
      onSurfaceVariant: t.muted,
      outline: t.muted,
      outlineVariant: blend(t.glassBorder),
      surfaceContainerLowest: t.bg,
      surfaceContainerLow: surface2,
      surfaceContainer: Color.alphaBlend(t.surface2, surface2),
      surfaceContainerHigh: Color.alphaBlend(t.surface2, blend(t.glassStrong)),
      surfaceContainerHighest: t.raised,
      inverseSurface: t.tooltipBg,
      onInverseSurface: t.tooltipFg,
      inversePrimary: t.accentText,
      shadow: const Color(0xFF000000),
    );

    final overlay = Color.alphaBlend(t.glassStrong, t.bg);
    TextStyle geist(double size, FontWeight w, [Color? color]) => TextStyle(
      fontFamily: AppTypography.geistFamily,
      fontSize: size,
      fontWeight: w,
      color: color ?? t.text,
    );
    final textTheme = TextTheme(
      displayLarge: geist(32, FontWeight.w600),
      headlineMedium: geist(20, FontWeight.w600),
      titleMedium: geist(14, FontWeight.w600),
      bodyLarge: geist(14, FontWeight.w400),
      bodyMedium: geist(13, FontWeight.w400),
      bodySmall: geist(12, FontWeight.w400, t.muted),
      labelLarge: geist(13, FontWeight.w600),
      labelMedium: geist(12, FontWeight.w500),
      labelSmall: geist(11, FontWeight.w600, t.muted),
    );
    RoundedRectangleBorder shape(double r) =>
        RoundedRectangleBorder(borderRadius: BorderRadius.circular(r));

    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: textTheme,
      fontFamily: AppTypography.geistFamily,
      scaffoldBackgroundColor: t.bg,
      extensions: [t],
      dialogTheme: DialogThemeData(
        backgroundColor: overlay,
        surfaceTintColor: Colors.transparent,
        shape: shape(AppRadius.island),
      ),
      menuTheme: MenuThemeData(
        style: MenuStyle(
          backgroundColor: WidgetStatePropertyAll(overlay),
          surfaceTintColor: const WidgetStatePropertyAll(Colors.transparent),
          shape: WidgetStatePropertyAll(shape(AppRadius.menu)),
          padding: const WidgetStatePropertyAll(EdgeInsets.all(6)),
        ),
      ),
      menuButtonTheme: MenuButtonThemeData(
        style: ButtonStyle(
          minimumSize: const WidgetStatePropertyAll(Size(0, 30)),
          shape: WidgetStatePropertyAll(shape(AppRadius.input)),
          textStyle: WidgetStatePropertyAll(geist(13, FontWeight.w400)),
        ),
      ),
      tooltipTheme: TooltipThemeData(
        constraints: const BoxConstraints(minHeight: 28),
        padding: const EdgeInsets.symmetric(horizontal: 10),
        decoration: BoxDecoration(
          color: t.tooltipBg,
          borderRadius: BorderRadius.circular(AppRadius.input),
        ),
        textStyle: geist(12, FontWeight.w500, t.tooltipFg),
      ),
      sliderTheme: SliderThemeData(
        activeTrackColor: t.accent,
        inactiveTrackColor: t.surface2,
        thumbColor: t.accent,
        trackHeight: 4,
        // Mockup: a native range input - thin track spanning the whole
        // control, small thumb, no hover halo and no `divisions` tick dots.
        trackShape: const _FullWidthTrack(),
        tickMarkShape: SliderTickMarkShape.noTickMark,
        overlayShape: SliderComponentShape.noOverlay,
        thumbShape: const RoundSliderThumbShape(
          enabledThumbRadius: 7,
          elevation: 0,
          pressedElevation: 0,
        ),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: const WidgetStatePropertyAll(Colors.white),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.accent : surface2,
        ),
        trackOutlineColor: const WidgetStatePropertyAll(Colors.transparent),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surface2,
        isDense: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.input),
          borderSide: BorderSide.none,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: t.accent,
          foregroundColor: t.onAccent,
          minimumSize: const Size(0, 34),
          shape: shape(AppRadius.button),
          textStyle: geist(13, FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          backgroundColor: t.surface2,
          foregroundColor: t.text,
          shape: shape(AppRadius.button),
          textStyle: geist(13, FontWeight.w500),
        ),
      ),
      dividerTheme: DividerThemeData(color: t.glassBorder, space: 1),
    );
  }
}

/// Rounded slider track with none of the stock horizontal inset, so it spans
/// the control's full width like the mockup's range input.
class _FullWidthTrack extends RoundedRectSliderTrackShape {
  const _FullWidthTrack();

  @override
  Rect getPreferredRect({
    required RenderBox parentBox,
    Offset offset = Offset.zero,
    required SliderThemeData sliderTheme,
    bool isEnabled = false,
    bool isDiscrete = false,
  }) {
    final h = sliderTheme.trackHeight ?? 4;
    return Rect.fromLTWH(
      offset.dx,
      offset.dy + (parentBox.size.height - h) / 2,
      parentBox.size.width,
      h,
    );
  }
}
