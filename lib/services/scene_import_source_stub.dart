import 'package:flowcraft/services/importable_scene.dart';

/// Web fallback for [SceneImportSource] — listing and reading files needs
/// `dart:io`. Selected in place of `scene_import_source_io.dart` by the
/// `dart.library.io` conditional import in `scene_import_source.dart`.
///
/// [list] answers empty rather than throwing, so the import dialog renders
/// its "nothing here" state and the paste-JSON route beside it — which does
/// work on web — stays usable.
class SceneImportSource {
  SceneImportSource._();

  static const int maxEntries = 0;

  static String defaultDirectoryPath() => '';

  static Future<List<ImportableScene>> list({String? directoryPath}) async =>
      const <ImportableScene>[];

  static Future<String> read(String path) async => throw UnsupportedError(
        'Reading files from disk is not available on the web build.',
      );

  static String expandHome(String path) => path;
}
