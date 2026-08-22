import 'package:flutter/foundation.dart' show immutable, listEquals;

import 'package:flowcraft/models/flow_project.dart';

/// Immutable snapshot of the saved-project library for the sidebar.
@immutable
class ProjectsState {
  const ProjectsState({
    this.projects = const <FlowProject>[],
    this.activeId,
    this.isLoading = true,
    this.error,
  });

  /// Every project on disk, newest edit first.
  final List<FlowProject> projects;

  /// The project the canvas is currently editing, or `null` while none is
  /// open (startup, or after deleting the last one on a web build).
  final String? activeId;

  /// True until the first listing completes, so the sidebar can show a
  /// spinner instead of an "empty library" message it would have to
  /// retract a frame later.
  final bool isLoading;

  /// Last failure worth telling the user about. Cleared by the next
  /// successful action.
  final String? error;

  FlowProject? get active {
    for (final project in projects) {
      if (project.id == activeId) return project;
    }
    return null;
  }

  ProjectsState copyWith({
    List<FlowProject>? projects,
    String? activeId,
    bool clearActive = false,
    bool? isLoading,
    String? error,
    bool clearError = false,
  }) {
    return ProjectsState(
      projects: projects ?? this.projects,
      activeId: clearActive ? null : (activeId ?? this.activeId),
      isLoading: isLoading ?? this.isLoading,
      error: clearError ? null : (error ?? this.error),
    );
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is ProjectsState &&
        listEquals(other.projects, projects) &&
        other.activeId == activeId &&
        other.isLoading == isLoading &&
        other.error == error;
  }

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(projects), activeId, isLoading, error);
}
