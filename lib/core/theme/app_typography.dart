import 'package:flutter/painting.dart' show FontWeight, TextStyle;
import 'package:google_fonts/google_fonts.dart';

/// "Kinetic Blueprint" typography tokens — single source of truth for text
/// styles used across the app chrome.
///
/// Colors are intentionally NOT baked in here; callers apply
/// `.copyWith(color: ...)` from `AppColors` as needed so these styles stay
/// reusable across light/dark chrome.
class AppTypography {
  AppTypography._();

  static TextStyle get displayLg => GoogleFonts.inter(
        fontSize: 48,
        fontWeight: FontWeight.w700,
        height: 1.2,
        letterSpacing: -0.02 * 48,
      );

  static TextStyle get headlineMd => GoogleFonts.inter(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        height: 1.4,
        letterSpacing: -0.01 * 24,
      );

  static TextStyle get bodyBase => GoogleFonts.inter(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        height: 1.6,
        letterSpacing: 0,
      );

  static TextStyle get labelMono => GoogleFonts.jetBrainsMono(
        fontSize: 12,
        fontWeight: FontWeight.w500,
        height: 1.2,
        letterSpacing: 0.05 * 12,
      );

  static TextStyle get caption => GoogleFonts.inter(
        fontSize: 11,
        fontWeight: FontWeight.w500,
        height: 1.2,
        letterSpacing: 0.01 * 11,
      );
}
