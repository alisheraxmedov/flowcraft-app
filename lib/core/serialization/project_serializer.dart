import 'dart:convert';

import 'package:flowcraft/core/serialization/sketch_serializer.dart';
import 'package:flowcraft/models/flow_project.dart';

/// Versioned JSON encoding for a saved project file and the project index.
///
/// The scene payload is delegated wholesale to [SketchSerializer] rather
/// than re-encoded here, so projects inherit its stroke simplification and
/// its schema-version migration hook instead of forking a second element
/// format that would drift out of step with it.
///
/// A project file is `{version, project, scene}` with the metadata header
/// first, which is what lets [decodeHeader] rebuild a lost index by reading
/// project files directly.
class ProjectSerializer {
  ProjectSerializer._();

  /// On-disk schema version for the *project wrapper* — independent of
  /// [SketchSerializer.schemaVersion], which versions the scene inside it.
  static const int schemaVersion = 1;

  static String encodeScene(FlowProjectScene scene) {
    return jsonEncode({
      'version': schemaVersion,
      'project': scene.project.toJson(),
      'scene': SketchSerializer.toMap(scene.elements),
    });
  }

  /// Reads a whole project file.
  ///
  /// The scene is decoded with [SketchSerializer.load], not `fromMap`: one
  /// element this build can't parse must not cost the user every other
  /// element in the file. What it does cost is reported as
  /// [FlowProjectScene.droppedCount] — a partial scene that autosave then
  /// wrote back over the original would turn a recoverable file into a
  /// permanently lossy one, so the count has to reach the UI.
  static FlowProjectScene decodeScene(String source) {
    final map = _decodeVersioned(source);
    final scene = SketchSerializer.load(map['scene'] as Map<String, dynamic>);
    return FlowProjectScene(
      project: FlowProject.fromJson(map['project'] as Map<String, dynamic>),
      elements: scene.elements,
      droppedCount: scene.droppedCount,
    );
  }

  /// Reads only the metadata header of a project file, skipping the
  /// elements. Used when rebuilding a missing or stale index.
  static FlowProject decodeHeader(String source) {
    final map = _decodeVersioned(source);
    return FlowProject.fromJson(map['project'] as Map<String, dynamic>);
  }

  static String encodeIndex(List<FlowProject> projects) {
    return jsonEncode({
      'version': schemaVersion,
      'projects': [
        // Broken entries are recovery state, not durable data — persisting
        // them would freeze a transient read failure into the index.
        for (final project in projects)
          if (!project.isBroken) project.toJson(),
      ],
    });
  }

  static List<FlowProject> decodeIndex(String source) {
    final map = _decodeVersioned(source);
    final raw = (map['projects'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    return [for (final json in raw) FlowProject.fromJson(json)];
  }

  static Map<String, dynamic> _decodeVersioned(String source) {
    final map = jsonDecode(source) as Map<String, dynamic>;
    final version = map['version'] as int? ?? 0;
    if (version > schemaVersion) {
      throw StateError(
        'Unsupported project schema version: $version '
        '(this build supports up to $schemaVersion)',
      );
    }
    return map;
  }
}
