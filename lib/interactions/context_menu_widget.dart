import 'package:flutter/widgets.dart';

/// A simple context menu widget that shows a list of actions.
///
/// Displayed at the tap position when the user right-clicks
/// on a node or edge.
class ContextMenuWidget extends StatelessWidget {
  /// Creates a [ContextMenuWidget].
  const ContextMenuWidget({
    super.key,
    required this.position,
    required this.items,
    this.onDismiss,
  });

  /// The screen-space position to display the menu.
  final Offset position;

  /// The menu items.
  final List<ContextMenuItem> items;

  /// Called when the menu is dismissed.
  final VoidCallback? onDismiss;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy,
      child: Container(
        constraints: const BoxConstraints(minWidth: 140),
        decoration: BoxDecoration(
          color: const Color(0xFFFFFFFF),
          borderRadius: BorderRadius.circular(6),
          boxShadow: const [
            BoxShadow(
              color: Color(0x33000000),
              blurRadius: 12,
              offset: Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: items.map((item) {
            return GestureDetector(
              onTap: () {
                item.onTap();
                onDismiss?.call();
              },
              child: Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 12, vertical: 8),
                child: Text(
                  item.label,
                  style: TextStyle(
                    fontSize: 13,
                    color: item.isDestructive
                        ? const Color(0xFFF44336)
                        : const Color(0xFF333333),
                  ),
                ),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
}

/// A single item in a [ContextMenuWidget].
class ContextMenuItem {
  /// Creates a [ContextMenuItem].
  const ContextMenuItem({
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  /// The display label.
  final String label;

  /// Called when this item is tapped.
  final VoidCallback onTap;

  /// Whether this item is a destructive action (displayed in red).
  final bool isDestructive;
}
