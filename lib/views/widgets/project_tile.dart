import 'package:flutter/material.dart';

import 'package:flowcraft/core/theme/app_radius.dart';
import 'package:flowcraft/core/theme/app_spacing.dart';
import 'package:flowcraft/core/theme/app_typography.dart';
import 'package:flowcraft/core/utils/relative_time.dart';
import 'package:flowcraft/models/flow_project.dart';

/// One row in the project sidebar: name, when it was last touched, how much
/// is on it, plus rename/delete.
///
/// A [FlowProject] whose file failed to parse renders as a muted, unopenable
/// row rather than being hidden — a project the user can see and delete is
/// far less alarming than one that silently disappeared.
class ProjectTile extends StatelessWidget {
  const ProjectTile({
    super.key,
    required this.project,
    required this.isActive,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  final FlowProject project;
  final bool isActive;
  final VoidCallback onOpen;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final broken = project.isBroken;
    final titleColor = broken ? colorScheme.error : colorScheme.onSurface;

    return Semantics(
      selected: isActive,
      child: Material(
        // Inactive rows take the sidebar's own surface rather than a
        // transparent literal, so every colour here still comes from the
        // scheme and follows the dark/light toggle.
        color: isActive
            ? colorScheme.surfaceContainerHighest
            : colorScheme.surfaceContainerLow,
        borderRadius: AppRadius.smRadius,
        child: InkWell(
          borderRadius: AppRadius.smRadius,
          onTap: broken ? null : onOpen,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.toolbarGap,
              vertical: AppSpacing.toolbarGap,
            ),
            child: Row(
              children: [
                _ActiveMarker(isActive: isActive),
                const SizedBox(width: AppSpacing.toolbarGap),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        project.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.bodySm.copyWith(
                          fontWeight:
                              isActive ? FontWeight.w600 : FontWeight.w400,
                          color: titleColor,
                        ),
                      ),
                      Text(
                        _subtitle(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTypography.caption.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                _RowMenu(
                  canRename: !broken,
                  onRename: onRename,
                  onDelete: onDelete,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _subtitle() {
    if (project.isBroken) return "Can't be read";
    final count = project.elementCount;
    return '$count element${count == 1 ? '' : 's'} · '
        '${RelativeTime.format(project.updatedAt)}';
  }
}

/// Vertical accent bar flagging the open project. A colour-only cue would
/// be invisible to a colour-blind user, so the active row also carries a
/// filled background and a heavier title weight.
class _ActiveMarker extends StatelessWidget {
  const _ActiveMarker({required this.isActive});

  static const double _width = 3;
  static const double _height = 28;

  final bool isActive;

  @override
  Widget build(BuildContext context) {
    // Reserves its width either way so rows don't shift sideways as the
    // selection moves; inactive draws nothing rather than painting a
    // transparent colour.
    if (!isActive) return const SizedBox(width: _width);
    return Container(
      width: _width,
      height: _height,
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary,
        borderRadius: AppRadius.xsRadius,
      ),
    );
  }
}

class _RowMenu extends StatelessWidget {
  const _RowMenu({
    required this.canRename,
    required this.onRename,
    required this.onDelete,
  });

  final bool canRename;
  final VoidCallback onRename;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return MenuAnchor(
      menuChildren: [
        MenuItemButton(
          leadingIcon: const Icon(Icons.edit_outlined, size: 18),
          onPressed: canRename ? onRename : null,
          child: const Text('Rename'),
        ),
        MenuItemButton(
          leadingIcon: Icon(
            Icons.delete_outline_rounded,
            size: 18,
            color: colorScheme.error,
          ),
          onPressed: onDelete,
          child: Text(
            'Delete',
            style: TextStyle(color: colorScheme.error),
          ),
        ),
      ],
      builder: (context, menu, _) => IconButton(
        icon: const Icon(Icons.more_horiz_rounded, size: 18),
        color: colorScheme.onSurfaceVariant,
        tooltip: 'Project actions',
        onPressed: () => menu.isOpen ? menu.close() : menu.open(),
      ),
    );
  }
}
