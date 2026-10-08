import 'package:flutter/material.dart';

import 'package:flowcraft/core/theme/app_typography.dart';
import 'package:flowcraft/views/widgets/glass/glass_island.dart';

/// The glass card every dialog sits in, per the mockup: radius 18,
/// glass-strong fill with a real backdrop blur, 1px border, the island
/// shadow, 20px padding.
///
/// A transparent [Dialog] hosting a [GlassIsland]: `dialogTheme` can only
/// paint an opaque colour, so the blur has to come from the island. The
/// [minWidth]/[maxWidth] are OUTER widths (border included), as in CSS
/// `border-box`.
class FcDialogSurface extends StatelessWidget {
  const FcDialogSurface({
    super.key,
    required this.child,
    this.minWidth = 0,
    this.maxWidth = double.infinity,
  });

  final Widget child;
  final double minWidth;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      shadowColor: Colors.transparent,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.all(24),
      child: ConstrainedBox(
        constraints: BoxConstraints(minWidth: minWidth, maxWidth: maxWidth),
        child: GlassIsland(
          strong: true,
          padding: const EdgeInsets.all(20),
          child: child,
        ),
      ),
    );
  }
}

/// A dialog laid out like the mockup's Connect / Delete dialogs: a
/// [FcDialogSurface], a 17/600 title, 16px to the body, 18px to the actions.
class FcDialog extends StatelessWidget {
  const FcDialog({
    super.key,
    required this.title,
    required this.content,
    required this.actions,
    this.scrollable = false,
  });

  final String title;
  final Widget content;
  final List<Widget> actions;
  final bool scrollable;

  @override
  Widget build(BuildContext context) {
    return FcDialogSurface(
      minWidth: 280,
      child: IntrinsicWidth(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: AppTypography.uiTitle.copyWith(
                fontSize: 17,
                height: 24 / 17,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
            const SizedBox(height: 16),
            Flexible(
              child: scrollable
                  ? SingleChildScrollView(child: content)
                  : content,
            ),
            const SizedBox(height: 18),
            OverflowBar(
              alignment: MainAxisAlignment.end,
              spacing: 8,
              overflowSpacing: 8,
              overflowAlignment: OverflowBarAlignment.end,
              children: actions,
            ),
          ],
        ),
      ),
    );
  }
}
