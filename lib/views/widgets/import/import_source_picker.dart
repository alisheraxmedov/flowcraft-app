import 'package:flutter/material.dart';

import 'package:flowcraft/core/theme/app_radius.dart';
import 'package:flowcraft/core/theme/app_spacing.dart';
import 'package:flowcraft/core/theme/app_typography.dart';
import 'package:flowcraft/services/importable_scene.dart';
import 'package:flowcraft/views/widgets/import/import_scene_list.dart';

/// Picking *which* scene to import: the export folder's contents, plus a
/// path field for a file that lives anywhere else.
///
/// Both, not one or the other. The list alone can't reach the
/// `.flowcraft.json` a colleague sent; the path field alone would make
/// re-opening your own export a typing exercise.
class ImportSourcePicker extends StatelessWidget {
  const ImportSourcePicker({
    super.key,
    required this.directoryPath,
    required this.scenes,
    required this.selectedPath,
    required this.onSelect,
    required this.pathController,
    required this.onPathChanged,
  });

  final String directoryPath;

  /// `null` while the folder is still being read.
  final List<ImportableScene>? scenes;

  final String? selectedPath;
  final ValueChanged<String> onSelect;
  final TextEditingController pathController;
  final VoidCallback onPathChanged;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final found = scenes;

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          directoryPath,
          style: AppTypography.labelMono.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: AppSpacing.toolbarGap),
        ConstrainedBox(
          constraints: const BoxConstraints(maxHeight: 240),
          child: found == null
              ? const Center(child: CircularProgressIndicator())
              : ImportSceneList(
                  scenes: found,
                  selectedPath: selectedPath,
                  onSelect: onSelect,
                  emptyMessage:
                      'No .json files here yet. Export one, or '
                      'paste a full path below.',
                ),
        ),
        const SizedBox(height: AppSpacing.panelPadding),
        TextField(
          controller: pathController,
          onChanged: (_) => onPathChanged(),
          style: AppTypography.bodySm.copyWith(color: colorScheme.onSurface),
          decoration: const InputDecoration(
            isDense: true,
            labelText: 'Or a path to any scene file',
            hintText: '~/Downloads/board.flowcraft.json',
            border: OutlineInputBorder(borderRadius: AppRadius.smRadius),
          ),
        ),
      ],
    );
  }
}
