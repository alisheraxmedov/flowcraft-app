import 'package:flutter/material.dart';

import 'package:flowcraft/core/theme/app_radius.dart';
import 'package:flowcraft/core/theme/app_spacing.dart';
import 'package:flowcraft/core/theme/app_typography.dart';
import 'package:flowcraft/core/utils/relative_time.dart';
import 'package:flowcraft/services/importable_scene.dart';
import 'package:flowcraft/views/widgets/glass/fc_icons.dart';

/// The `.json` files found in the export folder, newest first.
///
/// Size and age are shown because the folder fills up with timestamped
/// exports of the same board, and the file name alone stops telling them
/// apart after the second one.
class ImportSceneList extends StatelessWidget {
  const ImportSceneList({
    super.key,
    required this.scenes,
    required this.selectedPath,
    required this.onSelect,
    required this.emptyMessage,
  });

  final List<ImportableScene> scenes;
  final String? selectedPath;
  final ValueChanged<String> onSelect;

  /// Shown instead of the list when nothing was found — it names the folder
  /// that was searched, which is the only useful thing to say here.
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    if (scenes.isEmpty) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: AppSpacing.panelPadding),
        child: Text(
          emptyMessage,
          style: AppTypography.bodySm.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      );
    }

    // An eager column in a scroll view rather than a lazy `ListView`: the
    // host dialog is `scrollable`, which sizes its body by intrinsic height,
    // and a lazy viewport refuses to report one. The list is one folder of
    // exports — small enough that laziness bought nothing anyway.
    return SingleChildScrollView(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final scene in scenes)
            _SceneTile(
              scene: scene,
              selected: scene.path == selectedPath,
              onTap: () => onSelect(scene.path),
            ),
        ],
      ),
    );
  }
}

class _SceneTile extends StatelessWidget {
  const _SceneTile({
    required this.scene,
    required this.selected,
    required this.onTap,
  });

  final ImportableScene scene;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Material(
      color: selected ? colorScheme.primaryContainer : Colors.transparent,
      borderRadius: AppRadius.smRadius,
      child: InkWell(
        borderRadius: AppRadius.smRadius,
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.toolbarGap,
            vertical: 6,
          ),
          child: Row(
            children: [
              FcIconGlyph(
                FcIcons.fileJson,
                size: 16,
                color: colorScheme.onSurfaceVariant,
              ),
              const SizedBox(width: AppSpacing.toolbarGap),
              Expanded(
                child: Text(
                  scene.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTypography.bodySm.copyWith(
                    color: selected
                        ? colorScheme.onPrimaryContainer
                        : colorScheme.onSurface,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.toolbarGap),
              Text(
                '${scene.sizeLabel} · ${RelativeTime.format(scene.modifiedAt)}',
                style: AppTypography.caption.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
