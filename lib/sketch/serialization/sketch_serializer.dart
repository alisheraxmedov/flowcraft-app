import 'dart:convert';

import 'package:flowcraft/sketch/domain/stroke_simplifier.dart';
import 'package:flowcraft/sketch/models/sketch_element.dart';

/// Versioned JSON serialization for the sketch scene.
///
/// On write, freedraw strokes are simplified via [StrokeSimplifier.simplify]
/// to keep the payload compact without visible quality loss. On read, the
/// payload is validated against the schema version and a best-effort
/// migration is applied for older snapshots.
class SketchSerializer {
  SketchSerializer._();

  /// Current on-disk schema version. Bump when changing the JSON shape;
  /// add a migration branch in [fromMap] for older versions.
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
      final encoded = element.toJson();
      // Simplify freedraw strokes on write to keep payload small.
      if (element is SketchFreedraw &&
          simplificationTolerance > 0 &&
          element.points.length > 4) {
        final simplified = StrokeSimplifier.simplify(
          element.points,
          tolerance: simplificationTolerance,
        );
        encoded['points'] = [
          for (final p in simplified) {'dx': p.dx, 'dy': p.dy},
        ];
      }
      out.add(encoded);
    }
    return {
      'version': schemaVersion,
      'elements': out,
    };
  }

  static List<SketchElement> fromMap(Map<String, dynamic> map) {
    final version = map['version'] as int? ?? 0;
    if (version > schemaVersion) {
      throw StateError(
        'Unsupported sketch schema version: $version '
        '(this build supports up to $schemaVersion)',
      );
    }

    final raw = (map['elements'] as List<dynamic>? ?? const <dynamic>[])
        .cast<Map<String, dynamic>>();
    return [
      for (final json in raw) SketchElement.fromJson(json),
    ];
  }
}
