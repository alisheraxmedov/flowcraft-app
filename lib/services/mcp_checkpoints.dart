import 'package:flowcraft/models/sketch_element.dart';
import 'package:flowcraft/viewmodels/sketch_controller.dart';

/// One restorable snapshot of the canvas.
class McpCheckpoint {
  const McpCheckpoint({
    required this.id,
    required this.cause,
    required this.createdAt,
    required this.projectId,
    required this.elements,
  });

  /// `cp-N`, counting up for the life of the app.
  final String id;

  /// What triggered it: the mutating tool's name, `restore`, or the label an
  /// agent gave a manual checkpoint.
  final String cause;
  final DateTime createdAt;

  /// The project that was open when it was taken. A checkpoint is only
  /// restorable there: restoring it onto another project's canvas would let
  /// autosave write one project's scene into another's file.
  final String? projectId;
  final List<SketchElement> elements;
}

/// A ring of the last [maxEntries] canvas snapshots, taken before every
/// mutating MCP tool so an agent that botches an edit can roll it back.
///
/// In memory only — undo history is not persisted either — and element lists
/// are immutable snapshots, so holding twenty of them shares most of their
/// structure with the live scene.
class McpCheckpoints {
  static const int maxEntries = 20;

  final List<McpCheckpoint> _ring = <McpCheckpoint>[];
  int _nextNumber = 1;
  int? _lastPaintGen;
  String? _lastProjectId;

  /// Snapshots [controller]'s scene, unless nothing has changed since the
  /// previous capture in the same project (a retry loop of failing calls
  /// must not push real checkpoints out of the ring). Returns the checkpoint
  /// that now represents the current scene.
  McpCheckpoint capture(
    SketchController controller,
    String cause,
    String? projectId,
  ) {
    if (_ring.isNotEmpty &&
        _lastPaintGen == controller.paintGen &&
        _lastProjectId == projectId) {
      return _ring.last;
    }
    final checkpoint = McpCheckpoint(
      id: 'cp-${_nextNumber++}',
      cause: cause,
      createdAt: DateTime.now(),
      projectId: projectId,
      elements: controller.elements,
    );
    _ring.add(checkpoint);
    if (_ring.length > maxEntries) _ring.removeAt(0);
    _lastPaintGen = controller.paintGen;
    _lastProjectId = projectId;
    return checkpoint;
  }

  /// Oldest first.
  List<McpCheckpoint> list() => List.unmodifiable(_ring);

  McpCheckpoint? find(String id) {
    for (final checkpoint in _ring) {
      if (checkpoint.id == id) return checkpoint;
    }
    return null;
  }
}
