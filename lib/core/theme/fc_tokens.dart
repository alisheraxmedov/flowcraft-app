import 'package:flutter/material.dart';

/// "Glass Canvas" design tokens, verbatim from the mockups' `.fc` (light) and
/// `.fc.dark` CSS variables. Custom chrome reads them via `context.fc`;
/// Material widgets get the same values through the [ColorScheme] that
/// `AppTheme` builds from them.
@immutable
class FcTokens extends ThemeExtension<FcTokens> {
  const FcTokens({
    required this.bg,
    required this.glass,
    required this.glassStrong,
    required this.glassBorder,
    required this.hi,
    required this.surface2,
    required this.raised,
    required this.text,
    required this.muted,
    required this.accent,
    required this.onAccent,
    required this.accentTint,
    required this.accentText,
    required this.danger,
    required this.onDanger,
    required this.dangerTint,
    required this.ok,
    required this.ink,
    required this.swatchInk,
    required this.dot,
    required this.shadow,
    required this.raisedShadow,
    required this.blurSigma,
    required this.tooltipBg,
    required this.tooltipFg,
  });

  final Color bg;
  final Color glass;
  final Color glassStrong;
  final Color glassBorder;

  /// Inner top hairline (0.5px) that gives islands their lit edge.
  final Color hi;
  final Color surface2;
  final Color raised;
  final Color text;
  final Color muted;
  final Color accent;
  final Color onAccent;
  final Color accentTint;
  final Color accentText;
  final Color danger;
  final Color onDanger;
  final Color dangerTint;
  final Color ok;
  final Color ink;
  final Color swatchInk;

  /// Canvas grid dot.
  final Color dot;
  final List<BoxShadow> shadow;

  /// Pressed/selected button lift (segmented thumb, active icon button).
  final List<BoxShadow> raisedShadow;

  /// Backdrop blur sigma for glass islands (CSS blur 24px ~ 2 sigma = 12).
  /// 0 disables the blur and paints opaque glass instead.
  final double blurSigma;
  final Color tooltipBg;
  final Color tooltipFg;

  static const _raisedShadow = [
    BoxShadow(color: Color(0x24000000), blurRadius: 3, offset: Offset(0, 1)),
    BoxShadow(color: Color(0x0D000000), spreadRadius: 0.5),
  ];

  static const light = FcTokens(
    bg: Color(0xFFEEF0F4),
    glass: Color(0xBDFFFFFF),
    glassStrong: Color(0xEBFFFFFF),
    glassBorder: Color(0x14000000),
    hi: Color(0xE6FFFFFF),
    surface2: Color(0x123C3C43),
    raised: Color(0xFFFFFFFF),
    text: Color(0xFF1C1C1E),
    muted: Color(0xFF5E5E63),
    accent: Color(0xFF0A66D6),
    onAccent: Color(0xFFFFFFFF),
    accentTint: Color(0x1F0A66D6),
    accentText: Color(0xFF0A5FC4),
    danger: Color(0xFFC4001A),
    onDanger: Color(0xFFFFFFFF),
    dangerTint: Color(0x14D70015),
    ok: Color(0xFF248A3D),
    ink: Color(0xFF1E1E1E),
    swatchInk: Color(0xFF1E1E1E),
    dot: Color(0x333C3C43),
    shadow: [
      BoxShadow(
        color: Color(0x1A000000),
        blurRadius: 30,
        offset: Offset(0, 10),
      ),
      BoxShadow(color: Color(0x0F000000), blurRadius: 3, offset: Offset(0, 1)),
    ],
    raisedShadow: _raisedShadow,
    blurSigma: 12,
    tooltipBg: Color(0xFF2A2A2E),
    tooltipFg: Color(0xFFF5F5F7),
  );

  static const dark = FcTokens(
    bg: Color(0xFF121214),
    glass: Color(0xA826262A),
    glassStrong: Color(0xE626262A),
    glassBorder: Color(0x1AFFFFFF),
    hi: Color(0x14FFFFFF),
    surface2: Color(0x12FFFFFF),
    raised: Color(0xFF3A3A3F),
    text: Color(0xFFF5F5F7),
    muted: Color(0xFFA8A8AE),
    accent: Color(0xFF5AA2FF),
    onAccent: Color(0xFF0B1A2E),
    accentTint: Color(0x295AA2FF),
    accentText: Color(0xFF84BBFF),
    danger: Color(0xFFFF6961),
    onDanger: Color(0xFF2B0B09),
    dangerTint: Color(0x1FFF6961),
    ok: Color(0xFF30D158),
    ink: Color(0xFFF5F5F7),
    swatchInk: Color(0xFFDAE2FD),
    dot: Color(0x1AEBEBF5),
    shadow: [
      BoxShadow(
        color: Color(0x80000000),
        blurRadius: 36,
        offset: Offset(0, 12),
      ),
    ],
    raisedShadow: _raisedShadow,
    blurSigma: 12,
    tooltipBg: Color(0xFF2A2A2E),
    tooltipFg: Color(0xFFF5F5F7),
  );

  @override
  FcTokens copyWith({double? blurSigma}) => FcTokens(
    bg: bg,
    glass: glass,
    glassStrong: glassStrong,
    glassBorder: glassBorder,
    hi: hi,
    surface2: surface2,
    raised: raised,
    text: text,
    muted: muted,
    accent: accent,
    onAccent: onAccent,
    accentTint: accentTint,
    accentText: accentText,
    danger: danger,
    onDanger: onDanger,
    dangerTint: dangerTint,
    ok: ok,
    ink: ink,
    swatchInk: swatchInk,
    dot: dot,
    shadow: shadow,
    raisedShadow: raisedShadow,
    blurSigma: blurSigma ?? this.blurSigma,
    tooltipBg: tooltipBg,
    tooltipFg: tooltipFg,
  );

  /// Themes switch instantly (no animated theme crossfade of tokens), so
  /// a step at the midpoint is enough.
  @override
  FcTokens lerp(FcTokens? other, double t) =>
      other == null || t < 0.5 ? this : other;
}

extension FcContext on BuildContext {
  /// Falls back to the brightness-matching tokens under a bare [ThemeData]
  /// (widget tests, embedders) instead of throwing.
  FcTokens get fc {
    final theme = Theme.of(this);
    return theme.extension<FcTokens>() ??
        (theme.brightness == Brightness.dark ? FcTokens.dark : FcTokens.light);
  }
}
