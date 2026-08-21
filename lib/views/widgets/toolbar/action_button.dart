import 'package:flutter/material.dart';

import 'package:flowcraft/core/theme/app_radius.dart';

/// A single icon-only action button (undo / redo / clear, etc.) used in
/// the rich sketch toolbar. Dims and disables tapping when [enabled] is
/// false.
class ActionButton extends StatelessWidget {
  const ActionButton({
    super.key,
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.enabled,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final bool enabled;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Tooltip(
      message: tooltip,
      child: InkWell(
        borderRadius: AppRadius.mdRadius,
        hoverColor: enabled
            ? colorScheme.surfaceContainerHighest.withValues(alpha: 0.6)
            : Colors.transparent,
        onTap: enabled ? onTap : null,
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 2),
          width: 40,
          height: 40,
          alignment: Alignment.center,
          child: Icon(
            icon,
            size: 18,
            color: color.withValues(alpha: enabled ? 1.0 : 0.3),
          ),
        ),
      ),
    );
  }
}
