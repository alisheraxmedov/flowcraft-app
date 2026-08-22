/// Platform-agnostic entry point for writing exported files to disk.
///
/// `dart:io.File`/`Process` don't exist on web, so widgets must never import
/// `export_file_sink_io.dart` directly — that would break
/// `flutter build web`. This conditional export picks the real
/// implementation when `dart:io` is available and a refusing stub otherwise.
library;

export 'export_file_sink_stub.dart'
    if (dart.library.io) 'export_file_sink_io.dart';
