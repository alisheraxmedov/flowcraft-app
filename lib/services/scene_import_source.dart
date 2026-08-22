/// Platform-agnostic entry point for finding scene files to import.
///
/// The real implementation needs `dart:io`, which doesn't exist on web, so
/// widgets must import this barrel rather than `scene_import_source_io.dart`
/// — otherwise `flutter build web` breaks. Mirrors the `export_file_sink`
/// and `project_repository` splits.
library;

export 'scene_import_source_stub.dart'
    if (dart.library.io) 'scene_import_source_io.dart';
