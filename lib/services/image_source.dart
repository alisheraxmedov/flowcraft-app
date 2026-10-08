/// Platform-agnostic entry point for resolving `type:'image'` draw entries.
///
/// Reading a `path` needs `dart:io`, which web lacks, so callers import this
/// barrel rather than `image_source_io.dart`. Mirrors the `export_file_sink`
/// and `scene_import_source` splits.
library;

export 'image_source_stub.dart' if (dart.library.io) 'image_source_io.dart';
