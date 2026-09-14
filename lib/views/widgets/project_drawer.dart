import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:flowcraft/core/theme/app_radius.dart';
import 'package:flowcraft/core/theme/app_spacing.dart';
import 'package:flowcraft/core/theme/app_typography.dart';
import 'package:flowcraft/models/flow_project.dart';
import 'package:flowcraft/viewmodels/projects_state.dart';
import 'package:flowcraft/viewmodels/projects_view_model.dart';
import 'package:flowcraft/views/widgets/project_dialogs.dart';
import 'package:flowcraft/views/widgets/project_tile.dart';

/// Sidebar listing every saved whiteboard, chat-history style.
///
/// Dismisses its own enclosing drawer on open (via [Scaffold.maybeOf], so a
/// pinned side-panel host is unaffected) — the sidebar getting out of the
/// way the instant a row is tapped is what makes switching feel immediate,
/// and it keeps the dismiss off the far side of an `await`. Nothing here
/// assumes a [Scaffold] or a [Navigator]; [onProjectOpened] exists for
/// hosts that need to react to the same event.
class ProjectDrawer extends ConsumerWidget {
  const ProjectDrawer({super.key, this.onProjectOpened});

  /// Fired after a project is opened or created. Optional — a modal drawer
  /// host does not need it, since this widget dismisses itself.
  final VoidCallback? onProjectOpened;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(projectsViewModelProvider);
    final model = ref.read(projectsViewModelProvider.notifier);
    final colorScheme = Theme.of(context).colorScheme;

    return Drawer(
      backgroundColor: colorScheme.surfaceContainerLow,
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.panelPadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _Header(count: state.projects.length),
              const SizedBox(height: AppSpacing.panelPadding),
              FilledButton.icon(
                onPressed: () => _create(context, model),
                icon: const Icon(Icons.add_rounded, size: 18),
                label: const Text('New project'),
              ),
              if (state.error != null)
                _ErrorBanner(
                  message: state.error!,
                  onDismiss: model.dismissError,
                ),
              const SizedBox(height: AppSpacing.toolbarGap),
              Divider(color: colorScheme.outlineVariant, height: 1),
              Expanded(
                child: _ProjectList(
                  state: state,
                  onOpen: (project) => _open(context, model, project.id),
                  onRename: (project) => _rename(context, model, project),
                  onDelete: (project) => _delete(context, model, project),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _create(BuildContext context, ProjectsViewModel model) async {
    final name = await ProjectDialogs.askName(
      context,
      title: 'New project',
      confirmLabel: 'Create',
    );
    if (name == null || !context.mounted) return;
    _dismiss(context);
    await model.createProject(name);
  }

  Future<void> _open(
    BuildContext context,
    ProjectsViewModel model,
    String id,
  ) async {
    // Dismiss first: the sidebar getting out of the way the instant a row is
    // tapped is what makes switching feel immediate, and it keeps this off
    // the wrong side of an `await`.
    _dismiss(context);
    await model.openProject(id);
  }

  void _dismiss(BuildContext context) {
    onProjectOpened?.call();
    // A no-op for a pinned sidebar, which has no drawer to close.
    Scaffold.maybeOf(context)?.closeDrawer();
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

class _Header extends StatelessWidget {
  const _Header({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Row(
      children: [
        Icon(Icons.folder_open_rounded, size: 18, color: colorScheme.primary),
        const SizedBox(width: AppSpacing.toolbarGap),
        Text(
          'PROJECTS',
          style: AppTypography.labelMono.copyWith(color: colorScheme.onSurface),
        ),
        const Spacer(),
        Text(
          '$count',
          style: AppTypography.caption.copyWith(
            color: colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}

class _ProjectList extends StatelessWidget {
  const _ProjectList({
    required this.state,
    required this.onOpen,
    required this.onRename,
    required this.onDelete,
  });

  final ProjectsState state;
  final ValueChanged<FlowProject> onOpen;
  final ValueChanged<FlowProject> onRename;
  final ValueChanged<FlowProject> onDelete;

  @override
  Widget build(BuildContext context) {
    if (state.isLoading && state.projects.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (state.projects.isEmpty) {
      return const _EmptyState();
    }
    return ListView.builder(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.toolbarGap),
      itemCount: state.projects.length,
      itemBuilder: (context, index) {
        final project = state.projects[index];
        return ProjectTile(
          project: project,
          isActive: project.id == state.activeId,
          onOpen: () => onOpen(project),
          onRename: () => onRename(project),
          onDelete: () => onDelete(project),
        );
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Text(
        'No saved projects yet.\nStart one to keep your work.',
        textAlign: TextAlign.center,
        style: AppTypography.bodySm.copyWith(
          color: colorScheme.onSurfaceVariant,
        ),
      ),
    );
  }
}

/// Sticky failure notice. Dismissable because `state.error` otherwise
/// survives until the next *successful* mutation — so a one-off disk hiccup
/// would sit in the sidebar indefinitely with no way to acknowledge it.
class _ErrorBanner extends StatelessWidget {
  const _ErrorBanner({required this.message, required this.onDismiss});

  final String message;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: AppSpacing.toolbarGap),
      padding: const EdgeInsets.only(
        left: AppSpacing.toolbarGap,
        top: AppSpacing.toolbarGap,
        bottom: AppSpacing.toolbarGap,
      ),
      decoration: BoxDecoration(
        color: colorScheme.errorContainer,
        borderRadius: AppRadius.smRadius,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              message,
              style: AppTypography.caption.copyWith(
                color: colorScheme.onErrorContainer,
              ),
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close_rounded, size: 16),
            color: colorScheme.onErrorContainer,
            tooltip: 'Dismiss',
            visualDensity: VisualDensity.compact,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}
