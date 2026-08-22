import 'package:flutter/foundation.dart' show immutable;

/// One `.json` file the import dialog can offer, described well enough to
/// pick between two exports of the same board without opening either.
@immutable
class ImportableScene {
  const ImportableScene({
    required this.path,
    required this.name,
    required this.sizeBytes,
    required this.modifiedAt,
  });

  /// Absolute path, which is what gets read.
  final String path;

  /// File name as shown in the list.
  final String name;

  final int sizeBytes;
  final DateTime modifiedAt;

  /// `12.4 KB` — a size the user can compare at a glance. Deliberately
  /// coarse: the question this answers is "is this the full board or the
  /// three shapes I exported by accident", not "how many bytes".
  String get sizeLabel {
    if (sizeBytes < 1024) return '$sizeBytes B';
    final kb = sizeBytes / 1024;
    if (kb < 1024) return '${kb.toStringAsFixed(1)} KB';
    return '${(kb / 1024).toStringAsFixed(1)} MB';
  }
}
