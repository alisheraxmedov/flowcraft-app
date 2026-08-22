import 'package:flutter/material.dart';

import 'package:flowcraft/core/theme/app_radius.dart';
import 'package:flowcraft/core/theme/app_spacing.dart';
import 'package:flowcraft/core/theme/app_typography.dart';
import 'package:flowcraft/viewmodels/scene_importer.dart';
import 'package:flowcraft/viewmodels/sketch_controller.dart';
import 'package:flowcraft/views/widgets/import/import_actions.dart';
import 'package:flowcraft/views/widgets/import/import_feedback.dart';

/// "Paste JSON" — the import route for a scene that never reached a file.
///
/// Worth having next to the file picker because the *export* menu's third
/// entry puts a scene on the clipboard: without this, the payload FlowCraft
/// itself hands you has nowhere to go back into. It is also the only import
/// that works on the web build, where there is no filesystem to list.
class PasteSceneDialog extends StatefulWidget {
  const PasteSceneDialog({super.key, required this.controller});

  final SketchController controller;

  static Future<void> show(BuildContext context, SketchController controller) {
    return showDialog<void>(
      context: context,
      builder: (_) => PasteSceneDialog(controller: controller),
    );
  }

  @override
  State<PasteSceneDialog> createState() => _PasteSceneDialogState();
}

class _PasteSceneDialogState extends State<PasteSceneDialog> {
  final TextEditingController _json = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _json.dispose();
    super.dispose();
  }

  void _import(SceneImportMode mode) {
    final messenger = ScaffoldMessenger.of(context);
    final result = SceneImporter.import(
      widget.controller,
      _json.text,
      mode: mode,
    );
    if (!result.succeeded) {
      setState(() => _error = result.error);
      return;
    }
    Navigator.of(context).pop();
    ImportFeedback.report(messenger, result);
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return AlertDialog(
      scrollable: true,
      title: const Text('Paste a scene'),
      content: SizedBox(
        width: 560,
        child: TextField(
          controller: _json,
          // Nothing is validated until Import is pressed — validating on
          // every keystroke would paint a half-pasted payload red.
          onChanged: (_) => setState(() => _error = null),
          autofocus: true,
          minLines: 8,
          maxLines: 14,
          style: AppTypography.labelMono.copyWith(color: colorScheme.onSurface),
          decoration: const InputDecoration(
            isDense: true,
            hintText: '{"version": 1, "elements": [ … ]}',
            contentPadding: EdgeInsets.all(AppSpacing.toolbarGap),
            border: OutlineInputBorder(borderRadius: AppRadius.smRadius),
          ),
        ),
      ),
      actions: [
        ImportActions(
          enabled: _json.text.trim().isNotEmpty,
          error: _error,
          onImport: _import,
        ),
      ],
    );
  }
}
