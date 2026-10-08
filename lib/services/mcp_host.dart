import 'package:flowcraft/models/flow_project.dart';

/// What the MCP tools may ask of the saved-project library.
///
/// Closures rather than a reference to `ProjectsViewModel`: `services/` sits
/// below `viewmodels/` and must stay free of Riverpod (and, behind the
/// `dart:io` split, of anything that would not compile for web). Each
/// closure is wired in `McpViewModel` straight onto the view model's own
/// queued operations, so opening a project through MCP takes exactly the
/// path a drawer tap does — `loadScene`, autosave rebinding, index-as-cache.
class McpProjectsHost {
  const McpProjectsHost({
    required this.list,
    required this.activeId,
    required this.open,
    required this.create,
    required this.rename,
    required this.link,
    required this.unlink,
  });

  final List<FlowProject> Function() list;
  final String? Function() activeId;
  final Future<void> Function(String id) open;
  final Future<void> Function(String name) create;
  final Future<void> Function(String id, String name) rename;

  /// Throws with the refusal reason when [path] is unusable.
  final Future<void> Function(String id, String path) link;
  final Future<void> Function(String id) unlink;
}
