import 'package:flutter/painting.dart' show FontWeight, TextStyle;

/// "Kinetic Blueprint" typography tokens — single source of truth for text
/// styles used across the app chrome.
///
/// Colors are intentionally NOT baked in here; callers apply
/// `.copyWith(color: ...)` from `AppColors` as needed so these styles stay
/// reusable across light/dark chrome.
///
/// The two faces are **bundled as assets**, not fetched through
/// `google_fonts`. That package downloads the face from Google's CDN on first
/// run and caches it, which would make a local-first, offline app reach the
/// network — and fall back to a system face when it can't. Bundling costs a
/// couple of MB and makes the offline guarantee real.
///
/// The family names below must stay in sync with `pubspec.yaml`'s `fonts:`
/// section *and* with the values the properties panel's font-family dropdown
/// writes onto a `SketchText` ("Inter" / "JetBrains Mono"), since those
/// strings are handed straight to `TextStyle.fontFamily` by the painter.
class AppTypography {
  AppTypography._();

  /// App-chrome face (Geist). Chrome styles below use this; canvas text keeps
  /// [interFamily]/[monoFamily] so existing scenes render unchanged.
  static const String geistFamily = 'Geist';

  /// App-chrome monospace face (Geist Mono).
  static const String geistMonoFamily = 'Geist Mono';

  /// Default face for canvas text (scene data — do not repoint at chrome), and the default face for canvas text.
  static const String interFamily = 'Inter';

  /// Canvas monospace face (scene data).
  static const String monoFamily = 'JetBrains Mono';

  static const TextStyle displayLg = TextStyle(
    fontFamily: geistFamily,
    fontSize: 48,
    fontWeight: FontWeight.w700,
    height: 1.2,
    letterSpacing: -0.02 * 48,
  );

  static const TextStyle headlineMd = TextStyle(
    fontFamily: geistFamily,
    fontSize: 24,
    fontWeight: FontWeight.w600,
    height: 1.4,
    letterSpacing: -0.01 * 24,
  );

  static const TextStyle bodyBase = TextStyle(
    fontFamily: geistFamily,
    fontSize: 14,
    fontWeight: FontWeight.w400,
    height: 1.6,
    letterSpacing: 0,
  );

  /// Dense chrome text — sidebar rows, pill buttons, inline fields. Same
  /// face and metrics as [bodyBase]; 14px is a shade too loud for controls
  /// packed into a toolbar, and hand-rolling `bodyBase.copyWith(fontSize:
  /// 13)` at each call site is how that size drifts.
  static const TextStyle bodySm = TextStyle(
    fontFamily: geistFamily,
    fontSize: 13,
    fontWeight: FontWeight.w400,
    height: 1.6,
    letterSpacing: 0,
  );

  static const TextStyle labelMono = TextStyle(
    fontFamily: geistMonoFamily,
    fontSize: 12,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: 0.05 * 12,
  );

  static const TextStyle caption = TextStyle(
    fontFamily: geistFamily,
    fontSize: 11,
    fontWeight: FontWeight.w500,
    height: 1.2,
    letterSpacing: 0.01 * 11,
  );

  /// Small-caps-style section label (letter-spaced, semibold).
  static const TextStyle uiLabel = TextStyle(
    fontFamily: geistFamily,
    fontSize: 11,
    fontWeight: FontWeight.w600,
    height: 1.2,
    letterSpacing: 0.55,
  );

  /// Panel / card titles.
  static const TextStyle uiTitle = TextStyle(
    fontFamily: geistFamily,
    fontSize: 14,
    fontWeight: FontWeight.w600,
    height: 1.3,
    letterSpacing: 0,
  );

  static const TextStyle mono12 = TextStyle(
    fontFamily: geistMonoFamily,
    fontSize: 12,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0,
  );

  static const TextStyle mono11 = TextStyle(
    fontFamily: geistMonoFamily,
    fontSize: 11,
    fontWeight: FontWeight.w400,
    height: 1.4,
    letterSpacing: 0,
  );
}
