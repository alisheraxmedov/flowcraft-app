import 'dart:ui';

import 'package:flutter/material.dart';

import 'package:flowcraft/core/theme/app_radius.dart';
import 'package:flowcraft/core/theme/fc_tokens.dart';

/// A floating frosted-glass surface: translucent fill, 1px border, a lit top
/// hairline, shadow, and a backdrop blur + saturation boost scoped to its own
/// bounds (the [ClipRRect] confines the [BackdropFilter]).
///
/// The shadow sits OUTSIDE the clip, otherwise it would be cut off.
///
/// Sized like a CSS `box-sizing: border-box` box: [height] is the OUTER height
/// and [padding] sits inside the 1px border, so callers use the mockup's
/// numbers as written.
class GlassIsland extends StatelessWidget {
  const GlassIsland({
    super.key,
    required this.child,
    this.radius = AppRadius.island,
    this.strong = false,
    this.padding = EdgeInsets.zero,
    this.height,
  });

  final Widget child;
  final double radius;

  /// Use the denser fill (popovers/menus that sit over busy canvas content).
  final bool strong;
  final EdgeInsetsGeometry padding;

  /// Outer height including the border; null sizes to the content.
  final double? height;

  /// Saturate x1.8, the mockup's `saturate(180%)`.
  static const _saturate = ColorFilter.matrix(<double>[
    1.7154, -0.6444, -0.0710, 0, 0, //
    -0.2846, 1.3556, -0.0710, 0, 0, //
    -0.2846, -0.6444, 1.9290, 0, 0, //
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final t = context.fc;
    final r = BorderRadius.circular(radius);
    final fill = strong ? t.glassStrong : t.glass;
    // ponytail: blurSigma == 0 is the kill switch for Windows/Linux where
    // BackdropFilter can jank; it paints an opaque blend instead. Wire it to
    // a platform default / setting if profiling shows the need.
    final blurred = t.blurSigma > 0;
    Widget body = DecoratedBox(
      decoration: BoxDecoration(
        color: blurred ? fill : Color.alphaBlend(fill, t.bg),
        borderRadius: r,
        border: Border.all(color: t.glassBorder),
      ),
      position: DecorationPosition.background,
      child: DecoratedBox(
        position: DecorationPosition.foreground,
        decoration: BoxDecoration(
          borderRadius: r,
          border: Border(top: BorderSide(color: t.hi, width: 0.5)),
        ),
        child: Padding(
          padding: padding.add(const EdgeInsets.all(1)), // the border
          child: child,
        ),
      ),
    );
    if (blurred) {
      body = BackdropFilter(
        filter: ImageFilter.compose(
          outer: _saturate,
          inner: ImageFilter.blur(
            sigmaX: t.blurSigma,
            sigmaY: t.blurSigma,
            tileMode: TileMode.clamp,
          ),
        ),
        child: body,
      );
    }
    return SizedBox(
      height: height,
      child: DecoratedBox(
        decoration: BoxDecoration(borderRadius: r, boxShadow: t.shadow),
        child: ClipRRect(borderRadius: r, child: body),
      ),
    );
  }
}
