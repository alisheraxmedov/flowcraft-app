import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flowcraft/core/theme/app_radius.dart';
import 'package:flowcraft/core/theme/app_typography.dart';
import 'package:flowcraft/core/theme/fc_tokens.dart';
import 'package:flowcraft/models/flow_project.dart';
import 'package:flowcraft/viewmodels/projects_state.dart';
import 'package:flowcraft/viewmodels/projects_view_model.dart';
import 'package:flowcraft/views/widgets/glass/fc_icons.dart';
import 'package:flowcraft/views/widgets/link_file_dialog.dart';
import 'package:flowcraft/views/widgets/project_dialogs.dart';
import 'package:flowcraft/views/widgets/project_tile.dart';
import 'package:flowcraft/views/widgets/toolbar/popover_button.dart';

/// The panel-left button in the top-left island; opens [ProjectsPopover].
class ProjectsButton extends StatelessWidget {
  const ProjectsButton({super.key, this.anchorLink});

  /// Target the popover aligns to (the top-left island); null = the button.
  final LayerLink? anchorLink;

  @override
  Widget build(BuildContext context) {
    final t = context.fc;
    return PopoverButton(
      tooltip: 'Projects',
      activeColor: t.accent,
      anchor: PopoverAnchor.below,
      anchorLink: anchorLink,
      radius: AppRadius.island,
      builder: (context, _) =>
          FcIconGlyph(FcIcons.panelLeft, size: 18, color: t.muted),
      popoverBuilder: (context, close) => ProjectsPopover(close: close),
    );
  }
}

/// Every saved whiteboard, in a 340px glass popover.
///
/// [close] (from [PopoverButton]) is called BEFORE `await openProject`: the
/// popover getting out of the way the instant a row is tapped is what makes
/// switching feel immediate, and it keeps the dismiss off the far side of an
/// `await` (this widget is unmounted by then). Opening goes through
/// [ProjectsViewModel], i.e. `SketchController.loadScene`, never `replaceAll`.
class ProjectsPopover extends ConsumerWidget {
  const ProjectsPopover({super.key, required this.close});

  final VoidCallback close;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(projectsViewModelProvider);
    final model = ref.read(projectsViewModelProvider.notifier);
    final t = context.fc;

    return SizedBox(
      width: 340,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Projects',
                  style: AppTypography.uiTitle.copyWith(
                    fontSize: 15,
                    color: t.text,
                  ),
                ),
                Container(
                  constraints: const BoxConstraints(minWidth: 24),
                  height: 20,
                  padding: const EdgeInsets.symmetric(horizontal: 7),
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: t.surface2,
                    borderRadius: BorderRadius.circular(AppRadius.pill),
                  ),
                  child: Text(
                    '${state.projects.length}',
                    style: AppTypography.mono11.copyWith(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w500,
                      height: 1,
                      color: t.muted,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
            child: _NewButton(onPressed: () => _create(context, model)),
          ),
          if (state.error != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: _ErrorBanner(
                message: state.error!,
                onDismiss: model.dismissError,
              ),
            ),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxHeight: 360),
              child: _ProjectList(
                state: state,
                onOpen: (project) => _open(model, project.id),
                onRename: (project) => _rename(context, model, project),
                onDelete: (project) => _delete(context, model, project),
                onLink: (project) => showDialog<void>(
                  context: context,
                  builder: (_) => LinkFileDialog(
                    onLink: (path) => model.linkProject(project.id, path),
                  ),
                ),
                onUnlink: (project) => model.unlinkProject(project.id),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _create(BuildContext context, ProjectsViewModel model) async {
    final name = await ProjectDialogs.askName(
      context,
      title: 'New project',
      confirmLabel: 'Create',
    );
    if (name == null) return;
    close();
    await model.createProject(name);
  }

  Future<void> _open(ProjectsViewModel model, String id) async {
    close();
    await model.openProject(id);
  }

  Future<void> _rename(
    BuildContext context,
    ProjectsViewModel model,
    FlowProject project,
  ) async {
    final name = await ProjectDialogs.askName(
      context,
      title: 'Rename project',
      confirmLabel: 'Rename',
      initialValue: project.name,
    );
    if (name == null) return;
    await model.renameProject(project.id, name);
  }

  Future<void> _delete(
    BuildContext context,
    ProjectsViewModel model,
    FlowProject project,
  ) async {
    final confirmed = await ProjectDialogs.confirmDelete(
      context,
      projectName: project.name,
    );
    if (confirmed) await model.deleteProject(project.id);
  }
}

class _NewButton extends StatelessWidget {
  const _NewButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final t = context.fc;
    return Material(
      color: t.accentTint,
      borderRadius: BorderRadius.circular(AppRadius.button),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.button),
        onTap: onPressed,
        child: SizedBox(
          height: 36,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              FcIconGlyph(FcIcons.plus, size: 16, color: t.accentText),
              const SizedBox(width: 8),
              Text(
                'New project',
                style: AppTypography.bodySm.copyWith(
                  fontWeight: FontWeight.w600,
                  height: 1,
                  color: t.accentText,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProjectList extends StatelessWidget {
  const _ProjectList({
    required this.state,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
    required this.onLink,
    required this.onUnlink,
  });

  final ProjectsState state;
  final ValueChanged<FlowProject> onOpen;
  final ValueChanged<FlowProject> onRename;
  final ValueChanged<FlowProject> onDelete;
  final ValueChanged<FlowProject> onLink;
  final ValueChanged<FlowProject> onUnlink;

  @override
  Widget build(BuildContext context) {
    final t = context.fc;
    if (state.isLoading && state.projects.isEmpty) {
      return const Padding(
        padding: EdgeInsets.all(24),
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (state.projects.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: Text(
          'No saved projects yet.\nStart one to keep your work.',
          textAlign: TextAlign.center,
          style: AppTypography.bodySm.copyWith(color: t.muted),
        ),
      );
    }
    return ListView.separated(
      shrinkWrap: true,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
      itemCount: state.projects.length,
      separatorBuilder: (_, _) => const SizedBox(height: 2),
      itemBuilder: (context, index) {
        final project = state.projects[index];
        return ProjectTile(
          project: project,
          isActive: project.id == state.activeId,
          onOpen: () => onOpen(project),
          onRename: () => onRename(project),
          onDelete: () => onDelete(project),
          onLink: () => onLink(project),
          onUnlink: () => onUnlink(project),
        );
      },
    );
  }
}

/// Sticky failure notice (mockup's danger box: 10 padding, radius 10).
/// Dismissable because `state.error` otherwise survives until the next
/// *successful* mutation — a one-off disk hiccup would sit here forever.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final t = context.fc;
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: t.dangerTint,
        borderRadius: BorderRadius.circular(AppRadius.button),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 1),
            child: FcIconGlyph(FcIcons.circleAlert, size: 16, color: t.danger),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: AppTypography.bodySm.copyWith(
                fontSize: 12.5,
                height: 18 / 12.5,
                color: t.danger,
              ),
            ),
          ),
          Tooltip(
            message: 'Dismiss',
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: onDismiss,
              child: Padding(
                padding: const EdgeInsets.only(left: 8, top: 1),
                child: FcIconGlyph(FcIcons.x, size: 16, color: t.danger),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
