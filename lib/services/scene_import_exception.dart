/// Largest scene file the import dialog will read, in bytes.
///
/// Reading happens on the UI isolate — `readAsString` then `jsonDecode`,
/// neither of which can be chunked — so an unbounded path field is a way
/// to freeze the window on, or run the GUI process out of memory with, a
/// file that was never a scene to begin with. 64 MiB is an order of
/// magnitude past the largest board this app produces (10,000 mixed
/// elements encode to ~8 MB), and the MCP endpoint draws the same line
/// at 8 MiB for the same reason.
const int maxSceneImportBytes = 64 * 1024 * 1024;

/// Thrown by `SceneImportSource.read` for a file over
/// [maxSceneImportBytes]. Its text is shown as-is, so it names the size and
/// the limit in units a person reads.
class SceneImportTooLargeException implements Exception {
  const SceneImportTooLargeException({required this.sizeBytes});

  final int sizeBytes;

  @override
  String toString() =>
      'That file is too large to import (${_mb(sizeBytes)}; '
      'the limit is ${_mb(maxSceneImportBytes)}).';

  static String _mb(int bytes) =>
      '${(bytes / (1024 * 1024)).toStringAsFixed(bytes < 1024 * 1024 ? 2 : 0)} MB';
}
