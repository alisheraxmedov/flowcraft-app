import 'package:flutter/material.dart';

import 'package:flowcraft/core/theme/app_radius.dart';
import 'package:flowcraft/core/theme/app_typography.dart';
import 'package:flowcraft/core/theme/fc_tokens.dart';
import 'package:flowcraft/views/widgets/fc_dialog.dart';

/// Glass dialog frame from the mockups' Delete confirm: 360 wide, 20 padding,
/// 15/600 title, 13/19 muted body, 34px buttons right-aligned 8 apart.
///
/// Rides on [FcDialogSurface], so it is the same blurred radius-18 glass card
/// as every other dialog.
class ProjectDialogShell extends StatelessWidget {
  const ProjectDialogShell({
    super.key,
    required this.title,
    this.body,
    this.field,
    required this.actions,
  });

  final String title;
  final String? body;

  /// Optional input shown under the title/body.
  final Widget? field;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final t = context.fc;
    return FcDialogSurface(
      minWidth: 360,
      maxWidth: 360,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTypography.uiTitle.copyWith(
              fontSize: 15,
              height: 22 / 15,
              color: t.text,
            ),
          ),
          if (body != null) ...[
            const SizedBox(height: 6),
            Text(
              body!,
              style: AppTypography.bodySm.copyWith(
                height: 19 / 13,
                color: t.muted,
              ),
            ),
          ],
          if (field != null) ...[const SizedBox(height: 12), field!],
          const SizedBox(height: 18),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              for (var i = 0; i < actions.length; i++) ...[
                if (i > 0) const SizedBox(width: 8),
                actions[i],
              ],
            ],
          ),
        ],
      ),
    );
  }
}

/// 34px dialog button: [ProjectDialogButton.cancel] is the quiet surface2
/// fill (500), the default is accent (600), `danger` swaps in danger/onDanger.
class ProjectDialogButton extends StatelessWidget {
  const ProjectDialogButton(
    this.label, {
    super.key,
    required this.onPressed,
    this.danger = false,
    this.quiet = false,
  });

  const ProjectDialogButton.cancel({super.key, required this.onPressed})
    : label = 'Cancel',
      danger = false,
      quiet = true;

  final String label;
  final VoidCallback? onPressed;
  final bool danger;
  final bool quiet;

  @override
  Widget build(BuildContext context) {
    final t = context.fc;
    final bg = quiet ? t.surface2 : (danger ? t.danger : t.accent);
    final fg = quiet ? t.text : (danger ? t.onDanger : t.onAccent);
    return FilledButton(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        backgroundColor: bg,
        foregroundColor: fg,
        disabledBackgroundColor: bg.withValues(alpha: 0.35),
        elevation: 0,
        minimumSize: const Size(0, 34),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.button),
        ),
        textStyle: AppTypography.bodySm.copyWith(
          fontWeight: quiet ? FontWeight.w500 : FontWeight.w600,
        ),
      ),
      child: Text(label),
    );
  }
}

/// Modal prompts shared by the projects popover: naming a project (new or
/// renamed) and confirming a delete. Kept together because both are pure
/// "ask the user one thing" dialogs the popover and its rows both reach for.
class ProjectDialogs {
  ProjectDialogs._();

  /// Asks for a project name. Resolves to the entered name, or `null` if
  /// the user cancelled or left it blank.
  static Future<String?> askName(
    BuildContext context, {
    required String title,
    required String confirmLabel,
    String initialValue = '',
  }) {
    return showDialog<String>(
      context: context,
      builder: (context) => _NameDialog(
        title: title,
        confirmLabel: confirmLabel,
        initialValue: initialValue,
      ),
    );
  }

  /// Confirms a destructive action. Resolves to `true` only on an explicit
  /// confirm — a dismissed barrier means "no".
  static Future<bool> confirmDelete(
    BuildContext context, {
    required String projectName,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ProjectDialogShell(
        title: 'Delete "$projectName"?',
        body: 'This permanently removes the project file. It cannot be undone.',
        actions: [
          ProjectDialogButton.cancel(
            onPressed: () => Navigator.of(context).pop(false),
          ),
          ProjectDialogButton(
            'Delete',
            danger: true,
            onPressed: () => Navigator.of(context).pop(true),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }
}

class _NameDialog extends StatefulWidget {
  const _NameDialog({
    required this.title,
    required this.confirmLabel,
    required this.initialValue,
  });

  final String title;
  final String confirmLabel;
  final String initialValue;

  @override
  State<_NameDialog> createState() => _NameDialogState();
}

class _NameDialogState extends State<_NameDialog> {
  late final TextEditingController _controller = TextEditingController(
    text: widget.initialValue,
  );

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    final name = _controller.text.trim();
    Navigator.of(context).pop(name.isEmpty ? null : name);
  }

  @override
  Widget build(BuildContext context) {
    return ProjectDialogShell(
      title: widget.title,
      field: TextField(
        controller: _controller,
        autofocus: true,
        textInputAction: TextInputAction.done,
        onSubmitted: (_) => _submit(),
        decoration: const InputDecoration(hintText: 'Project name'),
      ),
      actions: [
        ProjectDialogButton.cancel(
          onPressed: () => Navigator.of(context).pop(),
        ),
        ProjectDialogButton(widget.confirmLabel, onPressed: _submit),
      ],
    );
  }
}
