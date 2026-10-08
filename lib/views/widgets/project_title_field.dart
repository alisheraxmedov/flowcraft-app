import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show LogicalKeyboardKey;
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flowcraft/core/theme/app_radius.dart';
import 'package:flowcraft/core/theme/app_typography.dart';
import 'package:flowcraft/core/theme/fc_tokens.dart';
import 'package:flowcraft/models/flow_project.dart';
import 'package:flowcraft/viewmodels/projects_view_model.dart';

/// The open project's name in the top-left island, click-to-rename in place.
///
/// Inline rather than behind a dialog, because renaming is the one project
/// action done often enough that a modal gets in the way — and the name is
/// already on screen. Blurring commits (matching the canvas text editor's
/// behaviour) while Escape abandons, so neither mouse nor keyboard users
/// have to hunt for a confirm button.
///
/// Renders nothing when no project is open, so it is safe to leave in the
/// tree unconditionally. Hosts in a `MainAxisSize.min` row should wrap it in
/// a [Flexible] so a long name ellipsises instead of overflowing a narrow
/// window.
class ProjectTitleField extends ConsumerStatefulWidget {
  const ProjectTitleField({super.key, this.width = 160});

  /// Widest the name button grows (it hugs its text below that) and the
  /// width of the inline rename field.
  final double width;

  @override
  ConsumerState<ProjectTitleField> createState() => _ProjectTitleFieldState();
}

class _ProjectTitleFieldState extends ConsumerState<ProjectTitleField> {
  final TextEditingController _controller = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  /// The project this edit started on. Pinned rather than re-read on
  /// commit: clicking a sidebar row both opens another project *and* blurs
  /// this field, so "whatever is active now" would apply the typed name to
  /// the project the user just switched to.
  String? _editingId;

  bool get _editing => _editingId != null;

  @override
  void initState() {
    super.initState();
    // Clicking elsewhere is a commit, not a cancel — the same bet the
    // inline canvas text editor makes, so renaming feels consistent.
    _focusNode.addListener(() {
      if (!_focusNode.hasFocus && _editing) _commit();
    });
  }

  @override
  void dispose() {
    // Disposing the node fires the focus listener; clearing the target
    // first stops that from running a commit (and a setState) on a dead
    // State.
    _editingId = null;
    _controller.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _beginEdit(FlowProject project) {
    _controller.text = project.name;
    _controller.selection = TextSelection(
      baseOffset: 0,
      extentOffset: project.name.length,
    );
    setState(() => _editingId = project.id);
    _focusNode.requestFocus();
  }

  void _commit() {
    final id = _editingId;
    final name = _controller.text.trim();
    setState(() => _editingId = null);
    if (id == null || name.isEmpty) return;
    ref.read(projectsViewModelProvider.notifier).renameProject(id, name);
  }

  void _cancel() {
    setState(() => _editingId = null);
    _focusNode.unfocus();
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(projectsViewModelProvider).active;
    if (active == null) {
      // Dropping the edit target here rather than via setState: we are
      // already inside build, and the field is about to unmount and blur —
      // which would otherwise re-enter setState mid-build.
      _editingId = null;
      return const SizedBox.shrink();
    }

    return _editing
        ? SizedBox(
            width: widget.width,
            height: 32,
            child: _NameField(
              controller: _controller,
              focusNode: _focusNode,
              onSubmitted: _commit,
              onCancel: _cancel,
            ),
          )
        : ConstrainedBox(
            constraints: BoxConstraints(maxWidth: widget.width),
            child: _NameButton(
              name: active.name,
              onTap: () => _beginEdit(active),
            ),
          );
  }
}

class _NameButton extends StatelessWidget {
  const _NameButton({required this.name, required this.onTap});

  final String name;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final t = context.fc;
    // Mockup: 32px tall, radius 10, 8px side padding, 14/600 text colour.
    return Tooltip(
      message: 'Rename project',
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.button),
        hoverColor: t.surface2,
        onTap: onTap,
        child: Container(
          height: 32,
          alignment: Alignment.centerLeft,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text(
            name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTypography.uiTitle.copyWith(color: t.text),
          ),
        ),
      ),
    );
  }
}

class _NameField extends StatelessWidget {
  const _NameField({
    required this.controller,
    required this.focusNode,
    required this.onSubmitted,
    required this.onCancel,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final VoidCallback onSubmitted;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final t = context.fc;
    // `CallbackShortcuts` rather than a `KeyboardListener`: it reuses the
    // TextField's own focus instead of needing a second FocusNode this
    // stateless widget would have nowhere to dispose.
    return CallbackShortcuts(
      bindings: {const SingleActivator(LogicalKeyboardKey.escape): onCancel},
      child: TextField(
        controller: controller,
        focusNode: focusNode,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => onSubmitted(),
        style: AppTypography.uiTitle.copyWith(color: t.text),
        decoration: InputDecoration(
          isDense: true,
          filled: true,
          fillColor: t.surface2,
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 8,
            vertical: 6,
          ),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(AppRadius.button),
            borderSide: BorderSide.none,
          ),
        ),
      ),
    );
  }
}
