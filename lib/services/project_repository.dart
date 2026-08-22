/// Platform-agnostic entry point for saved-project storage.
///
/// The real implementation needs `dart:io`, which doesn't exist on web, so
/// view models must import this barrel rather than
/// `project_repository_io.dart` — otherwise `flutter build web` breaks.
/// Mirrors the `app_control.dart` split.
library;

export 'project_repository_stub.dart'
    if (dart.library.io) 'project_repository_io.dart';
