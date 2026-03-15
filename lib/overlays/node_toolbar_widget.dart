import 'package:flutter/widgets.dart';

/// A floating toolbar displayed when a node is selected.
///
/// Shows common actions like delete, rename, and duplicate.
class NodeToolbarWidget extends StatelessWidget {
  /// Creates a [NodeToolbarWidget].
  const NodeToolbarWidget({
    super.key,
    required this.position,
    this.onDelete,
    this.onDuplicate,
    this.onRename,
  });

  /// The screen-space position of the toolbar (typically above the node).
  final Offset position;

  /// Called when delete is pressed.
  final VoidCallback? onDelete;

  /// Called when duplicate is pressed.
  final VoidCallback? onDuplicate;

  /// Called when rename is pressed.
  final VoidCallback? onRename;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      left: position.dx,
      top: position.dy - 40,
      child: FractionalTranslation(
        translation: const Offset(-0.5, 0),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: const Color(0xFF333333),
            borderRadius: BorderRadius.circular(6),
            boxShadow: const [
              BoxShadow(
                color: Color(0x33000000),
                blurRadius: 8,
                offset: Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (onRename != null)
                _ToolbarButton(label: 'Rename', onTap: onRename!),
              if (onDuplicate != null)
                _ToolbarButton(label: 'Copy', onTap: onDuplicate!),
              if (onDelete != null)
                _ToolbarButton(
                  label: 'Delete',
                  onTap: onDelete!,
                  isDestructive: true,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ToolbarButton extends StatelessWidget {
  const _ToolbarButton({
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        child: Text(
          label,
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: isDestructive
                ? const Color(0xFFEF5350)
                : const Color(0xFFFFFFFF),
          ),
        ),
      ),
    );
  }
}
