import 'package:flutter/material.dart';

import 'package:flowcraft/core/theme/app_radius.dart';
import 'package:flowcraft/core/theme/app_typography.dart';

/// Asks for the path of the file a project should be mirrored to.
///
/// A typed path rather than a native picker — the app ships zero plugins,
/// so no file dialog exists (see CLAUDE.md). [onLink] does the real work
/// and resolves to a refusal message, which is shown under the field while
/// the dialog stays open so the user can fix the path; `null` means linked.
class LinkFileDialog extends StatefulWidget {
  const LinkFileDialog({super.key, required this.onLink});

  final Future<String?> Function(String path) onLink;

  @override
  State<LinkFileDialog> createState() => _LinkFileDialogState();
}

class _LinkFileDialogState extends State<LinkFileDialog> {
  final TextEditingController _controller = TextEditingController();
  String? _error;
  bool _busy = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final path = _controller.text.trim();
    if (path.isEmpty || _busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final error = await widget.onLink(path);
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

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      shape: const RoundedRectangleBorder(borderRadius: AppRadius.mdRadius),
      title: Text('Link to file', style: AppTypography.headlineMd),
      content: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: InputDecoration(
          hintText: '~/repo/docs/board.flowcraft',
          helperText:
              'Absolute path ending in .flowcraft or .json. If the file '
              'already exists, this board is replaced by its contents.',
          helperMaxLines: 2,
          errorText: _error,
          errorMaxLines: 3,
          border: const OutlineInputBorder(borderRadius: AppRadius.smRadius),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _submit,
          child: const Text('Link'),
        ),
      ],
    );
  }
}
