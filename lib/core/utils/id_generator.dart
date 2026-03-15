import 'dart:math' as math;

/// Generates short unique identifiers for nodes, edges, and handles.
class IdGenerator {
  static final math.Random _random = math.Random();

  /// Generates a unique ID string based on timestamp and random suffix.
  ///
  /// Format: `prefix_timestamp_randomHex`
  static String generate([String prefix = 'fc']) {
    final timestamp = DateTime.now().microsecondsSinceEpoch;
    final randomPart = _random.nextInt(0xFFFF).toRadixString(16).padLeft(4, '0');
    return '${prefix}_${timestamp}_$randomPart';
  }

  /// Generates a node ID.
  static String nodeId() => generate('node');

  /// Generates an edge ID.
  static String edgeId() => generate('edge');

  /// Generates a handle ID.
  static String handleId() => generate('handle');
}
