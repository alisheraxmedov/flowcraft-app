import 'dart:convert';

import 'package:flowcraft/core/domain/stroke_simplifier.dart';
import 'package:flowcraft/models/sketch_element.dart';

/// Versioned JSON serialization for the sketch scene.
///
/// On write, freedraw strokes are simplified via [StrokeSimplifier.simplify]
/// to keep the payload compact without visible quality loss. On read, the
/// payload is validated against the schema version and a best-effort
/// migration is applied for older snapshots.
///
/// Reading comes in two strengths: [fromMap] refuses a payload with any bad
/// element in it, [load] keeps the good ones and reports the rest. Which one
/// a caller wants depends on whether bad input is its own fault or the
/// file's — see each.
class SketchSerializer {
  SketchSerializer._();

  /// Current on-disk schema version. Bump when changing the JSON shape;
  /// add a migration branch in [_read] for older versions.
  ///
  /// *Adding* a field does not qualify, as long as its `fromJson` defaults
  /// and its `toJson` omits it when unset: old files still load, and new
  /// files still load in builds that ignore the key. Bumping for that would
  /// make every already-saved file unreadable by the build that saved it.
  static const int schemaVersion = 1;

  /// Encodes [elements] to a JSON string with the current [schemaVersion].
  static String serialize(
    List<SketchElement> elements, {
    double simplificationTolerance = 0.5,
  }) {
    return jsonEncode(toMap(
      elements,
      simplificationTolerance: simplificationTolerance,
    ));
  }

  /// Decodes a JSON string previously produced by [serialize].
  static List<SketchElement> deserialize(String jsonString) {
    final map = jsonDecode(jsonString) as Map<String, dynamic>;
    return fromMap(map);
  }

  static Map<String, dynamic> toMap(
    List<SketchElement> elements, {
    double simplificationTolerance = 0.5,
  }) {
    final out = <Map<String, dynamic>>[];
    for (final element in elements) {
      // Simplify freedraw strokes on write to keep payload small. The
      // simplified copy is what gets encoded — encoding the full stroke
      // first and then overwriting its `points` did the expensive half of
      // the work twice.
      if (element is SketchFreedraw &&
          simplificationTolerance > 0 &&
          element.points.length > 4) {
        final simplified = StrokeSimplifier.simplify(
          element.points,
          tolerance: simplificationTolerance,
        );
        out.add(element.copyWith(points: simplified).toJson());
        continue;
      }
      out.add(element.toJson());
    }
    return {
      'version': schemaVersion,
      'elements': out,
    };
  }

  /// Strict decode: any element that fails to parse takes the whole scene
  /// down with it. Right for callers whose input is a caller error rather
  /// than a file — the MCP draw path wants a loud rejection, not a scene
  /// silently missing the shape the agent asked for.
  ///
  /// Use [load] to open a *file*, where one bad element must not cost the
  /// user every other element in it.
  static List<SketchElement> fromMap(Map<String, dynamic> map) =>
      _read(map, tolerant: false).elements;

  /// Tolerant decode: elements that fail to parse are skipped and reported
  /// in [SketchSceneLoad.errors] instead of aborting the load.
  ///
  /// One unreadable element used to make a whole project unopenable — it
  /// surfaced as a broken row in the sidebar and every other element in the
  /// file went with it. Skipping is only defensible because the loss is
  /// *reported*: a silent partial load that autosave then wrote back over
  /// the original file would turn a recoverable problem into a permanent
  /// one, so callers must decide what to do about a non-empty
  /// [SketchSceneLoad.errors] before saving.
  ///
  /// The schema-version check still throws. A payload from a newer build is
  /// not one bad element: nothing here knows which parts of it are safe to
  /// keep, and quietly dropping what it doesn't understand would corrupt the
  /// file on the next save. Refusing it whole is the honest answer.
  static SketchSceneLoad load(Map<String, dynamic> map) =>
      _read(map, tolerant: true);

  /// [load] over a JSON string. Throws on text that isn't a JSON object —
  /// see [load] for what it tolerates and what it doesn't.
  static SketchSceneLoad loadJson(String jsonString) =>
      load(jsonDecode(jsonString) as Map<String, dynamic>);

  static SketchSceneLoad _read(
    Map<String, dynamic> map, {
    required bool tolerant,
  }) {
    // `num`, not `int`: a payload that has been through a tool that writes
    // every number as a double (`1.0`) is still this schema, not a crash.
    final version = (map['version'] as num?)?.toInt() ?? 0;
    if (version > schemaVersion) {
      throw StateError(
        'Unsupported sketch schema version: $version '
        '(this build supports up to $schemaVersion)',
      );
    }

    final raw = map['elements'] as List<dynamic>? ?? const <dynamic>[];
    final elements = <SketchElement>[];
    final errors = <SketchElementLoadError>[];
    for (var i = 0; i < raw.length; i++) {
      final entry = raw[i];
      try {
        if (entry is! Map) {
          throw StateError('Expected an object, got ${entry.runtimeType}.');
        }
        elements.add(SketchElement.fromJson(entry.cast<String, dynamic>()));
      } catch (error) {
        if (!tolerant) rethrow;
        errors.add(SketchElementLoadError(
          index: i,
          // Read defensively: this entry is already known to be malformed,
          // and throwing while describing the failure would defeat the
          // point of tolerating it.
          id: _stringOrNull(entry, 'id'),
          type: _stringOrNull(entry, 'type'),
          error: error,
        ));
      }
    }
    return SketchSceneLoad(elements: elements, errors: errors);
  }

  static String? _stringOrNull(Object? entry, String key) {
    if (entry is! Map) return null;
    final value = entry[key];
    return value is String ? value : null;
  }
}

/// One element of a scene payload that could not be decoded.
class SketchElementLoadError {
  const SketchElementLoadError({
    required this.index,
    required this.error,
    this.id,
    this.type,
  });

  /// Position in the payload's element list, which is the only handle on an
  /// element whose own `id` is missing or malformed.
  final int index;

  final String? id;
  final String? type;
  final Object error;

  @override
  String toString() =>
      'element #$index (${type ?? 'unknown type'}, ${id ?? 'no id'}): $error';
}

/// Outcome of a tolerant scene decode: what loaded, and what did not.
class SketchSceneLoad {
  const SketchSceneLoad({
    required this.elements,
    required this.errors,
  });

  final List<SketchElement> elements;

  /// Elements dropped on the way in, in payload order. Empty on a clean
  /// load — check [isComplete] before overwriting the file this came from.
  final List<SketchElementLoadError> errors;

  bool get isComplete => errors.isEmpty;

  int get droppedCount => errors.length;
}
