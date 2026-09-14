import 'dart:convert';

import 'package:flowcraft/core/serialization/sketch_serializer.dart';
import 'package:flowcraft/models/flow_project.dart';

/// Versioned JSON encoding for a saved project file and the project index.
///
/// The scene payload is delegated wholesale to [SketchSerializer] rather
/// than re-encoded here, so projects inherit its element format, its
/// tolerant decoder and its schema-version migration hook instead of
/// forking a second format that would drift out of step with it.
///
/// A project file is `{version, project, scene}` with the metadata header
/// first, which is what lets [decodeHeader] rebuild a lost index by reading
/// project files directly.
class ProjectSerializer {
  ProjectSerializer._();

  /// On-disk schema version for the *project wrapper* — independent of
  /// [SketchSerializer.schemaVersion], which versions the scene inside it.
  static const int schemaVersion = 1;

  /// Encodes a whole project file.
  ///
  /// Freedraw strokes are written as they are, not re-simplified: the
  /// gesture handler already ran the same Ramer–Douglas–Peucker pass at the
  /// same tolerance when the stroke was committed, so a second pass here
  /// shaved ~1 % more points for ~40 % of the encode time on a stroke-heavy
  /// board — on the UI isolate, 800 ms after every edit. Explicit export
  /// and clipboard copy go through [SketchSerializer.serialize], which
  /// still simplifies.
  static String encodeScene(FlowProjectScene scene) {
    return jsonEncode({
      'version': schemaVersion,
      'project': scene.project.toJson(),
      'scene': SketchSerializer.toMap(
        scene.elements,
        simplificationTolerance: 0,
      ),
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

  /// Reads only the metadata header of a project file, without decoding the
  /// elements into [SketchElement]s. Used when rebuilding a missing or
  /// stale index.
  ///
  /// The JSON itself is still parsed whole — there is no streaming decoder
  /// in `dart:convert` — so on a large file this costs one `jsonDecode`;
  /// what it skips is the per-element construction and validation.
  static FlowProject decodeHeader(String source) {
    final map = _decodeVersioned(source);
    return FlowProject.fromJson(map['project'] as Map<String, dynamic>);
  }

  /// Re-encodes [source] with its `project` header swapped for [project]
  /// and everything else — the scene in particular — carried over as the
  /// raw JSON it already was.
  ///
  /// This is what a rename goes through. Routing it via [decodeScene] and
  /// [encodeScene] instead would pass the elements through the *tolerant*
  /// decoder, which drops the ones this build can't parse, and then write
  /// the reduced list back — silently destroying, on disk, elements a newer
  /// FlowCraft saved. The scene here is never interpreted, only copied.
  static String replaceHeader(String source, FlowProject project) {
    final map = _decodeVersioned(source);
    map['project'] = project.toJson();
    return jsonEncode(map);
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
    // `num`, not `int`: a file that has been through a tool that writes
    // every number as a double (`1.0`) is still this schema, not a crash.
    final version = (map['version'] as num?)?.toInt() ?? 0;
    if (version > schemaVersion) {
      throw StateError(
        'Unsupported project schema version: $version '
        '(this build supports up to $schemaVersion)',
      );
    }
    return map;
  }
}
