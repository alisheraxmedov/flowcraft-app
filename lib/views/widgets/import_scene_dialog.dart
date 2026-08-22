import 'package:flutter/material.dart';

import 'package:flowcraft/services/importable_scene.dart';
import 'package:flowcraft/services/scene_import_source.dart';
import 'package:flowcraft/viewmodels/scene_importer.dart';
import 'package:flowcraft/viewmodels/sketch_controller.dart';
import 'package:flowcraft/views/widgets/import/import_actions.dart';
import 'package:flowcraft/views/widgets/import/import_feedback.dart';
import 'package:flowcraft/views/widgets/import/import_source_picker.dart';

/// "Import from file" — pick one of the exports already on disk, or type a
/// path to a scene that came from somewhere else.
///
/// A list plus a path field, because there is no native file picker to
/// borrow (the zero-plugin rule; see `SceneImportSource`). The list covers
/// the case that actually happens — re-opening something this app exported,
/// which always lands in one known folder — in a single click and no typing.
/// The path field is the escape hatch for the `.flowcraft.json` a colleague
/// sent, which would otherwise be unreachable without a file dialog.
class ImportSceneDialog extends StatefulWidget {
  const ImportSceneDialog({
    super.key,
    required this.controller,
    this.directoryPath,
  });

  final SketchController controller;

  /// Folder to list; defaults to the export folder. Tests point it at a
  /// temp directory.
  final String? directoryPath;

  static Future<void> show(
    BuildContext context,
    SketchController controller, {
    String? directoryPath,
  }) {
    return showDialog<void>(
      context: context,
      builder: (_) => ImportSceneDialog(
        controller: controller,
        directoryPath: directoryPath,
      ),
    );
  }

  @override
  State<ImportSceneDialog> createState() => _ImportSceneDialogState();
}

class _ImportSceneDialogState extends State<ImportSceneDialog> {
  final TextEditingController _path = TextEditingController();

  List<ImportableScene>? _scenes;
  String? _selectedPath;
  String? _error;
  bool _busy = false;

  late final String _directory =
      widget.directoryPath ?? SceneImportSource.defaultDirectoryPath();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final scenes = await SceneImportSource.list(
        directoryPath: widget.directoryPath,
      );
      if (mounted) setState(() => _scenes = scenes);
    } catch (error) {
      if (mounted) {
        setState(() {
          _scenes = const <ImportableScene>[];
          _error = 'Could not read $_directory: $error';
        });
      }
    }
  }

  /// The typed path wins when it is non-empty — if someone has bothered to
  /// type one, a row highlighted earlier is not what they meant.
  String? get _source =>
      _path.text.trim().isNotEmpty ? _path.text.trim() : _selectedPath;

  Future<void> _import(SceneImportMode mode) async {
    final path = _source;
    if (path == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final navigator = Navigator.of(context);
    setState(() {
      _busy = true;
      _error = null;
    });

    final String json;
    try {
      json = await SceneImportSource.read(path);
    } catch (error) {
      _fail('Could not read $path: $error');
      return;
    }

    final result = SceneImporter.import(widget.controller, json, mode: mode);
    if (!mounted) return;
    if (!result.succeeded) {
      _fail(result.error!);
      return;
    }
    navigator.pop();
    ImportFeedback.report(messenger, result);
  }

  /// Shows [message] in the dialog rather than as a snackbar behind it: the
  /// fix for a bad file is to pick a different one, which means staying
  /// here with the list still on screen.
  void _fail(String message) {
    if (!mounted) return;
    setState(() {
      _busy = false;
      _error = message;
    });
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Import a scene'),
      content: SizedBox(
        width: 560,
        child: ImportSourcePicker(
          directoryPath: _directory,
          scenes: _scenes,
          selectedPath: _selectedPath,
          onSelect: (path) => setState(() {
            _selectedPath = path;
            // Picking a row retracts a half-typed path, so the two inputs
            // can never disagree about what is about to be imported.
            _path.clear();
          }),
          pathController: _path,
          onPathChanged: () => setState(() {}),
        ),
      ),
      actions: [
        ImportActions(
          enabled: _source != null,
          busy: _busy,
          error: _error,
          onImport: _import,
        ),
      ],
    );
  }
}
