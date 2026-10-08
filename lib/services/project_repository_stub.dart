import 'package:flowcraft/models/flow_project.dart';
import 'package:flowcraft/models/sketch_element.dart';

/// Web fallback for [ProjectRepository] — saved projects live in files, and
/// `dart:io` doesn't exist on web. Selected in place of
/// `project_repository_io.dart` by the `dart.library.io` conditional import
/// in `project_repository.dart`.
///
/// [list] returns empty rather than throwing so the sidebar still renders
/// (as an empty library); every write refuses loudly, because silently
/// dropping a save is exactly the data loss this feature exists to fix.
class ProjectRepository {
  ProjectRepository({String? directoryPath});

  /// Present for API parity with the io build; never called here.
  void Function(Object error)? onMirrorError;

  String get directoryPath => '';

  Future<List<FlowProject>> list() async => const <FlowProject>[];

  Future<FlowProjectScene> load(String id) async => throw _unsupported;

  Future<FlowProject> save({
    required String id,
    required List<SketchElement> elements,
  }) async => throw _unsupported;

  Future<FlowProject> create(String name) async => throw _unsupported;

  Future<FlowProject> rename(String id, String name) async =>
      throw _unsupported;

  Future<FlowProject> link(String id, String path) async => throw _unsupported;

  Future<FlowProject> unlink(String id) async => throw _unsupported;

  Future<void> delete(String id) async => throw _unsupported;

  /// Byte-for-byte the io implementation — it is pure string handling with
  /// nothing platform-specific about it, and letting the two drift would
  /// mean the same name normalises differently per build target.
  static String normalizeName(String name) {
    final cleaned = name.trim().replaceAll(RegExp(r'\s+'), ' ');
    if (cleaned.isEmpty) return 'Untitled';
    return cleaned.length <= 80 ? cleaned : cleaned.substring(0, 80);
  }

  static UnsupportedError get _unsupported =>
      UnsupportedError('Saved projects are not available on the web build.');
}
