/// Web fallback for [ExportFileSink] — writing files and launching a file
/// manager both need `dart:io`, which doesn't exist on web. Selected in
/// place of `export_file_sink_io.dart` by the `dart.library.io` conditional
/// import in `export_file_sink.dart`.
///
/// PNG/JSON *rendering* still works on web (it is pure `dart:ui`); only the
/// final "put it on disk" step is unavailable, so the failure is raised
/// here rather than degrading the whole export menu.
class ExportFileSink {
  ExportFileSink._();

  static String defaultDirectoryPath() => '';

  static Future<String> write({
    required String fileName,
    required List<int> bytes,
    String? directoryPath,
  }) async {
    throw UnsupportedError(
      'Saving exports to disk is not available on the web build.',
    );
  }

  static Future<bool> reveal(String path) async => false;
}
