import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'package:flowcraft/services/canvas_exporter.dart';
import 'package:flowcraft/services/diagram_spec.dart';
import 'package:flowcraft/services/image_source.dart';
import 'package:flowcraft/viewmodels/sketch_controller.dart';
import 'package:flowcraft/views/widgets/fc_dialog.dart';

/// Longest displayed side of a freshly inserted image, in canvas pixels.
/// A 4000 px photo would otherwise land as a wall the user must shrink.
const double maxInsertedImageSide = 800;

/// Asks for the path of an image file and drops it onto the canvas.
///
/// A typed path rather than a native picker — zero plugins (see CLAUDE.md).
/// The file goes through the same [ImageSource] checks the MCP tool uses, so
/// the refusal text shown under the field is the one an agent would get.
class InsertImageDialog extends StatefulWidget {
  const InsertImageDialog({super.key, required this.controller});

  final SketchController controller;

  static Future<void> show(BuildContext context, SketchController controller) {
    return showDialog<void>(
      context: context,
      builder: (_) => InsertImageDialog(controller: controller),
    );
  }

  @override
  State<InsertImageDialog> createState() => _InsertImageDialogState();
}

class _InsertImageDialogState extends State<InsertImageDialog> {
  final TextEditingController _path = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _path.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final path = _path.text.trim();
    if (path.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await _insert(path);
    if (!mounted) return;
    if (error == null) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _busy = false;
        _error = error;
      });
    }
  }

  /// Returns a refusal message, or null once the image is on the canvas.
  Future<String?> _insert(String path) async {
    final c = widget.controller;
    try {
      final resolved = await ImageSource.resolve([
        {'type': 'image', 'path': path},
      ]);
      final entry = Map<String, dynamic>.from(resolved.single as Map);
      // `resolve` fills the natural size; shrink to the cap, keep aspect.
      final w = (entry['width'] as num).toDouble();
      final h = (entry['height'] as num).toDouble();
      final scale = math.min(1.0, maxInsertedImageSide / math.max(w, h));
      entry['width'] = w * scale;
      entry['height'] = h * scale;
      // Below existing content, left-aligned with it.
      if (c.elements.isEmpty) {
        entry['x'] = 0.0;
        entry['y'] = 0.0;
      } else {
        final bounds = CanvasExporter.contentBounds(c.elements);
        entry['x'] = bounds.left;
        entry['y'] = bounds.bottom + 48;
      }
      final image = parseDiagramElements([entry]);
      c.addAll(image);
      c.selectMany(image.map((e) => e.id));
      c.requestFrame(CanvasExporter.contentBounds(image));
      return null;
    } on DiagramSpecException catch (e) {
      return e.message;
    } catch (_) {
      return 'That file could not be read as an image.';
    }
  }

  @override
  Widget build(BuildContext context) {
    return FcDialog(
      title: 'Insert image',
      content: SizedBox(
        width: 420,
        child: TextField(
          controller: _path,
          autofocus: true,
          textInputAction: TextInputAction.done,
          onSubmitted: (_) => _submit(),
          onChanged: (_) => setState(() => _error = null),
          decoration: InputDecoration(
            hintText: '~/Pictures/diagram.png',
            helperText:
                'Absolute path to a png, jpg, webp or gif (up to 4 MiB).',
            helperMaxLines: 2,
            errorText: _error,
            errorMaxLines: 3,
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: Text(_busy ? 'Inserting…' : 'Insert'),
        ),
      ],
    );
  }
}
