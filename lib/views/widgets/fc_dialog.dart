import 'package:flutter/material.dart';

import 'package:flowcraft/core/theme/app_typography.dart';

/// An [AlertDialog] laid out like the mockup's Connect / Delete dialogs:
/// 20px padding all round, a 17/600 title, 16px to the body, 18px to the
/// actions.
///
/// Shape and fill are deliberately not set here -- `dialogTheme` supplies the
/// radius-18 glass surface, so every dialog follows the theme.
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
    return AlertDialog(
      scrollable: scrollable,
      titlePadding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
      contentPadding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
      actionsPadding: const EdgeInsets.fromLTRB(20, 18, 20, 20),
      buttonPadding: EdgeInsets.zero,
      actionsOverflowButtonSpacing: 8,
      title: Text(
        title,
        style: AppTypography.uiTitle.copyWith(
          fontSize: 17,
          height: 24 / 17,
          color: Theme.of(context).colorScheme.onSurface,
        ),
      ),
      content: content,
      actions: actions,
    );
  }
}
